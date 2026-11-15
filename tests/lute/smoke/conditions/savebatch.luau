-- Condition tree of resave.savebatch (node fields: node.luau).
local shared = require './shared'
local SHOP_STORE = shared.SHOP_STORE
local pendingtx = shared.pendingtx
local andthen = shared.andthen

-- savebatch suggested-fix cases stand alone
local BATCH_SOLO =
	{ 'duplicate', 'empty', 'locked', 'create_fails', 'lock_fails', 'commit_fails', 'adopt_fails', 'then_track' }

return {
	name = 'savebatch',
	preamble = SHOP_STORE .. "\ncloud(players).seller = { data = { coins = 0, items = { 'sword' } }, version = 0 }",
	call = 'local err = resave.savebatch(function(queue)\n{{builder}}{{trade}}\nend)',
	ret = 'return err',
	settle = true,
	slots = {
		builder = '',
		trade = "\tqueue(players, 'seller', function(d)\n\t\t{{sell}}\n\tend)\n\tqueue(players, 'buyer', function(d)\n\t\tassert(d.coins >= 50, 'not enough coins')\n\t\td.coins -= 50\n\t\ttable.insert(d.items, 'sword')\n\tend)",
		sell = "local slot = table.find(d.items, 'sword')\n\t\tassert(slot, 'the sword is gone')\n\t\ttable.remove(d.items, slot)\n\t\td.coins += 50",
		adoptn = '3',
		adoptwhy = 'writes 1 and 2 lock both players, write 3 applies the trade to one of them',
	},
	tree = {
		{
			id = 'duplicate',
			label = 'the seller is queued twice',
			slots = {
				trade = "\tqueue(players, 'seller', function(d)\n\t\t{{sell}}\n\tend)\n\tqueue(players, 'seller', function(d)\n\t\td.coins += 10 -- trade fee refund\n\tend)\n\tqueue(players, 'buyer', function(d)\n\t\tassert(d.coins >= 50, 'not enough coins')\n\t\td.coins -= 50\n\t\ttable.insert(d.items, 'sword')\n\tend)",
			},
			-- throws before anything is read, so nothing else changes the result
			conflicts = {
				'empty',
				'locked',
				'create_fails',
				'lock_fails',
				'commit_fails',
				'adopt_fails',
				'then_track',
				'builder_raises',
				'poor',
			},
		},
		{
			id = 'merged',
			label = "fix: the seller's changes go in one update",
			queue = 'limitation',
			setup = "resave.track(players, 'seller')",
			slots = {
				sell = "local slot = table.find(d.items, 'sword')\n\t\tassert(slot, 'the sword is gone')\n\t\ttable.remove(d.items, slot)\n\t\td.coins += 50 + 10 -- price plus the trade fee refund, in one update",
			},
			conflicts = {
				'duplicate',
				'empty',
				'locked',
				'create_fails',
				'lock_fails',
				'commit_fails',
				'adopt_fails',
				'then_track',
				'builder_raises',
				'builder_checked',
				'poor',
			},
		},
		{
			id = 'empty',
			label = 'nothing is traded',
			slots = { trade = '\t-- both players removed their items' },
			conflicts = { 'duplicate' },
		},
		{
			id = 'builder_raises',
			group = 'broken',
			label = 'the builder reads an offer that was cancelled',
			setup = 'local offer = nil -- the buyer cancelled the offer',
			slots = { builder = '\tlocal price = offer.price\n' },
		},
		{
			id = 'builder_checked',
			group = 'broken',
			label = 'fix: the builder stops when the offer was cancelled',
			queue = 'limitation',
			setup = 'local offer = nil -- the buyer cancelled the offer',
			slots = { builder = '\tif not offer then return end -- nothing to trade\n' },
			conflicts = BATCH_SOLO,
		},
		{
			id = 'poor',
			group = 'broken',
			label = "the buyer can't afford it",
			queue = 'intro',
			setup = 'cloud(players).buyer = { data = { coins = 10, items = {} }, version = 0 }',
			conflicts = { 'empty' },
		},
		{
			id = 'locked',
			label = 'the seller is in another trade',
			setup = "cloud(players).seller.pendingtx = { id = 'tx-other', newdata = { coins = 0, items = {} }, version = 0, cooltimestamp = 0 }\ntxcloud['tx-other'] = { state = 'pending', adopts = {}, committimeout = now + 60 }",
			conflicts = { 'empty' },
		},
		{
			id = 'create_fails',
			group = 'fail',
			label = 'the transaction store is down',
			arm = "fail('tx', 'update')",
		},
		{
			id = 'lock_fails',
			group = 'fail',
			label = 'the player DataStore is down',
			arm = "fail(players, 'update')",
			conflicts = { 'empty' },
		},
		{
			id = 'commit_fails',
			group = 'fail',
			label = 'the commit write fails',
			arm = "failwrite('tx', 2) -- 1st tx write creates it, 2nd commits it",
			conflicts = { 'empty' },
		},
		{
			id = 'adopt_fails',
			group = 'fail',
			label = "writing one player's result fails",
			arm = 'failwrite(players, {{adoptn}}) -- {{adoptwhy}}',
			conflicts = { 'empty' },
		},
		andthen(
			'then_track',
			'the seller joins',
			'seller joins',
			"heal(players)\nheal('tx')\nlocal trackerr, seller = resave.track(players, 'seller')\nsettle()",
			{ conflicts = { 'builder_raises' } }
		),
	},
}
