local roblox = require './roblox'
local task = require '@lute/task'
local resave: typeof(require '../../lib') = roblox.require './../../lib'
local storage = roblox.require './../../lib/storage'
local shim = roblox

local helpers = require './helpers'
local suite = helpers.suite
local unique = helpers.unique

local function haswarning(needle: string): boolean
	for _, warning in shim.warnings do
		if string.find(warning, needle, 1, true) then return true end
	end
	return false
end

local function add(amount: number)
	return function(d)
		d.coins += amount
	end
end

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

	s:case('saved_updates_leave_pending_list', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		resave.queueupdate(session, add(1))
		resave.queueupdate(session, add(2))
		t.eq(resave.free(session), nil)

		t.eq(#session.pendingupdates, 0)
		t.eq(shim.stores[name].data.p1.data, { coins = 3 })
	end)

	s:case('update_queued_during_save_stays_pending', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		resave.queueupdate(session, add(1))
		resave.queueupdate(session, add(2))

		local ds = shim.stores[name]
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
		t.eq(shim.stores[name].data.p1.data, { coins = 3 })
	end)

	s:case('failed_write_keeps_updates_pending', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		resave.queueupdate(session, add(1))

		local ds = shim.stores[name]
		local realupdate = ds.UpdateAsync
		function ds:UpdateAsync(key, update)
			realupdate(self, key, function(value)
				update(value)
				error 'write failed'
			end)
		end

		local freeerr = resave.free(session)
		ds.UpdateAsync = realupdate

		t.strContains(tostring(freeerr), 'write failed')
		t.eq(#session.pendingupdates, 1)
		t.eq(session.data, { coins = 1 })

		t.eq(resave.free(session), nil)
		t.eq(shim.stores[name].data.p1.data, { coins = 1 })
	end)

	s:case('livesync_warns_when_sync_fails', function(t)
		local name = unique()
		local key = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, session = resave.track(st, key)
		assert(session, err)

		shim.stores[name]._failupdate = true
		resave.queueupdate(session, add(1))

		local deadline = os.clock() + 3
		while not haswarning(`[livesync] fail to sync '{key}'`) and os.clock() < deadline do
			task.wait()
		end
		shim.stores[name]._failupdate = nil

		t.that(haswarning(`[livesync] fail to sync '{key}'`), 'expected livesync warning')
		t.eq(resave.free(session), nil)
	end)

	-- runs last: closing cancels the background sync loop
	s:case('close_warns_when_save_fails', function(t)
		local name = unique()
		local key = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, session = resave.track(st, key)
		assert(session, err)

		shim.stores[name]._failupdate = true
		resave.queueupdate(session, add(1))
		shim.close()
		shim.stores[name]._failupdate = nil

		t.that(haswarning(`[bindtoclose] fail to save '{key}'`), 'expected bindtoclose warning')
	end)
end)
