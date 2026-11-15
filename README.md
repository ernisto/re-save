<p align="center">
	<img src="scripts/docgen/site/icon.svg" width="96" alt="re-save icon">
</p>

<h1 align="center">re-save</h1>

<p align="center">
	Session-based DataStore saving for Roblox, with an oplog, schema migrations and multi-key transactions.
</p>

<p align="center">
	<a href="https://github.com/ernisto/re-save/actions/workflows/check.yml"><img src="https://github.com/ernisto/re-save/actions/workflows/check.yml/badge.svg" alt="Tests"></a>
</p>

<p align="center">
	<a href="https://ernisto.github.io/re-save/">Docs</a> ·
	<a href="https://ernisto.github.io/re-save/#tutorials">Tutorials</a> ·
	<a href="https://ernisto.github.io/re-save/#examples">Examples</a> ·
	<a href="https://ernisto.github.io/re-save/#reference">API Reference</a> ·
	<a href="https://github.com/ernisto/re-save/releases/latest/download/resave.rbxm">Download</a>
</p>

## Features

- **No session locks**: a key can be open on more than one server. Each session keeps its changes in an oplog and replays them on the newest saved data, so no change is lost.
- **Change now, save later**: `queueupdate` changes `session.data` at once; the oplog is saved in the background, on `free` and on shutdown.
- **Versioned schemas**: migrations upgrade old saves when they load, and are test-run when the schema is built, so a broken one fails at startup.
- **Transactions**: `savebatch` changes several keys at once, or none of them.

## Installation

- **Wally**: add to `wally.toml`, then run `wally install`
```toml
[server-dependencies]
resave = "ernisto/re-save@0.1.0-alpha.7"
```

- **pesde**:
```sh
pesde add wally#ernisto/re-save
```

- **Model file**: [download `resave.rbxm`](https://github.com/ernisto/re-save/releases/latest/download/resave.rbxm) from the [latest release](https://github.com/ernisto/re-save/releases/latest) and put it in ServerScriptService.

## Quick look

```luau
local Players = game:GetService 'Players'
local ServerScriptService = game:GetService 'ServerScriptService'
local resave = require(ServerScriptService.ServerPackages.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0 },
})

Players.PlayerAdded:Connect(function(player)
	local err = resave.track(players, tostring(player.UserId))
	if err then player:Kick 'Could not load your data, please rejoin' end
end)

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
```

New here? Start with the [tutorials](https://ernisto.github.io/re-save/#tutorials).

## License

[MIT](LICENSE). re-save is rewritten from [drop](https://github.com/jackhexed/drop) by [jackhexed](https://github.com/jackhexed) (formerly jackdotink), also MIT licensed.
