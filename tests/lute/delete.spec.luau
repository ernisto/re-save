local roblox = require './roblox'
local resave: typeof(require '../../lib') = roblox.require './../../lib'
local shim = roblox

local helpers = require './helpers'
local suite = helpers.suite
local unique = helpers.unique
local record = helpers.record

suite('delete', function(s)
	s:case('removes_record', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })
		shim.stores[name].data.p1 = record {}

		t.eq(resave.delete(st, 'p1'), nil)
		t.eq(shim.stores[name].data.p1, nil)
	end)

	s:case('fails_when_remove_fails', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })
		shim.stores[name]._failremove = true

		local err = resave.delete(st, 'p1')
		assert(err)

		t.strContains(err, 'remove failed')
	end)

	s:case('adopts_tx_of_a_locked_record', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema {} })
		shim.stores.tx.data['tx-x'] = { state = 'commited', committimeout = 0, adopts = { [`{name}:p1`] = false } }
		shim.stores[name].data.p1 = record({}, 0, { id = 'tx-x', newdata = {}, version = 0, cooltimestamp = 0 })

		t.eq(resave.delete(st, 'p1'), nil)
		-- the record was the tx's last adopter, so the tx is cleaned up
		t.eq(shim.stores.tx.data['tx-x'], nil)
	end)
end)
