-- Condition tree of resave.free (node fields: node.luau).
local nodes = require './node'
local shared = require './shared'
local STORE = shared.STORE
local RECORD = shared.RECORD
local UPDATE_FAILS = shared.UPDATE_FAILS
local WRITE_FAILS = shared.WRITE_FAILS
local txnodes = shared.txnodes
local andthen = shared.andthen

local spec: nodes.spec = {
	name = 'free',
	preamble = STORE,
	prep = "local _, s = resave.track(players, 'p1')",
	call = 'local err = resave.free(s)',
	ret = 'return err',
	slots = { coins = '5', pendingtx = '' },
	tree = {
		{
			id = 'record',
			label = 'a record is stored',
			setup = RECORD,
			children = txnodes 'tx',
		},
		{ id = 'freed', group = 'session', label = 'session was already freed', arm = 'resave.free(s)' },
		{
			id = 'pending',
			group = 'session',
			label = 'oplog has updates',
			arm = 'resave.queueupdate(s, function(d)\n\td.coins += 7\nend)',
			children = {
				{
					id = 'rewritten',
					label = 'another server rewrote the record so the update fails',
					arm = 'cloud(players).p1 = { data = { gems = 3 }, version = 0 }',
				},
				{
					id = 'bumped',
					label = 'a server on a newer version saved the record',
					arm = 'cloud(players).p1 = { data = { coins = 1 }, version = 3 } -- a newer release saved the player meanwhile',
					conflicts = { 'rewritten', 'record', 'update_fails', 'write_fails', 'then_queue' },
				},
			},
		},
		UPDATE_FAILS,
		WRITE_FAILS,
		andthen(
			'then_track',
			'track the key again',
			'2nd track',
			"heal(players)\nlocal _, again = resave.track(players, 'p1')"
		),
		andthen(
			'then_retry',
			'the DataStore recovers and free is retried',
			'retry',
			'heal(players)\nlocal retryerr = resave.free(s)'
		),
		andthen(
			'then_queue',
			'queueupdate on the same session',
			'queueupdate',
			'resave.queueupdate(s, function(d)\n\td.coins += 1\nend)'
		),
		andthen(
			'then_queue_checked',
			'fix: queueupdate only if the session is still tracked',
			'queueupdate',
			'if resave.istracked(s) then -- the player may have left\n\tresave.queueupdate(s, function(d)\n\t\td.coins += 1\n\tend)\nend',
			{ queue = 'limitation', conflicts = { 'record', 'pending', 'freed', 'update_fails', 'write_fails' } }
		),
	},
}

return spec
