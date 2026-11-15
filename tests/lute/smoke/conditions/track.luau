-- Condition tree of resave.track (node fields: node.luau).
local shared = require './shared'
local RECORD = shared.RECORD
local UPDATE_FAILS = shared.UPDATE_FAILS
local WRITE_FAILS = shared.WRITE_FAILS
local pendingtx = shared.pendingtx
local txnodes = shared.txnodes
local andthen = shared.andthen

return {
	name = 'track',
	preamble = "local schema = {{schema}}\nlocal players = resave.store('players', { schema = schema })",
	call = "local err, s = resave.track(players, 'p1')",
	ret = 'return err, s',
	slots = {
		schema = 'resave.schema { coins = 0 }',
		coins = '5',
		pendingtx = '',
	},
	tree = {
		{
			id = 'tracked',
			group = 'key',
			label = 'key is already tracked',
			setup = "local _, first = resave.track(players, 'p1')",
			post = "assert(s == first, 'expected the same session')",
			keep = true, -- no cloud call: invisible in the final state, still worth showing
		},
		{
			id = 'record',
			group = 'key',
			label = 'a record is stored',
			setup = RECORD,
			children = {
				{
					id = 'outdated',
					group = 'version',
					label = 'saved by an older version of the game',
					slots = {
						schema = 'resave.migrate(resave.schema { coins = 0 }, function(d)\n\treturn { gold = d.coins * 10 }\nend)',
					},
				},
				{
					id = 'migration_fails',
					group = 'version',
					label = 'stored data fails a migration',
					slots = {
						coins = '500',
						schema = "resave.migrate(resave.schema { coins = 0 }, function(d)\n\tassert(d.coins < 100, 'too many coins')\n\treturn { gold = d.coins * 10 }\nend)",
					},
					-- tx locks and failures add nothing to the error
					conflicts = {
						'tx_committed',
						'tx_live',
						'tx_deleted',
						'tx_expired',
						'update_fails',
						'write_fails',
					},
				},
				table.unpack(txnodes 'tx'),
			},
		},
		{
			id = 'malformed',
			group = 'key',
			label = 'stored value is not a record',
			setup = "cloud(players).p1 = 'corrupt'",
			conflicts = { 'then_queue_free', 'update_fails', 'write_fails' },
		},
		{
			id = 'ahead',
			group = 'key',
			label = 'stored version is newer than the schema',
			setup = 'cloud(players).p1 = { data = { coins = 1 }, version = 3 }',
		},
		UPDATE_FAILS,
		WRITE_FAILS,
		andthen(
			'then_queue_free',
			'queueupdate and free',
			'queueupdate',
			'resave.queueupdate(s, function(d)\n\td.coins += 1\nend)\nlocal freeerr = resave.free(s)',
			{ conflicts = { 'ahead', 'update_fails', 'write_fails', 'outdated', 'migration_fails' } }
		),
		andthen(
			'then_track',
			'track again',
			'2nd track',
			"local _, again = resave.track(players, 'p1')\nassert(again == s, 'expected the same session')",
			{ conflicts = { 'ahead', 'update_fails', 'write_fails' } }
		),
	},
}
