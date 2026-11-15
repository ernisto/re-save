-- savebatch locking: tx ids, duplicate keys, failed and leftover locks.
local mock = require '../../mock'
local resave: typeof(require '../../../../lib') = mock.require '@self/init'
local txstore = mock.stores.tx

local helpers = require '../helpers'
local throwscontains = helpers.throwscontains
local record = helpers.record
local suite = helpers.suite
local unique = helpers.unique

suite('savebatch locks', function(s)
	s:case('fails_when_tx_id_collides', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		txstore.data[mock.guidpeek()] = { state = 'pending', adopts = {}, committimeout = os.time() + 60 }

		local err = resave.savebatch(function(queue)
			queue(st, 'a', function(d)
				d.coins += 3
			end)
		end)
		assert(err)

		t.strContains(err, 'already exists')
		t.eq(mock.stores[name].data.a, nil)
	end)

	s:case('rejects_duplicate_update_for_same_key', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })
		resave.track(st, 'a')

		throwscontains(t, function()
			resave.savebatch(function(queue)
				queue(st, 'a', function(d) end)
				queue(st, 'a', function(d) end)
			end)
		end, 'already defined a tx')
	end)

	s:case('aborts_when_a_lock_fails', function(t)
		local a, b = unique(), unique()
		local sa = resave.store(a, { schema = resave.schema { coins = 0 } })
		local sb = resave.store(b, { schema = resave.schema { coins = 0 } })
		mock.stores[b]._failupdate = true

		local err = resave.savebatch(function(queue)
			queue(sa, 'a', function(d)
				d.coins += 3
			end)
			queue(sb, 'b', function(d)
				d.coins += 4
			end)
		end)
		assert(err)

		t.strContains(err, 'update failed')
		-- good session is locked then unlocked by the abort, data untouched
		t.eq(mock.stores[a].data.a.data, { coins = 0 })
		t.eq(mock.stores[a].data.a.pendingtx, nil)
		-- failed session never wrote
		t.eq(mock.stores[b].data.b, nil)
	end)

	s:case('leaves_no_lock_when_record_has_resolvable_old_tx', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		mock.stores[name].data.a = record(
			{ coins = 5 },
			0,
			{ id = 'tx-gone', newdata = { coins = 9 }, version = 0, cooltimestamp = 0 }
		)

		local err = resave.savebatch(function(queue)
			queue(st, 'a', function(d)
				d.coins += 3
			end)
		end)
		assert(err)

		-- old lock resolved as aborted; the failed batch must not lock again
		t.strContains(err, 'pending tx')
		t.eq(mock.stores[name].data.a, record({ coins = 5 }, 0))
	end)
end)
