local roblox = require './roblox'
local resave: typeof(require '../../lib') = roblox.require './../../lib'
local shim = roblox
local txstore = shim.stores.tx

local helpers = require './helpers'
local maketest = helpers.maketest
local suite = helpers.suite
local unique = helpers.unique
local record = helpers.record

suite('track', function(s)
	s:case('track_new_key_uses_schema_default_and_persists_record', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, session = resave.track(st, 'p1')
		assert(session)

		t.eq(err, nil)
		t.eq(session.data, { coins = 0 })
		local stored = shim.stores[name].data.p1
		t.eq(stored.version, 0)
		t.eq(stored.data, { coins = 0 })
	end)

	s:case('track_migrates_stored_data', function(t)
		local name = unique()
		local schema = resave.migrate(resave.schema { v = 0 }, function(d)
			d.v += 1
			return d
		end)
		local st = resave.store(name, { schema = schema })
		shim.stores[name].data.p1 = record({ v = 0 }, 0)

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		t.eq(err, nil :: any)
		t.eq(session.data, { v = 1 })
		t.eq(shim.stores[name].data.p1.version, 1)
	end)

	s:case('track_returns_original_data_when_migration_fails', function(t)
		local name = unique()
		local schema = resave.migrate(resave.schema { nested = { x = 0 } }, function(d)
			d.nested.x += 1
			return d
		end)
		local st = resave.store(name, { schema = schema })
		shim.stores[name].data.p1 = record({ missing = true }, 0)

		local err, session = resave.track(st, 'p1')
		assert(session)

		t.eq(err, nil)
		t.eq(session.data, { missing = true } :: any)
	end)

	s:case('track_fails_outdated_when_version_ahead', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })
		shim.stores[name].data.p1 = record({}, 5)

		-- assert surfaces as the returned error via the xpcall'd UpdateAsync
		local err, session = resave.track(st, 'p1')
		assert(err)

		t.strContains(err, 'outdated base')
		t.eq(session, nil)
		t.eq(st.tracking.p1, nil)
	end)

	s:case('track_uses_default_for_non_record_value', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		shim.stores[name].data.p1 = 'garbage'

		local err, session = resave.track(st, 'p1')
		assert(session)

		t.eq(err, nil)
		t.eq(session.data, { coins = 0 })
	end)

	s:case('track_fails_and_untracks_when_updateasync_fails', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })
		shim.stores[name]._failupdate = true

		local err, session = resave.track(st, 'p1')
		assert(err)

		t.strContains(err, 'update failed')
		t.eq(session, nil)
		t.eq(st.tracking.p1, nil)
	end)

	s:case('track_returns_cached_loaded_session', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, first = resave.track(st, 'p1')
		assert(first, err)

		resave.queueupdate(first, function(d)
			d.coins += 1
		end)

		local err2, second = resave.track(st, 'p1')

		t.eq(err2, nil)
		t.eq(second, first)
	end)

	s:case('track_freezes_session_data', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		t.throws(function()
			session.data.coins = 1
		end)
	end)

	s:case('track_resolves_commited_pendingtx', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		maketest('tx-c', { state = 'commited' })
		shim.stores[name].data.p1 = record(
			{ coins = 5 },
			0,
			{ id = 'tx-c', newdata = { coins = 9 }, version = 0, cooltimestamp = 0 }
		)

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		t.eq(err, nil :: any)
		t.eq(session.data, { coins = 9 })
		t.eq(shim.stores[name].data.p1.pendingtx, nil)
		t.eq(txstore.data['tx-c'], nil)
	end)

	s:case('track_resolves_aborted_pendingtx_when_tx_missing', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		shim.stores[name].data.p1 = record(
			{ coins = 5 },
			0,
			{ id = 'tx-gone', newdata = { coins = 9 }, version = 0, cooltimestamp = 0 }
		)

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		t.eq(err, nil :: any)
		t.eq(session.data, { coins = 5 })
		t.eq(shim.stores[name].data.p1.pendingtx, nil)
	end)

	s:case('track_fails_while_pendingtx_unexpired', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		maketest('tx-live', {})
		shim.stores[name].data.p1 = record(
			{ coins = 5 },
			0,
			{ id = 'tx-live', newdata = { coins = 9 }, version = 0, cooltimestamp = 0 }
		)

		local err, session = resave.track(st, 'p1')
		assert(err)

		t.strContains(err, 'pending tx')
		t.eq(session, nil)
		t.eq(st.tracking.p1, nil)
	end)

	s:case('track_resolves_expired_pendingtx_as_aborted', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		maketest('tx-old', { committimeout = os.time() - 10 })
		shim.stores[name].data.p1 = record(
			{ coins = 5 },
			0,
			{ id = 'tx-old', newdata = { coins = 9 }, version = 0, cooltimestamp = 0 }
		)

		local err, session = resave.track(st, 'p1')
		assert(session, err)

		t.eq(err, nil :: any)
		t.eq(session.data, { coins = 5 })
		t.eq(shim.stores[name].data.p1.pendingtx, nil)
	end)
end)
