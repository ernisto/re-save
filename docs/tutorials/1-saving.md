# Saving coins

```luau Player's server
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'

local store = DataStoreService:GetDataStore 'players'
```

```cloud
players.friend = 20
```

[Your game has one currency: coins.](mark:players.friend = »20) [Players earn them, leave, and expect them to be there next time.](code:GetDataStore 'players')

## Load on join, save on leave

[The obvious version reads the coins when the player joins,](code:PlayerAdded)

```luau Player's server
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'

local store = DataStoreService:GetDataStore 'players'

Players.PlayerAdded:Connect(function(player)
	local coins = store:GetAsync(player.UserId) or 0
end)
```

[keeps them in a table while the player is in the game,](code:local coins)

```luau Player's server
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'

local store = DataStoreService:GetDataStore 'players'
local coins = {}

Players.PlayerAdded:Connect(function(player)
	coins[player] = store:GetAsync(player.UserId) or 0
end)
```

[and writes them back when the player leaves.](code:PlayerRemoving)

```luau Player's server
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'

local store = DataStoreService:GetDataStore 'players'
local coins = {}

Players.PlayerAdded:Connect(function(player)
	coins[player] = store:GetAsync(player.UserId) or 0
end)

Players.PlayerRemoving:Connect(function(player)
	store:SetAsync(player.UserId, coins[player])
	coins[player] = nil
end)
```

[Gameplay adds to the table when a player earns coins.](code:local function earn)

```luau Player's server
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'

local store = DataStoreService:GetDataStore 'players'
local coins = {}

Players.PlayerAdded:Connect(function(player)
	coins[player] = store:GetAsync(player.UserId) or 0
end)

Players.PlayerRemoving:Connect(function(player)
	store:SetAsync(player.UserId, coins[player])
	coins[player] = nil
end)

local function earn(player, amount)
	coins[player] += amount
end
```

[It works. You ship it.](code:players.friend)

## Your designer wants gifts

[Players should be able to send coins to a friend, even when the friend is playing on another server.](code:local function gift)

```luau Sender's server
local DataStoreService = game:GetService 'DataStoreService'
local store = DataStoreService:GetDataStore 'players'

local function gift(userid, amount)
	store:UpdateAsync(userid, function(old)
		return (old or 0) + amount
	end)
end
```

[The friend's coins live in the memory of the friend's server, so the gift can't touch `coins`.](code:local coins) [It writes to the DataStore directly.](code:store:UpdateAsync) [`UpdateAsync` reads the newest value and adds to it, so two gifts sent at once can't overwrite each other.](mark:return »(old or 0) + amount)

## QA: "gifts disappear"

