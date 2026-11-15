# Installing

## Add the package

re-save is published on Wally. It only runs on the server, so add it as a server dependency in `wally.toml`:

```toml
[server-dependencies]
resave = "ernisto/re-save@{{version}}"
```

Then run `wally install`.

With pesde, `pesde add wally#ernisto/re-save` does the same.

Without a package manager, [download resave.rbxm](https://github.com/ernisto/re-save/releases/latest/download/resave.rbxm) from the [latest GitHub release](https://github.com/ernisto/re-save/releases/latest) and put it in ServerScriptService.

## Require it

Wally installs server packages in `ServerPackages`: require re-save from wherever your Rojo project puts that folder, and register each store once, when the server starts.

```luau
local ServerScriptService = game:GetService 'ServerScriptService'
local resave = require(ServerScriptService.ServerPackages.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0 },
})
```

From here, everything in the earlier chapters works as shown.
