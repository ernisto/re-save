local ServerScriptService = game:GetService 'ServerScriptService'

local resave = require(ServerScriptService.packages.resave)

local v0 = resave.schema { coins = 0 }
local v1 = resave.migrate(v0, function(t)
	t.items = {} :: { { id: string } }
	return t
end)
local v2 = resave.migrate(v1, function(t)
	return {
		coins = t.coins,
		inventory = { items = t.items, limit = 10 },
		-- remove `items` field
	}
end)

local plrstore = resave.store('player', { schema = v2 })
print('store', plrstore)

print 'loading ernisto'
local err1, ernisto = resave.track(plrstore, 'ernisto')

print('err:', err1)
assert(err1 == nil and ernisto, err1)

resave.queueupdate(ernisto, function(data)
	data.coins += 10
end)

print('ernisto', resave.view(plrstore, 'ernisto'))
print('david', resave.view(plrstore, 'david'))

print 'loading david'
local err2, david = resave.track(plrstore, 'david')

print('err:', err2)
assert(err2 == nil and david, err2)

print('ernisto', resave.view(plrstore, 'ernisto'))
print('david', resave.view(plrstore, 'david'))

print 'making tx'
local err = resave.savebatch(function(update)
	update(plrstore, 'ernisto', function(data)
		data.coins -= 10
	end)
	update(plrstore, 'david', function(data)
		data.coins += 10
	end)
end)
warn('tx err', err)

print('ernisto', resave.view(plrstore, 'ernisto'))
print('david', resave.view(plrstore, 'david'))

resave.free(ernisto)
resave.free(david)
