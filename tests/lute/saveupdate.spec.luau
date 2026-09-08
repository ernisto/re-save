local roblox = require './roblox'
local resave: typeof(require '../../lib') = roblox.require './../../lib'
local shim = roblox

local helpers = require './helpers'
local suite = helpers.suite
local unique = helpers.unique

suite('saveupdate', function(s)
	s:case('writes_directly_to_cloud', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err = resave.saveupdate(st, 'p1', function(d)
			d.coins += 5
		end)

		t.eq(err, nil)
		t.eq(shim.stores[name].data.p1.data, { coins = 5 })
	end)

	s:case('keeps_cloud_data_when_update_errors', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err = resave.saveupdate(st, 'p1', function()
			error 'boom'
		end)
		assert(err)

		t.strContains(err, 'boom')
		t.eq(shim.stores[name].data.p1.data, { coins = 0 })
	end)
end)
