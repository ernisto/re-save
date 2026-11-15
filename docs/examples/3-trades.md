# Trades

Change two keys together, or neither. `savebatch` tests every update first, then locks, commits and adopts both records; an update that raises cancels the whole trade.

```luau
local ServerScriptService = game:GetService 'ServerScriptService'
local resave = require(ServerScriptService.ServerPackages.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0, items = {} },
})

local function trade(seller, buyer, item, price)
	return resave.savebatch(function(update)
		update(players, seller, function(data)
			local slot = table.find(data.items, item)
			assert(slot, 'the item is gone')
			table.remove(data.items, slot)
			data.coins += price
		end)
		update(players, buyer, function(data)
			assert(data.coins >= price, 'not enough coins')
			data.coins -= price
			table.insert(data.items, item)
		end)
	end)
end

local err = trade('1001', '1002', 'sword', 50)
if err then warn(`trade failed: {err}`) end
```

Call `update` once per key: put all of one player's changes in that single update. Tracked traders go through their sessions, so `session.data` shows the result as soon as `savebatch` returns.
