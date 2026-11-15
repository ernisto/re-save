# Changing the save format

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local players = resave.store('players', {
	schema = resave.schema { coins = 0 },
})
```

```cloud
players.veteran = {
  data = { coins = 120 },
  version = 0,
}
```

[The game is live.](code:local players) [Thousands of players have a save shaped like `{ coins = 0 }`.](mark:data = »{ coins = 120 })

## Your designer wants gems

[A second currency. The obvious version adds it to the default,](code:gems = 0 })

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local players = resave.store('players', {
	schema = resave.schema { coins = 0, gems = 0 },
})
```

[then uses it.](code:local function earngems)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local players = resave.store('players', {
	schema = resave.schema { coins = 0, gems = 0 },
})

local function earngems(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.gems += amount
	end)
end
```

[New players get gems. You ship it.](mark:data = »{ coins = 0, gems = 7 })

```cloud
players.veteran = {
  data = { coins = 120 },
  version = 0,
}
players.newbie = {
  data = { coins = 0, gems = 7 },
  version = 0,
}
```

## Returning players crash

[A player from last week opens the shop,](code:players.veteran) [and `data.gems` is nil.](mark:data.gems -> nil)

```output Output
[cloneapply] execution failed:
attempt to perform arithmetic (add) on nil and number
```

## Why it broke

**[The default is only used for a key that doesn't exist yet.](mark:resave.schema »{ coins = 0, gems = 0 })** [The veteran's save was written before gems existed, so it is still `{ coins = 120 }`: nothing ever wrote gems into it.](mark:data = »{ coins = 120 })

[The quick patch handles the old shape where gems are used,](code:(data.gems or 0))

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local players = resave.store('players', {
	schema = resave.schema { coins = 0, gems = 0 },
})

local function earngems(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.gems = (data.gems or 0) + amount
	end)
end
```

[and where they are read.](code:local function gemsof)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local players = resave.store('players', {
	schema = resave.schema { coins = 0, gems = 0 },
})

local function earngems(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.gems = (data.gems or 0) + amount
	end)
end

local function gemsof(player)
	return sessions[player].data.gems or 0
end
```

[It works until next month: the shop, the leaderboard and the trade window each need their own `or 0`.](mark:return sessions[player].data.gems »or 0) [Then the designer adds an item list, and every reader has to handle three shapes.](code:players.veteran|players.newbie) [Whoever forgets one ships the next crash.](mark:data.gems = »(data.gems or 0))

**[Knowledge of every old format is copied into every piece of code that reads the save.](code:local function earngems|local function gemsof)**

## Upgrade the save once, when it loads

[Put that knowledge in one place instead.](code:local players) [Keep the original default as it was,](code:local v0)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local v0 = resave.schema { coins = 0 }

local players = resave.store('players', { schema = v0 })

local function earngems(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.gems = (data.gems or 0) + amount
	end)
end

local function gemsof(player)
	return sessions[player].data.gems or 0
end
```

[and describe the change as a step from the old shape to the new one.](code:local v1)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local v0 = resave.schema { coins = 0 }
local v1 = resave.migrate(v0, function(data)
	data.gems = data.gems or 0
end)

local players = resave.store('players', { schema = v1 })

local function earngems(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.gems = (data.gems or 0) + amount
	end)
end

local function gemsof(player)
	return sessions[player].data.gems or 0
end
```

[Now every other `or 0` can go.](code:local function earngems|local function gemsof)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local v0 = resave.schema { coins = 0 }
local v1 = resave.migrate(v0, function(data)
	data.gems = data.gems or 0
end)

local players = resave.store('players', { schema = v1 })

local function earngems(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.gems += amount
	end)
end

local function gemsof(player)
	return sessions[player].data.gems
end
```

[Every save records which version it has reached.](mark:»version = 0) [Follow the veteran.](code:players.veteran)

1. [The script starts. `resave.migrate` test-runs the step on the default, so a step that breaks on a brand new save errors in Studio, not on a player.](mark:local v1 = »resave.migrate -> { coins = 0 } becomes { coins = 0, gems = 0 })
2. [The veteran joins with `{ coins = 120 }` at version 0: one step behind.](mark:data = »{ coins = 120 }) [The step runs once, and the save is written back at version 1.](mark:data.gems = »data.gems or 0 -> 0)

