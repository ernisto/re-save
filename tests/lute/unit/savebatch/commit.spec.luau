-- savebatch commit: timeouts, the order of writes, and reads it can skip.
local mock = require '../../mock'
local resave: typeof(require '../../../../lib') = mock.require '@self/init'
local txstore = mock.stores.tx

local helpers = require '../helpers'
local record = helpers.record
local suite = helpers.suite
local unique = helpers.unique

suite('savebatch commit', function(s)
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
		t.eq(mock.stores[name].data.a, record({ coins = 0 }, 0))
	end)

	s:case('locks_and_reports_errors_in_queue_order', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		local keys = { 'k1', 'k2', 'k3', 'k4', 'k5', 'k6', 'k7', 'k8' }

		local ds = mock.stores[name]
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

		local ds = mock.stores[name]
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
