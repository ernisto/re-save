local roblox = require './roblox'
local resave: typeof(require '../../lib') = roblox.require './../../lib'
local shim = roblox

local helpers = require './helpers'
local suite = helpers.suite
local unique = helpers.unique

suite('free', function(s)
	s:case('noop_when_not_alive', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		resave.free(session)
		t.eq(resave.free(session), nil)
	end)

	s:case('untracks_and_freezes_session', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		local err2 = resave.free(session)
		t.eq(err2, nil)

		t.eq(st.tracking.p1, nil)
		t.throws(function()
			session.data = {}
		end)
	end)

	s:case('flushes_pending_updates_to_cloud', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		resave.queueupdate(session, function(d)
			d.coins += 5
		end)

		t.eq(resave.free(session), nil)

		t.eq(shim.stores[name].data.p1.data, { coins = 5 })
		t.eq(st.tracking.p1, nil)
	end)

	s:case('keeps_session_when_flush_fails', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		resave.queueupdate(session, function(d)
			d.coins += 5
		end)

		shim.stores[name]._failupdate = true
		local err2 = resave.free(session)
		assert(err2)

		t.strContains(err2, 'update failed')
		t.eq(st.tracking.p1, session)
	end)

	s:case('skips_flush_that_fails_against_new_cloud_data', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { x = 0 } })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		resave.queueupdate(session, function(d)
			d.x += 1
		end)

		-- cloud data changes shape underneath so the queued op no longer applies
		shim.stores[name].data.p1.data = {}
		local err2 = resave.free(session)

		t.eq(err2, nil)
		t.eq(shim.stores[name].data.p1.data, {})
	end)
end)
