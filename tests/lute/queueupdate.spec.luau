local roblox = require './roblox'
local resave: typeof(require '../../lib') = roblox.require './../../lib'
local shim = roblox

local helpers = require './helpers'
local throwscontains = helpers.throwscontains
local suite = helpers.suite
local unique = helpers.unique

suite('queueupdate', function(s)
	s:case('applies_update_locally_and_queues', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		resave.queueupdate(session, function(d)
			d.coins += 5
		end)

		t.eq(session.data, { coins = 5 })
		t.eq(#session.pendingupdates, 1)
		t.eq(shim.stores[name].data.p1.data, { coins = 0 })
	end)

	s:case('rejects_untracked_session', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		resave.free(session)

		t.throwsWith('tracked records', function()
			resave.queueupdate(session, function(d) end)
		end)
	end)

	s:case('rejects_erroring_update', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		throwscontains(t, function()
			resave.queueupdate(session, function()
				error 'boom'
			end)
		end, 'boom')
	end)

	s:case('rejects_yielding_update', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		throwscontains(t, function()
			resave.queueupdate(session, function()
				coroutine.yield()
			end)
		end, 'attempt to yield in a update')
	end)

	s:case('rejects_unserializable_result', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		throwscontains(t, function()
			resave.queueupdate(session, function(d)
				d.__jsonfail = true
			end)
		end, 'not savable as json')
	end)

	s:case('rejects_non_ascii_result', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		throwscontains(t, function()
			resave.queueupdate(session, function(d)
				d.__nonascii = true
			end)
		end, 'non-ascii')
	end)

	s:case('rejects_impure_update', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		local runs = 0
		throwscontains(t, function()
			resave.queueupdate(session, function(d)
				runs += 1
				d.x = runs
			end)
		end, '2nd execution produced a different result')
	end)
end)
