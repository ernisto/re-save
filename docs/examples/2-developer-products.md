# Developer products

Grant a purchase only once it is saved. `saveupdate` writes in one `UpdateAsync` (through the player's session when they are tracked), so `PurchaseGranted` is returned only after the coins are in the DataStore. Remembering the receipt makes a retried receipt a no-op.

```luau
local MarketplaceService = game:GetService 'MarketplaceService'
local ServerScriptService = game:GetService 'ServerScriptService'
local resave = require(ServerScriptService.ServerPackages.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0, receipts = {} },
})

local COINS = { [1234567] = 100 } -- product id → coins

MarketplaceService.ProcessReceipt = function(receipt)
	local coins = COINS[receipt.ProductId]
	if not coins then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local err = resave.saveupdate(players, tostring(receipt.PlayerId), function(data)
		if table.find(data.receipts, receipt.PurchaseId) then return end

		data.coins += coins
		table.insert(data.receipts, receipt.PurchaseId)
		if #data.receipts > 50 then table.remove(data.receipts, 1) end
	end)

	if err then return Enum.ProductPurchaseDecision.NotProcessedYet end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
```

On an error nothing was written: Roblox calls `ProcessReceipt` again later.
