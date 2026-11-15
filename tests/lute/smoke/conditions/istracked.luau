-- Condition tree of resave.istracked (node fields: node.luau).
local shared = require './shared'
local STORE = shared.STORE

return {
	name = 'istracked',
	preamble = STORE,
	prep = "local _, s = resave.track(players, 'p1')",
	call = 'local tracked = resave.istracked(s)',
	ret = 'return tracked',
	tree = {
		{ id = 'freed', group = 'state', label = 'session was freed', arm = 'resave.free(s)' },
		{
			id = 'retracked',
			group = 'state',
			label = 'freed, then the key was tracked again',
			arm = "resave.free(s)\nresave.track(players, 'p1')",
		},
	},
}
