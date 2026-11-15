-- Condition tree of resave.queueupdate (node fields: ../node.luau): purchases and
-- misuses first, then their fixes, then follow-up events.
local fixes = require '@self/fixes'
local followups = require '@self/followups'
local shared = require './shared'
local SHOP_STORE = shared.SHOP_STORE

-- queueupdate follow-ups; the rebase purchase cases bring their own
local QUEUE_FOLLOWUPS = { 'livesync', 'then_saveupdate', 'then_free', 'then_view', 'then_queue' }

-- queueupdate purchases: the check belongs inside the update, so it runs again
-- whenever the update is replayed (rebased) on newer cloud data
local BUY_INSIDE =
	"if d.coins >= 10 then -- checked against whatever data it runs on\n\t\td.coins -= 10\n\t\ttable.insert(d.items, 'sword')\n\tend"
local SPENT_ELSEWHERE =
	"checkpoint 'queued'\ncloud(players).p1 = { data = { coins = 5, items = {} }, version = 0 } -- another server spent 95 coins meanwhile\nlocal freeerr = resave.free(s) -- leaving replays the queued purchase on that data"

local MISUSES = {
	{
		id = 'buy',
		group = 'fn',
		label = 'buys a sword, checking coins inside the update',
		slots = { body = BUY_INSIDE },
	},
	{
		id = 'buy_rebased',
		group = 'fn',
		label = 'fix: checks inside the update, then another server spends the coins',
		queue = 'limitation',
		slots = { body = BUY_INSIDE },
		post = SPENT_ELSEWHERE,
		conflicts = QUEUE_FOLLOWUPS,
	},
	{
		id = 'buy_stale',
		group = 'fn',
		label = 'checks coins before queueing, then another server spends them',
		queue = 'limitation',
		slots = {
			call = "if s.data.coins >= 10 then -- checked once, before queueing\n\tresave.queueupdate(s, function(d)\n\t\td.coins -= 10\n\t\ttable.insert(d.items, 'sword')\n\tend)\nend",
		},
		post = SPENT_ELSEWHERE,
		conflicts = QUEUE_FOLLOWUPS,
	},
	{
		id = 'queued',
		label = 'oplog already has an update',
		arm = 'resave.queueupdate(s, function(d)\n\td.coins += 1\nend)',
	},
	{ id = 'freed', label = 'the player already left', arm = 'resave.free(s)' },
	{
		id = 'raises',
		group = 'fn',
		label = 'uses an amount the client never sent',
		slots = {
			input = 'local amount = nil -- the RemoteEvent arrived without an amount\n',
			body = 'd.coins += amount',
		},
	},
	{
		id = 'yields',
		group = 'fn',
		label = 'waits on a web request inside the update',
		setup = 'local function getrankasync()\n\ttask.wait() -- an HTTP call or MarketplaceService lookup\n\treturn 3\nend',
		slots = { body = 'd.rank = getrankasync()' },
	},
	{
		id = 'not_json',
		group = 'fn',
		label = 'saves a vector as the spawn point',
		slots = { body = 'd.spawn = vector.create(10, 0, 5)' },
	},
	{
		id = 'returns_not_json',
		group = 'fn',
		label = 'returns data holding a function',
		slots = { body = 'return { coins = d.coins, onlevelup = function() end }' },
	},
	{
		id = 'non_ascii',
		group = 'fn',
		label = 'saves a pet name typed by the player',
		queue = 'limitation',
		slots = {
			input = "local name = 'Señor Bigotes' -- sent by the client through a RemoteEvent\n",
			body = 'd.petname = name',
		},
	},
	{
		id = 'impure',
		group = 'fn',
		label = 'stamps the daily reward time inside the update',
		slots = { body = 'd.lastclaim = os.clock()' },
	},
}

local tree = {}
for _, part in { MISUSES, fixes, followups } do
	table.move(part, 1, #part, #tree + 1, tree)
end

return {
	name = 'queueupdate',
	preamble = SHOP_STORE,
	prep = "local _, s = resave.track(players, 'p1')",
	call = '{{call}}',
	ret = '',
	slots = {
		call = '{{input}}resave.queueupdate(s, function(d)\n\t{{body}}\nend)',
		input = '',
		body = 'd.coins += 5',
	},
	tree = tree,
}
