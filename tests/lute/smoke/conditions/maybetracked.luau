-- Condition tree of resave.maybetracked (node fields: node.luau).
local nodes = require './node'
local shared = require './shared'
local STORE = shared.STORE

local spec: nodes.spec = {
	name = 'maybetracked',
	preamble = STORE,
	call = "local s = resave.maybetracked(players, 'p1')",
	ret = 'return s',
	tree = {
		{
			id = 'tracked',
			label = 'key is tracked',
			setup = "local _, first = resave.track(players, 'p1')",
			children = { { id = 'freed', label = 'session was freed', arm = 'resave.free(first)' } },
		},
	},
}

return spec
