local roblox = require './roblox'
local resave: typeof(require '../../lib') = roblox.require './../../lib'

local helpers = require './helpers'
local throwscontains = helpers.throwscontains
local suite = helpers.suite
local unique = helpers.unique

suite('schema', function(s)
	s:case('migrate_keeps_default_and_appends_migration', function(t)
		local base = resave.schema { coins = 0 }
		local next = resave.migrate(base, function(d)
			d.coins += 1
			return d
		end)

		t.eq(next.default, { coins = 0 })
		t.eq(#next.migrations, 1)
	end)

	s:case('migrate_throws_when_migration_fails_on_default', function(t)
		local base = resave.schema { coins = 0 }
		throwscontains(t, function()
			resave.migrate(base, function()
				error 'boom'
			end)
		end, 'boom')
	end)

	s:case('migrate_chains_multiple_migrations', function(t)
		local base = resave.schema { v = 0 }
		local mid = resave.migrate(base, function(d)
			d.v += 1
			return d
		end)
		local top = resave.migrate(mid, function(d)
			d.v += 10
			return d
		end)

		t.eq(#top.migrations, 2)
		local st = resave.store(unique(), { schema = top })

		local err, session = resave.track(st, 'k')
		assert(session, err)

		t.eq(session.data, { v = 11 })
	end)
end)