[A tester sends 100 coins to a friend who is playing, the friend leaves, and the 100 coins are gone.](code:local function gift) [Follow the friend's coins, step by step.](code:players.friend)

1. [The friend joins.](code:PlayerAdded)

```state Player's server memory
coins[friend] = 20
```

[Their server reads 20 from the cloud and keeps its own copy.](mark:store:GetAsync(player.UserId) or 0 -> 20)

2. [They earn 5.](code:local function earn)

```state Player's server memory
coins[friend] = 25
```

[`coins[friend]` is 25, but only in their server's memory:](mark:coins[friend] = »25) [the cloud still says 20.](mark:players.friend = »20)

3. [The tester sends 100 from another server.](code:local function gift)

```cloud
players.friend = 120
```

[`UpdateAsync` reads 20 and writes 120: the cloud has the gift.](mark:(old or 0) + amount -> 20 + 100) [The player's server never hears about it, and its copy still says 25.](mark:coins[friend] = »25)

4. [The friend leaves.](code:PlayerRemoving)

```cloud
players.friend = 25
```

```state Player's server memory
coins[friend] = nil
```

[Their server writes what it has, and the cloud goes from 120 to 25.](mark:UserId, »coins[player] -> 25)

[The gift was saved. Then the player's server wrote over it.](mark:players.friend = »25)

## Why it broke

```state Player's server memory
```

[The player's server doesn't save what happened.](code:local function earn) **[It saves a result it worked out from an old copy.](mark:UserId, »coins[player])** [When it read the coins they were 20, it never saw the gift, and `SetAsync` turns its wrong number into the truth.](code:store:SetAsync) [Swapping `SetAsync` for `UpdateAsync` doesn't help: the server still only has 25 to write.](mark:players.friend = »25) [What it really knows isn't "the coins are 25". It's "the player earned 5".](mark:coins[player] »+= amount -> the fact worth saving)

[So keep that instead: a list of changes for each player,](code:local pending)

```luau Player's server
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'

local store = DataStoreService:GetDataStore 'players'
local coins = {}
local pending = {}

Players.PlayerAdded:Connect(function(player)
	coins[player] = store:GetAsync(player.UserId) or 0
	pending[player] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	store:SetAsync(player.UserId, coins[player])
	coins[player] = nil
end)

local function earn(player, amount)
	coins[player] += amount
end
```

[one entry per earn,](code:local function earn)

```luau Player's server
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'

local store = DataStoreService:GetDataStore 'players'
local coins = {}
local pending = {}

Players.PlayerAdded:Connect(function(player)
	coins[player] = store:GetAsync(player.UserId) or 0
	pending[player] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	store:SetAsync(player.UserId, coins[player])
	coins[player] = nil
end)

local function earn(player, amount)
	table.insert(pending[player], function(value)
		return value + amount
	end)
end
```

[applied to whatever the cloud holds at save time.](code:PlayerRemoving)

```luau Player's server
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'

local store = DataStoreService:GetDataStore 'players'
local pending = {}

Players.PlayerAdded:Connect(function(player)
	pending[player] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	store:UpdateAsync(player.UserId, function(cloud)
		local value = cloud or 0
		for _, change in pending[player] do
			value = change(value)
		end
		return value
	end)
	pending[player] = nil
end)

local function earn(player, amount)
	table.insert(pending[player], function(value)
		return value + amount
	end)
end
```

## The same story, replayed

```cloud
players.friend = 20
```

[Run the QA story on the new code.](code:local pending)

1. [The friend joins.](code:PlayerAdded)

```state Player's server memory
pending[friend] = {}
```

[Nothing is read: their server starts an empty list of changes.](mark:pending[friend] = »{})

2. [They earn 5.](code:local function earn)

```state Player's server memory
pending[friend] = { +5 }
```

[The list gets one change, `+5`, and nothing is written.](mark:pending[friend] = »{ +5 })

3. [The tester sends 100.](code:local function gift)

```cloud
players.friend = 120
```

[The cloud goes from 20 to 120.](mark:players.friend = »120)

4. [The friend leaves.](code:PlayerRemoving)

```cloud
players.friend = 125
```

```state Player's server memory
pending[friend] = nil
```

[`UpdateAsync` hands over 120,](mark:local value = »cloud or 0 -> 120) [the list adds 5 on top,](mark:value = »change(value) -> 125) [and 125 is saved.](mark:players.friend = »125)

[Order doesn't matter anymore: gift first or earn first, both survive.](code:players.friend)

## The game needs more than that

```state Player's server memory
```

[That version can't show the player their coins: it only knows the changes.](code:local pending) [And real servers crash before `PlayerRemoving` ever runs.](code:PlayerRemoving) [So you add:](code:local store)

- [a copy of the last value read, plus the pending changes on top, to display coins](code:local function coinsof)

```luau Player's server
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'

local store = DataStoreService:GetDataStore 'players'
local saved = {}
local pending = {}

local function apply(value, changes)
	for _, change in changes do
		value = change(value)
	end
	return value
end

local function coinsof(player)
	return apply(saved[player], pending[player])
end

Players.PlayerAdded:Connect(function(player)
	saved[player] = store:GetAsync(player.UserId) or 0
	pending[player] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	store:UpdateAsync(player.UserId, function(cloud)
		local value = cloud or 0
		for _, change in pending[player] do
			value = change(value)
		end
		return value
	end)
	pending[player] = nil
end)

local function earn(player, amount)
	table.insert(pending[player], function(value)
		return value + amount
	end)
end
```

- [an autosave every minute, so a crash loses one minute instead of the whole session](code:task.spawn)

```luau Player's server
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'

local store = DataStoreService:GetDataStore 'players'
local saved = {}
local pending = {}

local function apply(value, changes)
	for _, change in changes do
		value = change(value)
	end
	return value
end

local function coinsof(player)
	return apply(saved[player], pending[player])
end

local function save(player)
	saved[player] = store:UpdateAsync(player.UserId, function(old)
		return apply(old or 0, pending[player])
	end)
	pending[player] = {}
end

Players.PlayerAdded:Connect(function(player)
	saved[player] = store:GetAsync(player.UserId) or 0
	pending[player] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	saved[player] = nil
	pending[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end
end)

local function earn(player, amount)
	table.insert(pending[player], function(value)
		return value + amount
	end)
end
```

- [changes made *during* a save wait for the next save, instead of being lost or saved twice](code:local changes)

```luau Player's server
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'

local store = DataStoreService:GetDataStore 'players'
local saved = {}
local pending = {}

local function apply(value, changes)
	for _, change in changes do
		value = change(value)
	end
	return value
end

local function coinsof(player)
	return apply(saved[player], pending[player])
end

local function save(player)
	local changes = pending[player]
	pending[player] = {}

	saved[player] = store:UpdateAsync(player.UserId, function(old)
		return apply(old or 0, changes)
	end)
end

Players.PlayerAdded:Connect(function(player)
	saved[player] = store:GetAsync(player.UserId) or 0
	pending[player] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	saved[player] = nil
	pending[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end
end)

local function earn(player, amount)
	table.insert(pending[player], function(value)
		return value + amount
	end)
end
```

- [a failed save keeps its changes for the next try](code:table.move)

```luau Player's server
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'

local store = DataStoreService:GetDataStore 'players'
local saved = {}
local pending = {}

local function apply(value, changes)
	for _, change in changes do
		value = change(value)
	end
	return value
end

local function coinsof(player)
	return apply(saved[player], pending[player])
end

local function save(player)
	local changes = pending[player]
	pending[player] = {}

	local ok, cloud = pcall(store.UpdateAsync, store, player.UserId, function(old)
		return apply(old or 0, changes)
	end)
	if ok then
		saved[player] = cloud
	else
		table.move(pending[player], 1, #pending[player], #changes + 1, changes)
		pending[player] = changes
	end
end

Players.PlayerAdded:Connect(function(player)
	saved[player] = store:GetAsync(player.UserId) or 0
	pending[player] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	saved[player] = nil
	pending[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end
end)

local function earn(player, amount)
	table.insert(pending[player], function(value)
		return value + amount
	end)
end
```

- [`BindToClose`, so a shutdown saves everyone](code:game:BindToClose)

```luau Player's server
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'

local store = DataStoreService:GetDataStore 'players'
local saved = {}
local pending = {}

local function apply(value, changes)
	for _, change in changes do
		value = change(value)
	end
	return value
end

local function coinsof(player)
	return apply(saved[player], pending[player])
end

local function save(player)
	local changes = pending[player]
	pending[player] = {}

	local ok, cloud = pcall(store.UpdateAsync, store, player.UserId, function(old)
		return apply(old or 0, changes)
	end)
	if ok then
		saved[player] = cloud
	else
		table.move(pending[player], 1, #pending[player], #changes + 1, changes)
		pending[player] = changes
	end
end

Players.PlayerAdded:Connect(function(player)
	saved[player] = store:GetAsync(player.UserId) or 0
	pending[player] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	saved[player] = nil
	pending[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		save(player)
	end
end)

local function earn(player, amount)
	table.insert(pending[player], function(value)
		return value + amount
	end)
end
```

[And it still ignores the DataStore request budget, and never retries a failed save before the next minute.](code:local function save) [None of this code is about coins: it's the same for every game that saves anything.](code:local function earn)

## Hand it to re-save

[That bookkeeping is what re-save does.](code:local function save) [First, register the store with what a brand new player starts with.](code:local players)

```luau Player's server
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'
local resave = require(path.to.resave)

local store = DataStoreService:GetDataStore 'players'
local players = resave.store('players', {
	schema = resave.schema { coins = 0 },
})
local saved = {}
local pending = {}

local function apply(value, changes)
	for _, change in changes do
		value = change(value)
	end
	return value
end

local function coinsof(player)
	return apply(saved[player], pending[player])
end

local function save(player)
	local changes = pending[player]
	pending[player] = {}

	local ok, cloud = pcall(store.UpdateAsync, store, player.UserId, function(old)
		return apply(old or 0, changes)
	end)
	if ok then
		saved[player] = cloud
	else
		table.move(pending[player], 1, #pending[player], #changes + 1, changes)
		pending[player] = changes
	end
end

Players.PlayerAdded:Connect(function(player)
	saved[player] = store:GetAsync(player.UserId) or 0
	pending[player] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	saved[player] = nil
	pending[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		save(player)
	end
end)

local function earn(player, amount)
	table.insert(pending[player], function(value)
		return value + amount
	end)
end
```

[Data is now a table, `{ coins = 0 }`, so more fields fit later.](mark:resave.schema »{ coins = 0 }) [Then each piece maps one to one.](code:local pending)

| [Your code](code:local saved) | [re-save](code:local players) |
|---|---|
| [`saved` + `pending` for one player](code:local saved) | [a session, from `resave.track`](code:PlayerAdded) |
| [`table.insert(pending[player], change)`](code:local function earn) | [`resave.queueupdate`](code:local function earn) |
| [`coinsof(player)`](code:local function coinsof) | [`session.data`](code:sessions[player] = session) |
| [`save` on leave](code:PlayerRemoving) | [`resave.free`](code:PlayerRemoving) |
| [the autosave loop and `BindToClose`](code:task.spawn) | [built in, with the request budget and retries](code:local sessions) |
| [`gift`](code:local function gift) | [`resave.saveupdate`](code:local function gift) |

```luau Player's server @8
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'
local resave = require(path.to.resave)

local store = DataStoreService:GetDataStore 'players'
local players = resave.store('players', {
	schema = resave.schema { coins = 0 },
})
local sessions = {}
local saved = {}
local pending = {}

local function apply(value, changes)
	for _, change in changes do
		value = change(value)
	end
	return value
end

local function coinsof(player)
	return apply(saved[player], pending[player])
end

local function save(player)
	local changes = pending[player]
	pending[player] = {}

	local ok, cloud = pcall(store.UpdateAsync, store, player.UserId, function(old)
		return apply(old or 0, changes)
	end)
	if ok then
		saved[player] = cloud
	else
		table.move(pending[player], 1, #pending[player], #changes + 1, changes)
		pending[player] = changes
	end
end

Players.PlayerAdded:Connect(function(player)
	local err, session = resave.track(players, tostring(player.UserId))
	if err then
		player:Kick 'Could not load your data, please rejoin'
		return
	end
	sessions[player] = session
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	saved[player] = nil
	pending[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		save(player)
	end
end)

local function earn(player, amount)
	table.insert(pending[player], function(value)
		return value + amount
	end)
end
```

```luau Player's server @10
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'
local resave = require(path.to.resave)

local store = DataStoreService:GetDataStore 'players'
local players = resave.store('players', {
	schema = resave.schema { coins = 0 },
})
local sessions = {}
local saved = {}
local pending = {}

local function apply(value, changes)
	for _, change in changes do
		value = change(value)
	end
	return value
end

local function coinsof(player)
	return apply(saved[player], pending[player])
end

local function save(player)
	local changes = pending[player]
	pending[player] = {}

	local ok, cloud = pcall(store.UpdateAsync, store, player.UserId, function(old)
		return apply(old or 0, changes)
	end)
	if ok then
		saved[player] = cloud
	else
		table.move(pending[player], 1, #pending[player], #changes + 1, changes)
		pending[player] = changes
	end
end

Players.PlayerAdded:Connect(function(player)
	local err, session = resave.track(players, tostring(player.UserId))
	if err then
		player:Kick 'Could not load your data, please rejoin'
		return
	end
	sessions[player] = session
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	saved[player] = nil
	pending[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		save(player)
	end
end)

local function earn(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.coins += amount
	end)
end
```

```luau Player's server @12
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'
local resave = require(path.to.resave)

local store = DataStoreService:GetDataStore 'players'
local players = resave.store('players', {
	schema = resave.schema { coins = 0 },
})
local sessions = {}
local saved = {}
local pending = {}

local function apply(value, changes)
	for _, change in changes do
		value = change(value)
	end
	return value
end

local function save(player)
	local changes = pending[player]
	pending[player] = {}

	local ok, cloud = pcall(store.UpdateAsync, store, player.UserId, function(old)
		return apply(old or 0, changes)
	end)
	if ok then
		saved[player] = cloud
	else
		table.move(pending[player], 1, #pending[player], #changes + 1, changes)
		pending[player] = changes
	end
end

Players.PlayerAdded:Connect(function(player)
	local err, session = resave.track(players, tostring(player.UserId))
	if err then
		player:Kick 'Could not load your data, please rejoin'
		return
	end
	sessions[player] = session
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	saved[player] = nil
	pending[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		save(player)
	end
end)

local function earn(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.coins += amount
	end)
end
```

```luau Player's server @14
local DataStoreService = game:GetService 'DataStoreService'
local Players = game:GetService 'Players'
local resave = require(path.to.resave)

local store = DataStoreService:GetDataStore 'players'
local players = resave.store('players', {
	schema = resave.schema { coins = 0 },
})
local sessions = {}
local saved = {}
local pending = {}

local function apply(value, changes)
	for _, change in changes do
		value = change(value)
	end
	return value
end

local function save(player)
	local changes = pending[player]
	pending[player] = {}

	local ok, cloud = pcall(store.UpdateAsync, store, player.UserId, function(old)
		return apply(old or 0, changes)
	end)
	if ok then
		saved[player] = cloud
	else
		table.move(pending[player], 1, #pending[player], #changes + 1, changes)
		pending[player] = changes
	end
end

Players.PlayerAdded:Connect(function(player)
	local err, session = resave.track(players, tostring(player.UserId))
	if err then
		player:Kick 'Could not load your data, please rejoin'
		return
	end
	sessions[player] = session
end)

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	sessions[player] = nil
	if session then resave.free(session) end
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		save(player)
	end
end)

local function earn(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.coins += amount
	end)
end
```

```luau Player's server @16
local Players = game:GetService 'Players'
local resave = require(path.to.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0 },
})
local sessions = {}

Players.PlayerAdded:Connect(function(player)
	local err, session = resave.track(players, tostring(player.UserId))
	if err then
		player:Kick 'Could not load your data, please rejoin'
		return
	end
	sessions[player] = session
end)

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	sessions[player] = nil
	if session then resave.free(session) end
end)

local function earn(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.coins += amount
	end)
end
```

```luau Sender's server @18
local resave = require(path.to.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0 },
})

local function gift(userid, amount)
	resave.saveupdate(players, tostring(userid), function(data)
		data.coins += amount
	end)
end
```

[re-save wraps every save in a record: the data, plus the version of its shape.](code:players.friend)

```cloud
players.friend = {
  data = { coins = 20 },
  version = 0,
}
```

[A bare `20` written by the old code isn't a record, and re-save refuses to load or overwrite it: convert old saves before you switch a live store.](mark:data = »{ coins = 20 })

## The QA story, one last time

[Run it on the re-save version.](code:local players)

1. [The friend joins.](code:PlayerAdded)

```state Session on the player's server
base  = { coins = 20 }
oplog = {}
data  = { coins = 20 }
```

[`resave.track` loads `{ coins = 20 }` into a session: `base` is the last cloud value it saw.](mark:local err, »session -> { coins = 20 })

2. [They earn 5.](code:local function earn)

```state Session on the player's server
base  = { coins = 20 }
oplog = { +5 }
data  = { coins = 25 }
```

[The update joins the session's list of changes,](mark:oplog = »{ +5 }) [and `session.data.coins` is 25 right away: `base` with the changes on top.](mark:data  = »{ coins = 25 })

3. [The tester sends 100.](code:local function gift)

```cloud
players.friend = {
  data = { coins = 120 },
  version = 0,
}
```

[`resave.saveupdate` writes it from the sender's server, and the cloud has 120.](mark:data = »{ coins = 120 })

4. [The friend leaves.](code:PlayerRemoving)

```cloud
players.friend = {
  data = { coins = 125 },
  version = 0,
}
```

```state Session on the player's server
base  = { coins = 125 }
oplog = {}
data  = { coins = 125 }
```

[`resave.free` replays `+5` on top of 120 and saves 125.](mark:resave.free(session) -> { coins = 125 }) [Had the player stayed, the next background save would do the same replay, and `session.data` would pick up the gift.](mark:base  = »{ coins = 125 })

[The list of changes is called an **oplog**,](mark:»oplog = ) [replaying it on top of the newest cloud value is a **rebase**,](mark:data = »{ coins = 125 }) [and that's the whole idea behind re-save: servers don't own a key, they add changes to it.](code:local function earn|local function gift)

## Why session.data is read-only

```state Session on the player's server
base  = { coins = 20 }
oplog = {}
data  = { coins = 20 }
```

```cloud
players.friend = {
  data = { coins = 20 },
  version = 0,
}
```

[A teammate writes the obvious thing.](code:local function earn)

```luau Player's server
local Players = game:GetService 'Players'
local resave = require(path.to.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0 },
})
local sessions = {}

Players.PlayerAdded:Connect(function(player)
	local err, session = resave.track(players, tostring(player.UserId))
	if err then
		player:Kick 'Could not load your data, please rejoin'
		return
	end
	sessions[player] = session
end)

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	sessions[player] = nil
	if session then resave.free(session) end
end)

local function earn(player, amount)
	sessions[player].data.coins += amount
end
```

[It throws the first time anyone earns a coin.](mark:sessions[player].»data.coins += amount -> frozen)

```output Output
attempt to modify a readonly table
```

[A direct write isn't in the oplog, so it couldn't be replayed on top of a gift: it would be the old `coins[player] += amount` bug again.](mark:oplog = »{}) [re-save freezes `session.data`, so the bug fails right away instead of losing coins later.](mark:data  = »{ coins = 20 }) [Every change goes through `resave.queueupdate`.](code:local function earn)

```luau Player's server
local Players = game:GetService 'Players'
local resave = require(path.to.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0 },
})
local sessions = {}

Players.PlayerAdded:Connect(function(player)
	local err, session = resave.track(players, tostring(player.UserId))
	if err then
		player:Kick 'Could not load your data, please rejoin'
		return
	end
	sessions[player] = session
end)

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	sessions[player] = nil
	if session then resave.free(session) end
end)

local function earn(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.coins += amount
	end)
end
```

```output Output
```
