# Schema changes

Change the shape of saved data with migrations. Each `migrate` adds one version; a save at an older version runs the steps it is missing when it loads. Migrations are test-run on the default when the schema is built, so a broken one fails at startup.

```luau
local ServerScriptService = game:GetService 'ServerScriptService'
local resave = require(ServerScriptService.ServerPackages.resave)

local v0 = resave.schema { coins = 0 }

-- version 1: every player gets a gem balance
local v1 = resave.migrate(v0, function(data)
	data.gems = 0
end)

-- version 2: coins become gold, 10 to 1
local v2 = resave.migrate(v1, function(data)
	return { gold = data.coins * 10, gems = data.gems }
end)

local players = resave.store('players', { schema = v2 })
```

Once a version is released, never edit or reorder its migration: add a new one on top. A migration must not yield and must give the same result every time it runs.