```cloud
players.veteran = {
  data = { coins = 120, gems = 0 },
  version = 1,
}
players.newbie = {
  data = { coins = 0, gems = 7 },
  version = 0,
}
```

3. [They earn gems, and `data.gems` is a number, always.](code:data.gems += amount)

[The newbie got gems from the edited default, at version 0, so the step keeps what is already there instead of resetting it.](mark:data = »{ coins = 0, gems = 7 })

```cloud
players.veteran = {
  data = { coins = 120, gems = 0 },
  version = 1,
}
players.newbie = {
  data = { coins = 0, gems = 7 },
  version = 1,
}
```

[A brand new player starts from `v0`'s default and takes the same step, so there is one path, not two.](mark:local v0 = resave.schema »{ coins = 0 }) [Code that reads the save only ever sees the newest shape.](code:local function gemsof)

## The next change is one more step

[The item list is just another step on top.](code:local v2)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local v0 = resave.schema { coins = 0 }
local v1 = resave.migrate(v0, function(data)
	data.gems = data.gems or 0
end)
local v2 = resave.migrate(v1, function(data)
	data.items = {}
end)

local players = resave.store('players', { schema = v2 })

local function earngems(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.gems += amount
	end)
end

local function gemsof(player)
	return sessions[player].data.gems
end
```

```cloud
players.sleeper = {
  data = { coins = 3 },
  version = 0,
}
```

[A player who hasn't joined since `v0` runs both steps, in order.](code:local v1|local v2)

```cloud
players.sleeper = {
  data = { coins = 3, gems = 0, items = {} },
  version = 2,
}
```

[`resave.migrate` returns a new schema and leaves the old one as it was, so every version stays a value with a name.](mark:local »v2 = resave.migrate)

[A step is replayed like an update, on every server that loads an old save: no yielding, nothing random, no clock, and a result that can be saved.](code:data.items = {}) [Break one of those and `resave.migrate` throws as the script starts.](mark:local v2 = »resave.migrate)

## Tested on the default, not on your players

[Items get a power stat, looked up by name.](code:local v3)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local v0 = resave.schema { coins = 0 }
local v1 = resave.migrate(v0, function(data)
	data.gems = data.gems or 0
end)
local v2 = resave.migrate(v1, function(data)
	data.items = {}
end)
local v3 = resave.migrate(v2, function(data)
	for i, name in data.items do
		data.items[i] = { name = name, power = POWER[name].base }
	end
end)

local players = resave.store('players', { schema = v3 })

local function earngems(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.gems += amount
	end)
end

local function gemsof(player)
	return sessions[player].data.gems
end
```

[The test-run passes: the default has no items, so the loop never runs.](mark:for i, name in »data.items -> {})

[Then a collector joins, holding a sword from an old event that is no longer in the `POWER` table.](mark:items = »{ 'eventsword' })

```cloud
players.collector = {
  data = {
    coins = 9, gems = 2,
    items = { 'eventsword' },
  },
  version = 2,
}
```

[The step fails on their save, so the load fails: `resave.track` returns the error,](mark:err = »'… fail to migrate to v3 …')

```state What track returned
err = '… fail to migrate to v3 …'
session = nil
```

[and the save stays exactly as it was, at version 2. A half-upgraded save is never loaded and never written.](mark:»version = 2)

[A step has to handle every shape an old save can have, not only the default.](code:local power)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local v0 = resave.schema { coins = 0 }
local v1 = resave.migrate(v0, function(data)
	data.gems = data.gems or 0
end)
local v2 = resave.migrate(v1, function(data)
	data.items = {}
end)
local v3 = resave.migrate(v2, function(data)
	for i, name in data.items do
		local power = POWER[name]
		data.items[i] = { name = name, power = power and power.base or 1 }
	end
end)

local players = resave.store('players', { schema = v3 })

local function earngems(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.gems += amount
	end)
end

local function gemsof(player)
	return sessions[player].data.gems
end
```

[Once the fixed step is out, the collector's next join upgrades the save.](mark:»version = 3)

```cloud
players.collector = {
  data = {
    coins = 9, gems = 2,
    items = { { name = 'eventsword', power = 1 } },
  },
  version = 3,
}
```

```state What track returned
err = nil
session = <session 'collector'>
```

## Never edit a step that shipped

```state What track returned
```

```cloud
players.veteran = {
  data = { coins = 120, gems = 0, items = {} },
  version = 3,
}
players.sleeper = {
  data = { coins = 3 },
  version = 0,
}
```

[The designer wants a welcome gift: 10 gems for everyone.](code:local v1) [The tempting change is to edit the step that creates gems.](mark:data.gems = »(data.gems or 0) + 10)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local v0 = resave.schema { coins = 0 }
local v1 = resave.migrate(v0, function(data)
	data.gems = (data.gems or 0) + 10
end)
local v2 = resave.migrate(v1, function(data)
	data.items = {}
end)
local v3 = resave.migrate(v2, function(data)
	for i, name in data.items do
		local power = POWER[name]
		data.items[i] = { name = name, power = power and power.base or 1 }
	end
end)

local players = resave.store('players', { schema = v3 })

local function earngems(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.gems += amount
	end)
end

local function gemsof(player)
	return sessions[player].data.gems
end
```

[The sleeper is still at version 0, runs the edited step, and gets the gift.](mark:data = »{ coins = 3, gems = 10, items = {} })

```cloud
players.veteran = {
  data = { coins = 120, gems = 0, items = {} },
  version = 3,
}
players.sleeper = {
  data = { coins = 3, gems = 10, items = {} },
  version = 3,
}
```

[The veteran already passed version 1, and a save never runs a step twice: no gift.](mark:data = »{ coins = 120, gems = 0, items = {} })

[Instead, leave shipped steps alone and add the change as a new step at the end: every save runs it exactly once.](code:local v4)

```luau Player's server
local resave = require(path.to.resave)
local sessions = {} -- player → session, from resave.track

local v0 = resave.schema { coins = 0 }
local v1 = resave.migrate(v0, function(data)
	data.gems = data.gems or 0
end)
local v2 = resave.migrate(v1, function(data)
	data.items = {}
end)
local v3 = resave.migrate(v2, function(data)
	for i, name in data.items do
		local power = POWER[name]
		data.items[i] = { name = name, power = power and power.base or 1 }
	end
end)
local v4 = resave.migrate(v3, function(data)
	data.gems += 10
end)

local players = resave.store('players', { schema = v4 })

local function earngems(player, amount)
	resave.queueupdate(sessions[player], function(data)
		data.gems += amount
	end)
end

local function gemsof(player)
	return sessions[player].data.gems
end
```

```cloud
players.veteran = {
  data = { coins = 120, gems = 10, items = {} },
  version = 4,
}
players.sleeper = {
  data = { coins = 3, gems = 10, items = {} },
  version = 4,
}
```

[A save's version is its position in the list of steps.](mark:»version = 4) [So never insert a step in the middle or reorder them either: saves that already passed that position would skip the new step and run the wrong ones.](code:local v1|local v2|local v3|local v4)

## Old servers meet new saves

[When you publish this update, servers that started before it keep running the old code, with a schema that ends at version 3.](code:local v3)

[A player whose save reached version 4 on a new server joins one of them.](mark:»version = 4) [An old server can't step a save backwards, so `resave.track` returns an error and leaves the save alone.](mark:err = »'… outdated base')

```state What track returned
err = '… outdated base'
session = nil
```

[The kick from chapter one tells them to rejoin, and they land on a new server.](mark:session = »nil)

[An old server that already holds a session for that player can't save it anymore either: every save fails the same way until that server shuts down, and its unsaved changes go with it.](code:players.veteran)

[So restart the old servers when you release a change to the save format.](code:local players)

[This is called **schema versioning**, and each step is a **migration**.](code:local v1|local v2|local v3|local v4)
