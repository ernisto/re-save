-- How defaults and migrations meet saves written by older code.
local mock = require '../mock'
local resave: typeof(require '../../../lib') = mock.require '@self/init'

local helpers = require './helpers'
local record = helpers.record
local suite = helpers.suite
local unique = helpers.unique

suite('schema', function(s)
	s:case('new_default_does_not_reach_old_saves', function(t)
		local name = unique()
		local players = resave.store(name, { schema = resave.schema { coins = 0, gems = 0 } })
		mock.stores[name].data.p1 = record { coins = 5 }

		local _, session = resave.track(players, 'p1')
		assert(session)
		t.eq(session.data.gems, nil)
	end)

	s:case('migration_upgrades_old_saves_and_new_players', function(t)
		local name = unique()
		local v0 = resave.schema { coins = 0 }
		local v1 = resave.migrate(v0, function(d)
			d.gems = 0
		end)
		local players = resave.store(name, { schema = v1 })
		mock.stores[name].data.p1 = record { coins = 5 }

		local _, old = resave.track(players, 'p1')
		local _, new = resave.track(players, 'p2')
		assert(old and new)
		t.eq(old.data, { coins = 5, gems = 0 })
		t.eq(new.data, { coins = 0, gems = 0 })
		t.eq(mock.stores[name].data.p1.version, 1)
	end)

	s:case('migration_keeps_a_field_the_edited_default_already_wrote', function(t)
		local name = unique()
		local v1 = resave.migrate(resave.schema { coins = 0 }, function(d)
			d.gems = d.gems or 0
		end)
		local players = resave.store(name, { schema = v1 })
		mock.stores[name].data.newbie = record { coins = 0, gems = 7 }

		local _, session = resave.track(players, 'newbie')
		assert(session)
		t.eq(session.data, { coins = 0, gems = 7 })
		t.eq(mock.stores[name].data.newbie.version, 1)
	end)
end)
