local roblox = require './roblox'
local resave: typeof(require '../../lib') = roblox.require './../../lib'
local shim = roblox

local helpers = require './helpers'
local suite = helpers.suite
local unique = helpers.unique
local record = helpers.record

suite('view', function(s)
	s:case('view_untracked_missing_key_returns_nil_pair', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })

		local err, data = resave.view(st, 'missing')

		t.eq(err, nil)
		t.eq(data, nil)
	end)

	s:case('view_untracked_returns_record', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		shim.stores[name].data.p1 = record({ coins = 7 }, 0)

		local err, data = resave.view(st, 'p1')

		t.eq(err, nil)
		t.eq(data, { coins = 7 })
	end)

	s:case('view_untracked_fails_when_getasync_fails', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })
		shim.stores[name]._failget = true

		local err, data = resave.view(st, 'p1')
		assert(err)

		t.strContains(err, 'get failed')
		t.eq(data, nil)
	end)

	s:case('view_tracked_flushes_pending_and_returns_cloud', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local _, session = resave.track(st, 'p1')
		assert(session)

		resave.queueupdate(session, function(d)
			d.coins += 5
		end)

		shim.stores[name].data.p1.data = { coins = 10 }
		local err, data = resave.view(st, 'p1')

		t.eq(err, nil)
		t.eq(data, { coins = 15 })
		t.eq(shim.stores[name].data.p1.data, { coins = 15 })
	end)

	s:case('view_tracked_fails_when_getasync_fails', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })

		resave.track(st, 'p1')
		shim.stores[name]._failget = true

		local err, data = resave.view(st, 'p1')
		assert(err)

		t.strContains(err, 'get failed')
		t.eq(data, nil)
	end)

	s:case('view_tracked_returns_cloud_data_when_save_fails', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local _, session = resave.track(st, 'p1')
		assert(session)
		resave.queueupdate(session, function(d)
			d.coins += 5
		end)

		-- the callback runs, then the write fails
		local ds = shim.stores[name]
		local realupdate = ds.UpdateAsync
		ds.UpdateAsync = function(self, key, fn)
			fn(table.clone(ds.data[key]))
			error 'write failed'
		end
		local err, data = resave.view(st, 'p1')
		ds.UpdateAsync = realupdate

		-- the saved data, not the unsaved one; the update stays queued for the next save
		t.eq(err, nil)
		t.eq(data, { coins = 0 })
		t.eq(ds.data.p1.data, { coins = 0 })
		t.eq(#session.pendingupdates, 1)
		t.eq(session.data, { coins = 5 })
	end)

	s:case('view_untracked_fails_outdated_when_version_ahead', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })
		shim.stores[name].data.p1 = record({}, 5)

		local ok, err, data = pcall(resave.view, st, 'p1')

		t.that(ok, 'view must not throw')
		t.strContains(err, 'outdated base')
		t.eq(data, nil)
	end)
end)
