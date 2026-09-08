local roblox = require './roblox'
local resave: typeof(require '../../lib') = roblox.require './../../lib'

local helpers = require './helpers'
local throwscontains = helpers.throwscontains
local suite = helpers.suite
local unique = helpers.unique

suite('store', function(s)
	s:case('rejects_duplicate_store_name', function(t)
		local name = unique()
		resave.store(name, { schema = resave.schema {} })

		throwscontains(t, function()
			resave.store(name, { schema = resave.schema {} })
		end, 'already was registered')
	end)
end)
