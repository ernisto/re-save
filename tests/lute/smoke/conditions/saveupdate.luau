-- Condition tree of resave.saveupdate (node fields: node.luau).
local nodes = require './node'
local shared = require './shared'
local SHOP_STORE = shared.SHOP_STORE
local UPDATE_FAILS = shared.UPDATE_FAILS
local WRITE_FAILS = shared.WRITE_FAILS
local andthen = shared.andthen

-- the shop: a sword costs 10 coins
local BUY_SWORD = "assert(d.coins >= 10, 'not enough coins')\n\td.coins -= 10\n\ttable.insert(d.items, 'sword')"
local SHOP_RECORD =
	"cloud(players).p1 = {\n\tdata = { coins = 25, items = { 'shield' } },\n\tversion = 0,{{pendingtx}}\n}"
local SHOP_LOCK =
	"\n\tpendingtx = { id = 'tx-a', newdata = { coins = 25, items = { 'shield', 'bow' } }, version = 0, cooltimestamp = 0 },"

local spec: nodes.spec = {
	name = 'saveupdate',
	preamble = SHOP_STORE,
	call = "local err = resave.saveupdate(players, 'p1', function(d)\n\t{{body}}\nend)",
	ret = 'return err',
	slots = { body = BUY_SWORD, pendingtx = '' },
	tree = {
		{
			id = 'record',
			label = 'the player has saved data',
			setup = SHOP_RECORD,
			children = {
				{
					id = 'tx_deleted',
					group = 'tx',
					label = 'locked by a trade that no longer exists (aborted)',
					slots = { pendingtx = SHOP_LOCK },
					settle = true,
				},
				{
					id = 'tx_live',
					group = 'tx',
					label = 'locked by a trade in progress',
					setup = "txcloud['tx-a'] = { state = 'pending', adopts = {}, committimeout = now + 60 }",
					slots = { pendingtx = SHOP_LOCK },
					settle = true,
				},
				{
					id = 'tx_committed',
					group = 'tx',
					label = 'locked by a trade that was committed',
					setup = "txcloud['tx-a'] = { state = 'commited', adopts = {}, committimeout = now + 60 }",
					slots = { pendingtx = SHOP_LOCK },
					settle = true,
				},
			},
		},
		{
			id = 'tracked',
			label = 'the player is playing',
			setup = "local _, s = resave.track(players, 'p1')",
			children = {
				{
					id = 'pending',
					label = 'they earned coins that are not saved yet',
					arm = 'resave.queueupdate(s, function(d)\n\td.coins += 30\nend)',
				},
			},
		},
		{
			id = 'poor',
			group = 'fn',
			label = "the player can't afford it",
			queue = 'intro',
			setup = 'cloud(players).p1 = { data = { coins = 4, items = {} }, version = 0 }',
			conflicts = { 'record' },
		},
		{
			id = 'yields',
			group = 'fn',
			label = 'the purchase waits on a web request',
			setup = 'local function checkreceiptasync()\n\ttask.wait() -- MarketplaceService or an HTTP call\n\treturn true\nend',
			slots = { body = 'assert(checkreceiptasync())\n\t' .. BUY_SWORD },
			-- rejected before anything is read, so nothing else changes the result
			conflicts = { 'record', 'tracked', 'update_fails', 'write_fails', 'then_track', 'then_retry' },
		},
		UPDATE_FAILS,
		WRITE_FAILS,
		andthen(
			'then_track',
			'the player joins',
			'join',
			"local trackerr, after = resave.track(players, 'p1')",
			{ conflicts = { 'update_fails' } }
		),
		andthen(
			'then_retry',
			'the DataStore recovers and the purchase is retried',
			'retry',
			"heal(players)\nlocal retryerr = resave.saveupdate(players, 'p1', function(d)\n\t" .. BUY_SWORD .. '\nend)'
		),
	},
}

return spec
