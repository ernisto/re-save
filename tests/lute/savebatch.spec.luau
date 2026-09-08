local roblox = require './roblox'
local resave: typeof(require '../../lib') = roblox.require './../../lib'
local shim = roblox
local txstore = shim.stores.tx

local helpers = require './helpers'
local throwscontains = helpers.throwscontains
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
end)
