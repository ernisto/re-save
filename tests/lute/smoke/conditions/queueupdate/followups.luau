-- queueupdate follow-up events after the call.
local nodes = require '../node'
local shared = require '../shared'
local andthen = shared.andthen

-- queueupdate cases where the call throws, so no follow-up could run
local QUEUE_FAILS = { 'freed', 'raises', 'yields', 'not_json', 'returns_not_json', 'non_ascii', 'impure' }

local list: { nodes.node } = {
	andthen('livesync', 'the background loop runs', 'background loop', 'settle()', { conflicts = QUEUE_FAILS }),
	andthen(
		'then_saveupdate',
		'saveupdate on the same key',
		'saveupdate',
		"local saveerr = resave.saveupdate(players, 'p1', function(d)\n\td.coins += 100\nend)",
		{ conflicts = QUEUE_FAILS }
	),
	andthen('then_free', 'free', 'free', 'local freeerr = resave.free(s)', { conflicts = QUEUE_FAILS }),
	andthen(
		'then_view',
		'view the key',
		'view',
		"local viewerr, viewed = resave.view(players, 'p1')",
		{ conflicts = QUEUE_FAILS }
	),
	andthen(
		'then_queue',
		'queueupdate again',
		'2nd queueupdate',
		'resave.queueupdate(s, function(d)\n\td.coins *= 2\nend)',
		{ conflicts = QUEUE_FAILS }
	),
}

return list
