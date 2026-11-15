-- What the smoke tests cannot see: session data is read-only and replaced on each
-- update, and loads survive a broken transaction store.
local mock = require '../mock'
local resave: typeof(require '../../../lib') = mock.require '@self/init'

local helpers = require './helpers'
local record = helpers.record
local suite = helpers.suite
local unique = helpers.unique

suite('session', function(s)
	s:case('writing_session_data_directly_throws', function(t)
		local players = resave.store(unique(), { schema = resave.schema { coins = 0 } })
		local _, session = resave.track(players, 'p1')
		assert(session)

		helpers.throwscontains(t, function()
			session.data.coins += 5
		end, 'readonly')
	end)

	s:case('session_data_is_replaced_not_edited', function(t)
		local players = resave.store(unique(), { schema = resave.schema { coins = 0 } })
		local _, session = resave.track(players, 'p1')
		assert(session)

		local held = session.data
		resave.queueupdate(session, function(d)
			d.coins += 5
		end)
		t.eq(held.coins, 0)
		t.eq(session.data.coins, 5)
	end)

	s:case('track_tracks_when_pendingtx_fails_to_resolve', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		mock.stores[name].data.p1 = record(
			{ coins = 5 },
			0,
			{ id = 'tx-x', newdata = { coins = 9 }, version = 0, cooltimestamp = 0 }
		)
		mock.stores.tx._failget = true

		local err, session = resave.track(st, 'p1')

		t.eq(err, nil)
		t.eq(st.tracking.p1, session)
		t.eq(mock.stores[name].data.p1.pendingtx.id, 'tx-x')
		t.strContains(mock.warnings[#mock.warnings], "fail to resolve tx 'tx-x'")
	end)

	s:case('adopts_tx_of_a_locked_record', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })
		mock.stores.tx.data['tx-x'] = { state = 'commited', committimeout = 0, adopts = { [`{name}:p1`] = false } }
		mock.stores[name].data.p1 = record({}, 0, { id = 'tx-x', newdata = {}, version = 0, cooltimestamp = 0 })

		t.eq(resave.delete(st, 'p1'), nil)
		-- the record was the tx's last adopter, so the tx is cleaned up
		t.eq(mock.stores.tx.data['tx-x'], nil)
	end)
end)
