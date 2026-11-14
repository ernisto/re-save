local roblox = require './roblox'
local task = require '@lute/task'
local storage = roblox.require './../../lib/storage'

local helpers = require './helpers'
local suite = helpers.suite
local unique = helpers.unique

suite('sync', function(s)
	s:case('storage_runs_one_call_per_key_at_a_time', function(t)
		local ds: any = storage.store(unique())
		local active, maxactive, done = 0, 0, 0

		function ds:GetAsync()
			active += 1
			maxactive = math.max(maxactive, active)
			task.wait()
			active -= 1
			return nil
		end

		for _ = 1, 3 do
			task.spawn(function()
				storage.awaitget(ds, 'p1')
				done += 1
			end)
		end
		while done < 3 do
			task.wait()
		end

		t.eq(maxactive, 1)
	end)
end)
