local roblox = require './roblox'
local resave: typeof(require '../../lib') = roblox.require './../../lib'
local shim = roblox
local txstore = shim.stores.tx

local helpers = require './helpers'
local throwscontains = helpers.throwscontains
local maketest = helpers.maketest
local record = helpers.record
local suite = helpers.suite
local unique = helpers.unique

suite('savebatch', function(s)
	s:case('commits_all_updates_and_deletes_tx', function(t)
		local a, b = unique(), unique()
		local sa = resave.store(a, { schema = resave.schema { coins = 0 } })
		local sb = resave.store(b, { schema = resave.schema { coins = 0 } })

		local err = resave.savebatch(function(queue)
			queue(sa, 'a', function(d)
				d.coins += 3
			end)
			queue(sb, 'b', function(d)
				d.coins += 4
			end)
		end)

		t.eq(err, nil)
		t.eq(shim.stores[a].data.a.data, { coins = 3 })
		t.eq(shim.stores[b].data.b.data, { coins = 4 })
		t.eq(shim.stores[a].data.a.pendingtx, nil)
		t.eq(next(txstore.data), nil)
	end)

	s:case('fails_when_tx_id_collides', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		txstore.data[shim.guidpeek()] = { state = 'pending', adopts = {}, committimeout = os.time() + 60 }

		local err = resave.savebatch(function(queue)
			queue(st, 'a', function(d)
				d.coins += 3
			end)
		end)
		assert(err)

		t.strContains(err, 'already exists')
		t.eq(shim.stores[name].data.a, nil)
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
		shim.stores[b]._failupdate = true

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
		t.eq(shim.stores[a].data.a.data, { coins = 0 })
		t.eq(shim.stores[a].data.a.pendingtx, nil)
		-- failed session never wrote
		t.eq(shim.stores[b].data.b, nil)
	end)

	s:case('defers_lock_while_other_pendingtx_unexpired', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		maketest('tx-live', {})
		shim.stores[name].data.a = record(
			{ coins = 5 },
			0,
			{ id = 'tx-live', newdata = { coins = 9 }, version = 0, cooltimestamp = 0 }
		)

		local err = resave.savebatch(function(queue)
			queue(st, 'a', function(d)
				d.coins += 3
			end)
		end)
		assert(err)

		t.strContains(err, 'pending tx')
		t.eq(shim.stores[name].data.a.data, { coins = 5 })
		t.eq(shim.stores[name].data.a.pendingtx.id, 'tx-live')
	end)

	s:case('leaves_no_lock_when_record_has_resolvable_old_tx', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		shim.stores[name].data.a = record(
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
		t.eq(shim.stores[name].data.a, record({ coins = 5 }, 0))
	end)

	s:case('aborts_without_locks_when_an_update_fails_its_check', function(t)
		local a, b = unique(), unique()
		local sa = resave.store(a, { schema = resave.schema { coins = 0 } })
		local sb = resave.store(b, { schema = resave.schema { coins = 0 } })
		local calls = 0

		local err = resave.savebatch(function(queue)
			queue(sa, 'a', function(d)
				d.coins += 3
			end)
			queue(sb, 'b', function(d)
				calls += 1
				d.coins = calls
			end)
		end)
		assert(err)

		t.strContains(err, 'different result')
		t.eq(shim.stores[a].data.a, nil)
		t.eq(shim.stores[b].data.b, nil)
	end)

	s:case('rejects_duplicate_update_for_same_untracked_key', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })

		throwscontains(t, function()
			resave.savebatch(function(queue)
				queue(st, 'a', function(d) end)
				queue(st, 'a', function(d) end)
			end)
		end, 'already defined a tx')
		t.eq(shim.stores[name].data.a, nil)
	end)

	s:case('drops_tx_and_locks_when_commit_fails', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		-- tx store: 1st update creates the tx, 2nd commits it
		local realupdate = txstore.UpdateAsync
		local calls = 0
		txstore.UpdateAsync = function(self, key, fn)
			calls += 1
			if calls == 2 then error 'commit failed' end
			return realupdate(self, key, fn)
		end
		local err = resave.savebatch(function(queue)
			queue(st, 'a', function(d)
				d.coins += 3
			end)
		end)
		txstore.UpdateAsync = realupdate
		assert(err)

		t.strContains(err, 'commit failed')
		t.eq(next(txstore.data), nil)
		t.eq(shim.stores[name].data.a, record({ coins = 0 }, 0))
	end)

	s:case('keeps_tx_when_an_adopt_write_fails', function(t)
		local a, b = unique(), unique()
		local sa = resave.store(a, { schema = resave.schema { coins = 0 } })
		local sb = resave.store(b, { schema = resave.schema { coins = 0 } })

		-- store b: 1st update locks, 2nd adopts; the adopt runs its callback, then the write fails
		local dsb = shim.stores[b]
		local realupdate = dsb.UpdateAsync
		local calls = 0
		dsb.UpdateAsync = function(self, key, fn)
			calls += 1
			if calls ~= 2 then return realupdate(self, key, fn) end
			fn(table.clone(dsb.data[key]))
			error 'adopt failed'
		end
		local err = resave.savebatch(function(queue)
			queue(sa, 'a', function(d)
				d.coins += 3
			end)
			queue(sb, 'b', function(d)
				d.coins += 4
			end)
		end)
		dsb.UpdateAsync = realupdate

		t.eq(err, nil)
		t.eq(shim.stores[a].data.a, record({ coins = 3 }, 0))
		-- b is still locked, and its tx stays committed, so the trade lands on its next load
		local txid = shim.stores[b].data.b.pendingtx.id
		t.eq(txstore.data[txid].state, 'commited')

		local terr, session = resave.track(sb, 'b')
		assert(session, terr)
		t.eq(session.data, { coins = 4 })
	end)

	s:case('aborts_when_commit_comes_after_timeout', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		-- tx store: 2nd update is the commit; expire the tx right before it
		local realupdate = txstore.UpdateAsync
		local calls = 0
		txstore.UpdateAsync = function(self, key, fn)
			calls += 1
			if calls == 2 then txstore.data[key].committimeout = os.time() - 1 end
			return realupdate(self, key, fn)
		end
		local err = resave.savebatch(function(queue)
			queue(st, 'a', function(d)
				d.coins += 3
			end)
		end)
		txstore.UpdateAsync = realupdate
		assert(err)

		t.strContains(err, 'commit timed out')
		t.eq(next(txstore.data), nil)
		t.eq(shim.stores[name].data.a, record({ coins = 0 }, 0))
	end)

	s:case('locks_and_reports_errors_in_queue_order', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		local keys = { 'k1', 'k2', 'k3', 'k4', 'k5', 'k6', 'k7', 'k8' }

		local ds = shim.stores[name]
		local realupdate = ds.UpdateAsync
		local order = {}
		ds.UpdateAsync = function(self, key, fn)
			table.insert(order, key)
			return realupdate(self, key, fn)
		end
		local err = resave.savebatch(function(queue)
			for _, key in keys do
				queue(st, key, function(d)
					d.coins += 1
				end)
			end
		end)
		ds.UpdateAsync = realupdate

		-- the locks come first, then the adopts, each in queue order
		t.eq(err, nil)
		t.eq(table.move(order, 1, #keys, 1, {}), keys)
		t.eq(table.move(order, #keys + 1, 2 * #keys, 1, {}), keys)

		-- with two failing updates, the first queued one is reported
		local err2 = resave.savebatch(function(queue)
			queue(st, 'k1', function()
				error 'first'
			end)
			queue(st, 'k2', function()
				error 'second'
			end)
		end)
		assert(err2)
		t.strContains(err2, 'first')
	end)

	s:case('pretests_tracked_sessions_on_cached_data', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		local _, sa = resave.track(st, 'a')
		assert(sa)

		local ds = shim.stores[name]
		local realget = ds.GetAsync
		local gets = 0
		ds.GetAsync = function(self, key)
			gets += 1
			return realget(self, key)
		end
		local err = resave.savebatch(function(queue)
			queue(st, 'a', function(d)
				d.coins += 1
			end)
			queue(st, 'b', function(d)
				d.coins += 1
			end)
		end)
		ds.GetAsync = realget

		-- only the untracked key is read before locking
		t.eq(err, nil)
		t.eq(gets, 1)
		t.eq(sa.data, { coins = 1 })
	end)
end)
