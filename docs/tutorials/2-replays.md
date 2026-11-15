# Updates run more than once

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track
```

```state Session
base  = { coins = 20 }
oplog = {}
data  = { coins = 20 }
```

[Every change now goes through `resave.queueupdate`, on the sessions the last chapter tracks.](code:local sessions) [This chapter is about what you can put inside one.](mark:»oplog = )

## Your designer wants a daily chest

[Opening it gives between 1 and 100 coins.](code:local function openchest)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local function openchest(player)
end
```

[The obvious version rolls inside the update.](code:math.random)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local function openchest(player)
	resave.queueupdate(sessions[player], function(data)
		data.coins += math.random(1, 100)
	end)
end
```

## It throws

[`resave.queueupdate` throws as soon as the chest opens,](code:resave.queueupdate)

```output Output
[cloneapply] 2nd execution produced a different result from 1st result
```

[and nothing was queued: the session is untouched.](mark:oplog = »{})

## Why it broke

[Go back to the gift story. `+5` ran when it was queued, on the session's copy, so the player saw 25.](mark:run 1, queued: »20 + 5 = 25)

```state Runs of one update
run 1, queued: 20 + 5 = 25
```

[It ran again at save time, on top of the gift: same function, different data.](mark:run 2, saved: »120 + 5 = 125)

```state Runs of one update
run 1, queued: 20 + 5 = 25
run 2, saved: 120 + 5 = 125
```

[If the cloud write fails, it runs again on the next save,](mark:run 3, retry: »120 + 5 = 125)

```state Runs of one update
run 1, queued: 20 + 5 = 25
run 2, saved: 120 + 5 = 125
run 3, retry: 120 + 5 = 125
```

[and Roblox can call an `UpdateAsync` callback more than once when servers race.](code:run 3, retry)

**[An update isn't run once. It's replayed, as many times as saving takes.](code:resave.queueupdate)**

[With `math.random` inside, each replay rolls again:](mark:math.random(1, 100) -> 37, then 81, then …)

```state Runs of one update
run 1, queued: 20 + 37 = 57
run 2, saved: 120 + 81 = 201
```

[the player sees 37 on screen,](mark:run 1, queued: 20 + »37) [and the save gives them 81.](mark:run 2, saved: 120 + »81)

[re-save runs every update twice when you queue it and compares the two results, so this fails here, in your code, not later as a strange coin count.](code:resave.queueupdate) [Two rolls can match by luck, so the check is a tripwire, not a proof: keeping updates repeatable is your rule to follow.](mark:»math.random(1, 100))

## Decide first, record the decision

```state Runs of one update
```

[The roll is a decision, and the update should only record a decision that was already made.](code:local reward)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local function openchest(player)
	local reward = math.random(1, 100)
	resave.queueupdate(sessions[player], function(data)
		data.coins += reward
	end)
end
```

