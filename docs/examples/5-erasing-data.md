# Erasing data

Handle a data erasure request (for example, a GDPR right-to-erasure message). Free the session first if the player is tracked on this server, so the session can't write the key again, then delete it.

```luau
local Players = game:GetService 'Players'
local ServerScriptService = game:GetService 'ServerScriptService'
local resave = require(ServerScriptService.ServerPackages.resave)

local players = resave.store('players', {
	schema = resave.schema { coins = 0 },
})

local function erase(userid)
	local key = tostring(userid)
	local session = resave.maybetracked(players, key)
	if session then resave.free(session) end

	local player = Players:GetPlayerByUserId(userid)
	if player then player:Kick 'Your data was deleted' end

	return resave.delete(players, key)
end
```
