-- saveupdate paths no condition tree reaches: impure updates, and an update that
-- fails only on the locked copy.
local mock = require '../mock'
local resave: typeof(require '../../../lib') = mock.require '@self/init'

local helpers = require './helpers'
local maketest = helpers.maketest
local record = helpers.record
local suite = helpers.suite
local unique = helpers.unique

suite('saveupdate', function(s)
	s:case('rejects_impure_update', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0, t = 0 } })
		local calls = 0

		local err = resave.saveupdate(st, 'p1', function(d)
			calls += 1
			d.t = calls
		end)
		assert(err)

		t.strContains(err, 'different result')
		t.eq(mock.stores[name].data.p1.data, { coins = 0, t = 0 })
	end)

	s:case('saves_nothing_when_update_fails_on_pendingtx_branch', function(t)
		local name = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })
		maketest('tx-live', {})
		mock.stores[name].data.p1 = record(
			{ coins = 5 },
			0,
			{ id = 'tx-live', newdata = { coins = 0 }, version = 0, cooltimestamp = 0 }
		)

		local err = resave.saveupdate(st, 'p1', function(d)
			assert(d.coins >= 5, 'not enough coins')
			d.coins -= 5
		end)
		assert(err)

		t.strContains(err, 'not enough coins')
		t.eq(mock.stores[name].data.p1.data, { coins = 5 })
		t.eq(mock.stores[name].data.p1.pendingtx.newdata, { coins = 0 })
	end)
end)
