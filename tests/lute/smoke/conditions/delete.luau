-- Condition tree of resave.delete (node fields: node.luau).
local nodes = require './node'
local shared = require './shared'
local STORE = shared.STORE
local andthen = shared.andthen

local spec: nodes.spec = {
	name = 'delete',
	preamble = STORE,
	call = "local err = resave.delete(players, 'p1')",
	ret = 'return err',
	tree = {
		{
			id = 'record',
			label = 'a record is stored',
			setup = 'cloud(players).p1 = { data = { coins = 5 }, version = 0 }',
		},
		{
			id = 'tracked',
			label = 'key is tracked with queued updates',
			setup = "local _, s = resave.track(players, 'p1')\nresave.queueupdate(s, function(d)\n\td.coins += 2\nend)",
			children = {
				andthen(
					'then_free',
					'free the tracked session',
					'free',
					'local freeerr = resave.free(s)',
					{ conflicts = { 'then_track', 'then_view' } }
				),
			},
		},
		{ id = 'remove_fails', label = 'RemoveAsync fails', arm = "fail(players, 'remove')" },
		andthen(
			'then_track',
			'track the key',
			'track',
			"heal(players)\nlocal trackerr, after = resave.track(players, 'p1')"
		),
		andthen(
			'then_view',
			'view the key',
			'view',
			"heal(players)\nlocal viewerr, viewed = resave.view(players, 'p1')"
		),
	},
}

return spec
