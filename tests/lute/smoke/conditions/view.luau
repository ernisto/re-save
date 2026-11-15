-- Condition tree of resave.view (node fields: node.luau).
local shared = require './shared'
local STORE = shared.STORE
local UPDATE_FAILS = shared.UPDATE_FAILS
local WRITE_FAILS = shared.WRITE_FAILS

local nodes = require './node'
type node = nodes.node

local GET_FAILS: node = {
	id = 'get_fails',
	group = 'fail',
	label = 'GetAsync fails',
	arm = "fail(players, 'get')",
}

return {
	name = 'view',
	preamble = STORE,
	call = "local err, data = resave.view(players, 'p1')",
	ret = 'return err, data',
	tree = {
		{
			id = 'record',
			group = 'key',
			label = 'a record is stored',
			setup = 'cloud(players).p1 = { data = { coins = 2 }, version = 0 }',
		},
		{
			id = 'ahead',
			group = 'key',
			label = 'stored version is newer than the schema',
			setup = 'cloud(players).p1 = { data = { coins = 1 }, version = 3 }',
		},
		{
			id = 'tracked',
			label = 'key is tracked',
			setup = "local _, s = resave.track(players, 'p1')",
			conflicts = { 'ahead' },
			children = {
				{
					id = 'pending',
					label = 'oplog has updates',
					arm = 'resave.queueupdate(s, function(d)\n\td.coins += 3\nend)',
				},
				{
					id = 'rewritten',
					label = 'another server wrote after track',
					arm = 'cloud(players).p1 = { data = { coins = 99 }, version = 0 }',
				},
			},
		},
		GET_FAILS,
		UPDATE_FAILS,
		{
			id = 'write_fails',
			group = 'fail',
			label = WRITE_FAILS.label,
			arm = WRITE_FAILS.arm,
		},
	},
}
