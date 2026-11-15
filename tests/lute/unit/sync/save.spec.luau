-- Background saving: one storage call per key at a time, updates queued mid-save,
-- and the request budget.
local mock = require '../../mock'
local task = require '@lute/task'
local storage = mock.require '@self/storage'
local resave: typeof(require '../../../../lib') = mock.require '@self/init'

local helpers = require '../helpers'
local suite = helpers.suite
local unique = helpers.unique

local function add(amount: number)
	return function(d)
		d.coins += amount
	end
end

suite('sync save', function(s)
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

	s:case('update_queued_during_save_stays_pending', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		resave.queueupdate(session, add(1))
		resave.queueupdate(session, add(2))

		local ds = mock.stores[name]
		local realupdate = ds.UpdateAsync
		function ds:UpdateAsync(key, update)
			local new = realupdate(self, key, update)
			resave.queueupdate(session, add(10))
			return new
		end

		t.eq(resave.free(session), nil)
		ds.UpdateAsync = realupdate

		t.eq(#session.pendingupdates, 1)
		t.eq(session.data, { coins = 13 })
		t.eq(mock.stores[name].data.p1.data, { coins = 3 })
	end)

	s:case('livesync_waits_for_budget', function(t)
		local resave = helpers.liveresave()
		local name = unique()
		local key = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, session = resave.track(st, key)
		assert(session, err)

		mock.setbudget(0)
		resave.queueupdate(session, add(1))
		local deadline = os.clock() + 0.3
		while os.clock() < deadline do
			task.wait()
		end
		t.eq(mock.stores[name].data[key].data, { coins = 0 })

		mock.setbudget(100)
		deadline = os.clock() + 3
		while mock.stores[name].data[key].data.coins == 0 and os.clock() < deadline do
			task.wait()
		end
		t.eq(mock.stores[name].data[key].data, { coins = 1 })
		t.eq(resave.free(session), nil)
	end)
end)
