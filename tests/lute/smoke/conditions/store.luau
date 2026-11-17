-- Condition tree of resave.store (node fields: node.luau).
local nodes = require './node'
local shared = require './shared'
local STORE = shared.STORE

local spec: nodes.spec = {
	name = 'store',
	preamble = '',
	call = STORE,
	ret = 'return players',
	tree = {
		{
			id = 'registered',
			label = 'name already registered on this server',
			setup = "resave.store('players', { schema = resave.schema {} })",
		},
		{
			id = 'shared',
			label = 'fix: other scripts reuse the registered store',
			queue = 'limitation',
			post = 'local shopplayers = players -- the shop script requires the shared module instead of registering again',
			conflicts = { 'registered' },
		},
	},
}

return spec
