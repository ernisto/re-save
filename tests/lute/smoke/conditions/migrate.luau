-- Condition tree of resave.migrate (node fields: node.luau).
-- migrate cases that build their own schemas or stores: not combined with `chained`
local MIGRATE_SOLO =
	{ 'player_breaks', 'edited', 'inserted', 'raises_fixed', 'impure_fixed', 'player_safe', 'fixed_on_top', 'appended' }

return {
	name = 'migrate',
	preamble = 'local v0 = resave.schema {{default}}',
	call = '{{call}}',
	ret = 'return {{latest}}',
	slots = {
		default = '{ coins = 0 }',
		base = 'v0',
		latest = 'v1',
		call = 'local {{latest}} = resave.migrate({{base}}, function(d)\n\t{{body}}\nend)',
		body = 'return { gold = d.coins * 10 }',
	},
	tree = {
		{
			id = 'chained',
			label = 'base already has a migration',
			setup = 'local v1 = resave.migrate(v0, function(d)\n\treturn { coins = d.coins + 1 }\nend)',
			slots = { base = 'v1', latest = 'v2' },
			conflicts = MIGRATE_SOLO,
		},
		{
			id = 'raises',
			group = 'fn',
			label = 'migration reads a field the default lacks',
			slots = { body = 'return { gold = d.coins * 10, level = d.stats.level } -- the default has no stats' },
		},
		{
			id = 'raises_fixed',
			group = 'fn',
			label = 'fix: the migration checks the field first',
			queue = 'limitation',
			slots = { body = 'return { gold = d.coins * 10, level = if d.stats then d.stats.level else 1 }' },
		},
		{ id = 'yields', group = 'fn', label = 'migration yields', slots = { body = 'task.wait()\n\treturn d' } },
		{
			id = 'impure',
			group = 'fn',
			label = 'migration stamps the time it ran',
			slots = { body = 'return { gold = d.coins * 10, migratedat = os.clock() }' },
		},
		{
			id = 'impure_fixed',
			group = 'fn',
			label = 'fix: the migration uses a fixed release time',
			queue = 'limitation',
			setup = 'local RELEASED_AT = 1731628800 -- the release date, written once',
			slots = { body = 'return { gold = d.coins * 10, migratedat = RELEASED_AT }' },
		},
		{
			id = 'player_safe',
			group = 'fn',
			label = 'fix: checks the field, then loads the old player',
			queue = 'limitation',
			slots = {
				default = '{ coins = 0, stats = { level = 1 } }',
				body = 'return { gold = d.coins * 10, level = if d.stats then d.stats.level else 1 }',
			},
			post = "local players = resave.store('players', { schema = {{latest}} })\ncloud(players).p1 = { data = { coins = 5 }, version = 0 } -- saved before `stats` existed\ncheckpoint 'schema built'\nlocal err, s = resave.track(players, 'p1')",
		},
		{
			id = 'fixed_on_top',
			group = 'fn',
			label = 'fix: a new migration on top of the released one',
			queue = 'limitation',
			slots = {
				latest = 'v2',
				call = 'local v1 = resave.migrate(v0, function(d)\n\treturn { gold = d.coins * 10 }\nend)\nlocal v2 = resave.migrate(v1, function(d)\n\td.gold *= 10\n\treturn d\nend)',
			},
			post = "local players = resave.store('players', { schema = {{latest}} })\ncloud(players).early = { data = { gold = 50 }, version = 1 } -- joined after the first release\ncloud(players).late = { data = { coins = 5 }, version = 0 } -- has not joined since\nlocal _, early = resave.track(players, 'early')\nlocal _, late = resave.track(players, 'late')",
		},
		{
			id = 'appended',
			group = 'fn',
			label = 'fix: the new migration is added after the released one',
			queue = 'limitation',
			slots = {
				latest = 'v2',
				call = 'local v1 = resave.migrate(v0, function(d)\n\treturn { gold = d.coins * 10 }\nend)\nlocal v2 = resave.migrate(v1, function(d)\n\td.stats = { level = 1 }\n\treturn d\nend)',
			},
			post = "local players = resave.store('players', { schema = {{latest}} })\ncloud(players).p1 = { data = { gold = 50 }, version = 1 } -- already ran the released version 1\nlocal err, s = resave.track(players, 'p1')",
		},
		{
			id = 'player_breaks',
			group = 'fn',
			label = "passes on the default, then fails on a player's old save",
			queue = 'limitation',
			slots = {
				default = '{ coins = 0, stats = { level = 1 } }',
				body = 'return { gold = d.coins * 10, level = d.stats.level }',
			},
			post = "local players = resave.store('players', { schema = {{latest}} })\ncloud(players).p1 = { data = { coins = 5 }, version = 0 } -- saved before `stats` existed\ncheckpoint 'schema built'\nlocal err, s = resave.track(players, 'p1')",
		},
		{
			id = 'edited',
			group = 'fn',
			label = 'a released migration is edited',
			queue = 'limitation',
			slots = {
				call = 'local v1 = resave.migrate(v0, function(d)\n\treturn { gold = d.coins * 100 }\nend)',
			},
			post = "local players = resave.store('players', { schema = {{latest}} })\ncloud(players).early = { data = { gold = 50 }, version = 1 } -- joined before the edit: 5 coins became 50 gold\ncloud(players).late = { data = { coins = 5 }, version = 0 } -- has not joined since\nlocal _, early = resave.track(players, 'early')\nlocal _, late = resave.track(players, 'late')",
		},
		{
			id = 'inserted',
			group = 'fn',
			label = 'a migration is inserted before a released one',
			queue = 'limitation',
			slots = {
				latest = 'v2',
				call = 'local v1 = resave.migrate(v0, function(d)\n\td.stats = { level = 1 }\n\treturn d\nend)\nlocal v2 = resave.migrate(v1, function(d)\n\treturn { gold = d.coins * 10, stats = d.stats }\nend)',
			},
			post = "local players = resave.store('players', { schema = {{latest}} })\ncloud(players).p1 = { data = { gold = 50 }, version = 1 } -- already ran the released version 1\nlocal err, s = resave.track(players, 'p1')",
		},
	},
}