1. [The roll happens once, outside the update.](code:local reward) [Say it's 37.](mark:math.random(1, 100) -> 37)
2. [The update only adds that number.](code:data.coins += reward)

```state Session
base  = { coins = 20 }
oplog = { +37 }
data  = { coins = 57 }
```

```state Runs of one update
run 1, queued: 20 + 37 = 57
```

[Queued, saved, retried: every run adds 37.](mark:data.coins += »reward -> 37)

```state Runs of one update
run 1, queued: 20 + 37 = 57
run 2, saved: 120 + 37 = 157
```

[The screen and the save agree.](mark:data  = »{ coins = 57 }) [The same goes for the clock and anything else that changes between runs: read it outside, pass the value in.](code:local reward)

## Check inside, not before

```state Runs of one update
```

```state Session
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

[The shop sells a sword for 10 coins.](code:local function buysword)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local function buysword(player)
	local session = sessions[player]
	if session.data.coins < 10 then return end

	resave.queueupdate(session, function(data)
		data.coins -= 10
		data.sword = true
	end)
end
```

[The obvious version checks the coins, then queues the purchase.](code:if session.data.coins < 10)

1. [A player with 20 coins buys the sword: the check passes, and the session shows 10 coins and a sword.](mark:data  = »{ coins = 10, sword = true })

```state Session
base  = { coins = 20 }
oplog = { buy sword }
data  = { coins = 10, sword = true }
```

2. [Before that is saved, another server takes 15 coins from the same player: a trade they set up earlier.](mark:data = »{ coins = 5 })

```cloud
players.friend = {
  data = { coins = 5 },
  version = 0,
}
```

3. [The next save replays the purchase on the 5 coins that are left.](code:resave.queueupdate)

```cloud
players.friend = {
  data = { coins = -5, sword = true },
  version = 0,
}
```

```state Session
base  = { coins = -5, sword = true }
oplog = {}
data  = { coins = -5, sword = true }
```

[The check isn't part of the update, so it doesn't run again: -5 coins and a free sword.](mark:data = »{ coins = -5, sword = true })

[The check ran once, on old data. Only the update is replayed, so the check belongs inside it.](code:assert)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local function buysword(player)
	local session = sessions[player]

	resave.queueupdate(session, function(data)
		assert(data.coins >= 10, 'not enough coins')
		data.coins -= 10
		data.sword = true
	end)
end
```

```state Session
base  = { coins = 5 }
oplog = {}
data  = { coins = 5 }
```

```cloud
players.friend = {
  data = { coins = 5 },
  version = 0,
}
```

[An update can fail on purpose. A player with 5 coins makes `resave.queueupdate` throw, and nothing changes: catch it to tell them why.](mark:»data.coins >= 10 -> 5 >= 10)

```output Output
[cloneapply] execution failed:
not enough coins
```

## The purchase, replayed

```state Session
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

[Run the shop story on the fixed code.](code:local function buysword)

1. [The player with 20 coins buys the sword: the `assert` passes on the session's copy.](mark:»data.coins >= 10 -> 20 >= 10)

```state Session
base  = { coins = 20 }
oplog = { buy sword }
data  = { coins = 10, sword = true }
```

2. [The other server takes 15 coins.](mark:data = »{ coins = 5 })

```cloud
players.friend = {
  data = { coins = 5 },
  version = 0,
}
```

3. [The next save replays the purchase on 5 coins, and this time the `assert` runs again and fails.](mark:»data.coins >= 10 -> 5 >= 10)

```output Output
[rebase] fail to apply update #1
not enough coins
```

[re-save drops that one update with a warning and saves the rest.](code:[rebase] fail)

```state Session
base  = { coins = 5 }
oplog = {}
data  = { coins = 5 }
```

[The session now shows what was really saved: 5 coins, no sword.](mark:data  = »{ coins = 5 }) [The cloud never went below zero.](mark:data = »{ coins = 5 })

[When the save is the player leaving, `resave.free` returns that message, so you can log what was dropped.](code:update #1)

## The other rules come from the same place

```state Session
```

```cloud
```

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local function setrank(player)
	resave.queueupdate(sessions[player], function(data)
		data.rank = fetchrank(player) -- a web request
	end)
end

local function setspawn(player, position)
	resave.queueupdate(sessions[player], function(data)
		data.spawn = position -- a Vector3
	end)
end

local function namepet(player, name)
	resave.queueupdate(sessions[player], function(data)
		data.pet = name -- 'Señor Bigotes'
	end)
end
```

[Replays explain every other rule for updates.](code:resave.queueupdate)

- **[No yielding.](code:local function setrank)** [A save is waiting on the update, and every replay would send the web request again.](mark:data.rank = »fetchrank(player))

```output Output
[cloneapply] execution failed:
attempt to yield in a update
```

[Do the request first, then queue an update that only writes its result.](code:local rank)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local function setrank(player)
	local rank = fetchrank(player)
	resave.queueupdate(sessions[player], function(data)
		data.rank = rank
	end)
end

local function setspawn(player, position)
	resave.queueupdate(sessions[player], function(data)
		data.spawn = position -- a Vector3
	end)
end

local function namepet(player, name)
	resave.queueupdate(sessions[player], function(data)
		data.pet = name -- 'Señor Bigotes'
	end)
end
```

```output Output
```

- **[Only data that saves.](code:local function setspawn)** [A DataStore holds JSON, and a `Vector3`, a `CFrame` or an Instance isn't JSON.](mark:data.spawn = »position)

```output Output
[cloneapply] result not savable as json
```

[Save plain numbers, and build the `Vector3` again when you load.](code:data.spawn)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local function setrank(player)
	local rank = fetchrank(player)
	resave.queueupdate(sessions[player], function(data)
		data.rank = rank
	end)
end

local function setspawn(player, position)
	resave.queueupdate(sessions[player], function(data)
		data.spawn = { x = position.X, y = position.Y, z = position.Z }
	end)
end

local function namepet(player, name)
	resave.queueupdate(sessions[player], function(data)
		data.pet = name -- 'Señor Bigotes'
	end)
end
```

```output Output
```

- **[ASCII text only.](code:local function namepet)** [re-save rejects any string with a non-ASCII character, so a name the player typed can throw.](mark:data.pet = »name)

```output Output
[cloneapply] result contains non-ascii characters
```

[Filter the name as usual, then keep it ASCII or store it encoded, for example as its list of code points.](code:data.pet)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local function setrank(player)
	local rank = fetchrank(player)
	resave.queueupdate(sessions[player], function(data)
		data.rank = rank
	end)
end

local function setspawn(player, position)
	resave.queueupdate(sessions[player], function(data)
		data.spawn = { x = position.X, y = position.Y, z = position.Z }
	end)
end

local function namepet(player, name)
	local codes = { utf8.codepoint(name, 1, -1) }
	resave.queueupdate(sessions[player], function(data)
		data.pet = codes
	end)
end
```

```output Output
```

[All three are checked when you queue, on the update's first run: a value that can't be saved fails here, in the function that made it, not later at save time.](code:local function setrank|local function setspawn|local function namepet)
