# Player data

Load a player's data when they join, change it while they play, and let it go when they leave. Changes are queued on the session and saved in the background, on `free`, and when the server shuts down. `maybetracked` finds the session from anywhere, so no table of sessions is needed.

```luau
local Players = game:GetService 'Players'
local ServerScriptService = game:GetService 'ServerScriptService'
local resave = require(ServerScriptService.ServerPackages.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0, items = {} },
})

Players.PlayerAdded:Connect(function(player)
	local err = resave.track(players, tostring(player.UserId))
	if err then player:Kick 'Could not load your data, please rejoin' end
end)

-- also frees a session still loading: track then returns it already freed
Players.PlayerRemoving:Connect(function(player)
	local session = resave.maybetracked(players, tostring(player.UserId))
	if session then resave.free(session) end
end)

local function earn(player, amount)
	local session = resave.maybetracked(players, tostring(player.UserId))
	if not session then return end

	resave.queueupdate(session, function(data)
		data.coins += amount
	end)
end

local function coinsof(player)
	local session = resave.maybetracked(players, tostring(player.UserId))
	return session and session.data.coins
end
```

An update must not yield, and must do the same thing every time it runs: it can be replayed on newer data when another server wrote the key meanwhile. Read anything slow (a rank, a price) first, then pass the result in.
