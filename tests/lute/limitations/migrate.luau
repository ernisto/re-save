-- limitation cases of migrate: { case, result, kind, why, todo?, fix? } each, keyed like intro/.
--   kind  'known' (library bug) | 'misuse' (calling code is wrong; fix names its fix case)
--         | 'limit' (something the library can't do) | 'fix' (the fix of a misuse, no todo)
-- Every limitation case needs one.
return {
	['raises'] = {
		case = "Add a migration that reads a field the default doesn't have",
		result = 'Throws right away, while the schema is built',
		kind = 'misuse',
		why = 'Every migration is test-run on the default when the schema is built. This one reads `d.stats.level`, and the default has no `stats`, so it fails at startup instead of when a player joins.',
		todo = 'Check that a field exists before reading it.',
		fix = 'raises_fixed',
	},
	['raises_fixed'] = {
		case = 'Fix: check the field before reading it',
		result = 'The schema builds; saves without `stats` get level 1',
		kind = 'fix',
		why = '`if d.stats then d.stats.level else 1` works for the default and for every save that never had `stats`.',
	},
	['yields'] = {
		case = 'Add a migration that yields',
		result = 'Throws: migrations may not yield',
		kind = 'limit',
		why = "Migrations run inside DataStore callbacks, where yielding isn't allowed.",
		todo = 'Do any waiting before building the schema; a migration should only reshape data.',
	},
	['impure'] = {
		case = 'Add a migration that stamps the time it ran',
		result = 'Throws: a migration must give the same result every time',
		kind = 'misuse',
		why = 'Every server must turn the same old save into the same new one, so each migration runs twice and both runs must agree.',
		todo = "Don't use the clock, randomness or outside state in a migration; if you need a time, use a fixed one like the release date.",
		fix = 'impure_fixed',
	},
	['impure_fixed'] = {
		case = 'Fix: use a fixed release time',
		result = 'The schema builds; every server stamps the same time',
		kind = 'fix',
		why = 'The time is written once in the code, so every run of the migration gives the same result.',
	},
	['player_breaks'] = {
		case = 'Add a migration that passes the startup test, then load an old player',
		result = 'The schema builds, but the old save breaks it: a warning, and the player keeps unmigrated data',
		kind = 'misuse',
		why = "The startup test only runs the migration on the default data. This one reads `stats`, which the default has but saves from before `stats` existed don't, so it only breaks for real players.",
		todo = 'Write migrations against every shape old saves can have: check fields before reading them, and test with real saves from each released version.',
		fix = 'player_safe',
	},
	['player_safe'] = {
		case = 'Fix: check the field, then load the old player',
		result = 'The old player loads migrated, with level 1',
		kind = 'fix',
		why = "Checking `d.stats` handles saves from before `stats` existed, which the startup test can't see.",
	},
	['edited'] = {
		case = 'Edit a migration that was already released',
		result = 'Two players with the same 5 coins end up with 50 and 500 gold',
		kind = 'misuse',
		why = 'A save records the version it reached. Players who joined before the edit already ran the old migration and never run version 1 again, so only players who join later get the new rule.',
		todo = 'Never change a released migration. Add a new migration on top that fixes the data, so every save goes through the same steps.',
		fix = 'fixed_on_top',
	},
	['fixed_on_top'] = {
		case = 'Fix: add the change as a new migration on top',
		result = 'Both players end up with 500 gold at version 2',
		kind = 'fix',
		why = 'The released migration stays as it was, and every save runs the new one after it, whether it joined before the change or not.',
	},
	['inserted'] = {
		case = 'Insert a migration before a released one',
		result = 'The already migrated player skips the new step and runs the old one again, which breaks',
		kind = 'misuse',
		why = 'Migrations are numbered by position. Inserting one in front renumbers the released ones, so saves that already reached version 1 skip the new migration and run the old one a second time on data it no longer fits.',
		todo = 'Only ever append migrations at the end. If you need a new step, add it as the newest version.',
		fix = 'appended',
	},
	['appended'] = {
		case = 'Fix: add the new migration after the released one',
		result = 'The already migrated player gets `stats` as version 2',
		kind = 'fix',
		why = "Appending keeps the released version numbers, so saves at version 1 run exactly the steps they're missing.",
	},
}
