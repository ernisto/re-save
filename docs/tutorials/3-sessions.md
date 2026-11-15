# The life of a session

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

```cloud
players.friend = {
  data = { coins = 20 },
  version = 0,
}
```

[A session is one player's save, loaded on one server.](code:local sessions) [Chapter one tracked it on join and freed it on leave.](code:PlayerAdded|PlayerRemoving) [This chapter follows it through everything that can happen in between.](code:local function earn)

## One store, registered once

[Chapter one drew the gift code on another server, but it's one game: every server runs both scripts.](code:local function gift)

```luau Gift script
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

[The second script to register `'players'` throws: a name can be registered once per server.](code:already was registered)

```output Output
a data store already was registered for id 'players'
```

[Two registrations could put two different schemas on one DataStore.](mark:schema = »resave.schema { coins = 0 })

[Register each store in one module,](code:return {)

```luau Stores module
local resave = require(path.to.resave)

return {
	players = resave.store('players', {
		schema = resave.schema { coins = 0 },
	}),
}
```

[and require it from every script that needs the store.](code:require(path.to.stores))

```luau Player's server
local Players = game:GetService 'Players'
local resave = require(path.to.resave)

local players = require(path.to.stores).players
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

```luau Gift script
local resave = require(path.to.resave)

local players = require(path.to.stores).players

local function gift(userid, amount)
	resave.saveupdate(players, tostring(userid), function(data)
		data.coins += amount
	end)
end
```

```output Output
```

## Loading can fail

```luau Gift script
```

```luau Stores module
```

[`resave.track` yields while it reads the DataStore.](code:resave.track) [When it works, `err` is nil and you get the session.](mark:session = »<session 'friend'>)

```state What track returned
err = nil
session = <session 'friend'>
```

[A failed load never throws: the reason comes back as `err`, and there is no session.](mark:local »err, session)

- [The DataStore is down, or throttling requests.](mark:err = »<the DataStore's error>)

```state What track returned
err = <the DataStore's error>
session = nil
```

- [The save was written by a newer version of the game than this server runs.](mark:err = »'… outdated base')

```state What track returned
err = '… outdated base'
session = nil
```

- [The stored value isn't a re-save record, like the bare numbers from chapter one.](mark:err = »'… stored value is not a record')

```state What track returned
err = '… stored value is not a record'
session = nil
```

- [A migration step failed on this player's data.](mark:err = »'… fail to migrate to v1 …')

```state What track returned
err = '… fail to migrate to v1 …'
session = nil
```

[Every time, the stored value is left as it was, and the key isn't tracked.](mark:session = »nil) [So kick: a player without a session has nowhere to queue changes, and must not play on data that can't be saved.](code:player:Kick)

## Leaving while loading

```state What track returned
```

[The load takes a moment, and a player can leave before it ends.](code:resave.track)

```state Timeline
1 PlayerAdded: track starts loading
```

[`PlayerRemoving` runs first, finds no session yet, and frees nothing.](mark:if »session then resave.free(session) end -> nil)

```state Timeline
1 PlayerAdded: track starts loading
2 PlayerRemoving: nothing to free yet
```

[Then `track` returns, and the session is stored for a player who is gone.](code:sessions[player] = session)

```state Timeline
1 PlayerAdded: track starts loading
2 PlayerRemoving: nothing to free yet
3 track returns: session stored, never freed
```

[It stays tracked until the server closes, and if the player comes back to this server, `track` hands them this old session without loading again.](code:3 track returns)

[After the load, check that the player is still here, and free the session if not.](code:IsDescendantOf)

```luau Player's server
local Players = game:GetService 'Players'
local resave = require(path.to.resave)

local players = require(path.to.stores).players
local sessions = {}

Players.PlayerAdded:Connect(function(player)
	local err, session = resave.track(players, tostring(player.UserId))
	if err then
		player:Kick 'Could not load your data, please rejoin'
		return
	end
	if not player:IsDescendantOf(Players) then
		resave.free(session)
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

```state Timeline
1 PlayerAdded: track starts loading
2 PlayerRemoving: nothing to free yet
3 track returns: player is gone, session freed
```

## session.data is a snapshot

```state Timeline
```

```state Session
base  = { coins = 20 }
oplog = {}
data  = { coins = 20 }
```

[A teammate shows the coins on screen, reading `session.data` once and keeping it.](code:local data)

```luau Gameplay code
local function showcoins(player, label)
	local data = sessions[player].data
	while label.Parent do
		label.Text = data.coins
		task.wait(1)
	end
end
```

[The player earns 5.](code:local function earn)

```state Session
base  = { coins = 20 }
oplog = { +5 }
data  = { coins = 25 }
```

[Every update replaces `session.data` with a new frozen table. The old table is never edited.](mark:data  = »{ coins = 25 }) [The variable still holds the old one, so the label says 20 forever.](mark:label.Text = »data.coins -> 20)

[Read `session.data` again every time you need it.](code:label.Text)

```luau Gameplay code
local function showcoins(player, label)
	local session = sessions[player]
	while label.Parent do
		label.Text = session.data.coins
		task.wait(1)
	end
end
```

## Saves happen in the background

```luau Gameplay code
```

[You never call save.](code:local function earn) [A loop inside re-save looks for tracked sessions with something in the oplog,](mark:oplog = »{ +5 }) [and saves them one at a time, waiting for DataStore request budget before each write.](mark:data = »{ coins = 25 })

```cloud
players.friend = {
  data = { coins = 25 },
  version = 0,
}
```

```state Session
base  = { coins = 25 }
oplog = {}
data  = { coins = 25 }
```

[After a save, `base` is the new cloud value and the oplog is empty.](mark:base  = »{ coins = 25 })

[Say the player earns 5 more while the DataStore is down.](code:local function earn)

```state Session
base  = { coins = 25 }
oplog = { +5 }
data  = { coins = 30 }
```

[The save fails. re-save warns, keeps the oplog, and the loop tries again on a later round.](code:[livesync])

```output Output
[livesync] fail to sync 'friend'
```

[Nothing is lost, and `session.data` showed 30 the whole time.](mark:data  = »{ coins = 30 })

[Meanwhile a gift of 100 reaches the cloud from another server.](mark:data = »{ coins = 125 })

```cloud
players.friend = {
  data = { coins = 125 },
  version = 0,
}
```

[Every save is also a load: the next one replays the oplog on the newest cloud value, and the gift lands in `session.data`.](mark:data  = »{ coins = 130 })

```cloud
players.friend = {
  data = { coins = 130 },
  version = 0,
}
```

```state Session
base  = { coins = 130 }
oplog = {}
data  = { coins = 130 }
```

[A session with an empty oplog is left alone, so a gift only shows up at that session's next save.](mark:oplog = »{}) [To pick it up sooner, call `resave.view` on the key: for a tracked key it syncs the session right away.](mark:»base  = )

## Leaving saves what's left

```state Session
base  = { coins = 130 }
oplog = { +5 }
data  = { coins = 135 }
tracked = true
```

[`resave.free` saves what is left in the oplog, stops tracking the session, and freezes it.](code:resave.free(session) end)

```cloud
players.friend = {
  data = { coins = 135 },
  version = 0,
}
```

```state Session
base  = { coins = 135 }
oplog = {}
data  = { coins = 135 }
tracked = false
```

[If that save fails instead, `free` returns the error, and the session stays tracked with its oplog.](mark:if session then »resave.free(session) -> err)

```cloud
players.friend = {
  data = { coins = 130 },
  version = 0,
}
```

```state Session
base  = { coins = 130 }
oplog = { +5 }
data  = { coins = 135 }
tracked = true
```

[The background loop keeps retrying it,](mark:oplog = »{ +5 }) [and when the server shuts down, re-save frees every session that is still tracked.](mark:tracked = »true) [So this handler can ignore the result: read it when you want a log.](code:PlayerRemoving)

[One result is not a failure. When a queued update no longer fits the newest cloud data, like the sword in the last chapter, it is dropped, the rest is saved, the session is freed, and `free` returns what was dropped.](mark:if session then »resave.free(session) -> '[rebase] fail to apply update #1 …')

```cloud
players.friend = {
  data = { coins = 135 },
  version = 0,
}
```

```state Session
base  = { coins = 135 }
oplog = {}
data  = { coins = 135 }
tracked = false
```

## After leaving, the session is dead

[Gameplay code often outlives the player: a timer, a web request that comes back late.](code:task.wait(60))

```luau Gameplay code
local function rewardlater(player)
	local session = sessions[player]
	task.wait(60)
	resave.queueupdate(session, function(data)
		data.coins += 10
	end)
end
```

[If the player left during the wait, the session was freed, and queueing on it throws.](code:data.coins += 10)

```output Output
you can only update tracked records
```

[A change to a freed session could never be saved, so re-save refuses it.](mark:tracked = »false)

[Ask `resave.istracked` before changing a session you held on to.](code:resave.istracked)

```luau Gameplay code
local function rewardlater(player)
	local session = sessions[player]
	task.wait(60)
	if not resave.istracked(session) then return end

	resave.queueupdate(session, function(data)
		data.coins += 10
	end)
end
```

```output Output
```

[`resave.maybetracked` answers from a key instead: the live session on this server, or nil.](code:local function coinsof)

```luau Gameplay code
local function rewardlater(player)
	local session = sessions[player]
	task.wait(60)
	if not resave.istracked(session) then return end

	resave.queueupdate(session, function(data)
		data.coins += 10
	end)
end

local function coinsof(userid)
	local session = resave.maybetracked(players, tostring(userid))
	return session and session.data.coins
end
```

## Players who aren't here

```luau Gameplay code
```

```state Session
```

[Not every player you touch is in your server.](code:local function profile)

```luau Any server
local function profile(userid)
	local err, data = resave.view(players, tostring(userid))
	if err then return 'unavailable' end
	if not data then return 'never played' end
	return `{data.coins} coins`
end

local function gift(userid, amount)
	local err = resave.saveupdate(players, tostring(userid), function(data)
		data.coins += amount
	end)
	return err == nil
end
```

[`resave.view` reads a save without tracking it: a profile page, a leaderboard row.](code:resave.view) [It returns `err` when the read failed,](mark:if »err then return 'unavailable' end) [and no data when the key was never saved. Nothing is created.](mark:if »not data then return 'never played' end) [Keep those two apart: a failed read is not an empty save.](code:'unavailable'|'never played')

[`resave.saveupdate` writes to any key right now, in one `UpdateAsync`: the gift from chapter one.](code:resave.saveupdate)

```cloud
players.friend = {
  data = { coins = 235 },
  version = 0,
}
```

[Its update follows the same rules as a queued one, but a failure is returned, not thrown.](mark:local »err = resave.saveupdate) [An error means this call saved nothing, so calling again is fine.](mark:return »err == nil) [Calling again after a success is not: the gift is added twice.](mark:data = »{ coins = 335 })

```cloud
players.friend = {
  data = { coins = 335 },
  version = 0,
}
```

[When the key is tracked on this server, `saveupdate` goes through its session: the oplog is saved in the same write, and `session.data` shows the result at once.](code:sessions[player] = session) [For a player's own gameplay, keep using `resave.queueupdate`: it costs no DataStore request per change.](code:local function earn)

## Deleting a player

```state Session
base  = { coins = 20 }
oplog = { +5 }
data  = { coins = 25 }
tracked = true
```

```cloud
players.friend = {
  data = { coins = 20 },
  version = 0,
}
```

[`resave.delete` removes a key from the DataStore, for a data deletion request.](code:resave.delete)

```luau Any server
local function erase(userid)
	return resave.delete(players, tostring(userid))
end
```

```cloud
players.friend = nil
```

[It doesn't touch a session.](mark:tracked = »true) [If the player is in a server with unsaved changes, that server's next save writes a record again: the default, plus its oplog.](mark:data = »{ coins = 5 })

```cloud
players.friend = {
  data = { coins = 5 },
  version = 0,
}
```

```state Session
base  = { coins = 5 }
oplog = {}
data  = { coins = 5 }
tracked = true
```

[On this server, free the session before deleting, and kick the player so nothing queues on it again.](code:local session = resave.maybetracked)

```luau Any server
local function erase(userid)
	local key = tostring(userid)
	local session = resave.maybetracked(players, key)
	if session then resave.free(session) end

	local player = Players:GetPlayerByUserId(userid)
	if player then player:Kick 'Your data was deleted' end

	return resave.delete(players, key)
end
```

```cloud
players.friend = nil
```

```state Session
base  = { coins = 25 }
oplog = {}
data  = { coins = 25 }
tracked = false
```

[A session on another server can still write the key back: delete again once the player is offline everywhere.](mark:players.friend = »nil)
