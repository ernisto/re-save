-- queueupdate suggested fixes: each stands alone, so no follow-up or second update.
local nodes = require '../node'
local QUEUE_SOLO = { 'queued', 'freed', 'livesync', 'then_saveupdate', 'then_free', 'then_view', 'then_queue' }

local list: { nodes.node } = {
	{
		id = 'freed_checked',
		group = 'fn',
		label = 'fix: checks the player is still tracked first',
		queue = 'limitation',
		arm = 'resave.free(s)',
		slots = {
			call = 'if resave.istracked(s) then -- the player may have left meanwhile\n\tresave.queueupdate(s, function(d)\n\t\td.coins += 5\n\tend)\nend',
		},
		conflicts = QUEUE_SOLO,
	},
	{
		id = 'raises_checked',
		group = 'fn',
		label = 'fix: checks the amount the client sent',
		queue = 'limitation',
		slots = {
			call = "local amount = nil -- the RemoteEvent arrived without an amount\nif type(amount) == 'number' and amount > 0 and amount <= 100 then\n\tresave.queueupdate(s, function(d)\n\t\td.coins += amount\n\tend)\nend",
		},
		conflicts = QUEUE_SOLO,
	},
	{
		id = 'vector_plain',
		group = 'fn',
		label = 'fix: saves the spawn point as plain numbers',
		queue = 'limitation',
		slots = { body = 'd.spawn = { x = 10, y = 0, z = 5 } -- rebuild the vector when loading' },
		conflicts = QUEUE_SOLO,
	},
	{
		id = 'returns_plain',
		group = 'fn',
		label = 'fix: returns plain data and keeps the callback in game code',
		queue = 'limitation',
		slots = { body = 'return { coins = d.coins + 5, items = d.items }' },
		conflicts = QUEUE_SOLO,
	},
	{
		id = 'impure_fixed',
		group = 'fn',
		label = 'fix: reads the time before queueing',
		queue = 'limitation',
		slots = {
			input = 'local now = os.clock() -- read once, outside the update\n',
			body = 'd.lastclaim = now',
		},
		conflicts = QUEUE_SOLO,
	},
}

return list
