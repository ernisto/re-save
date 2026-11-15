-- limitation cases of track: { case, result, kind, why, todo?, fix? } each, keyed like intro/.
--   kind  'known' (library bug) | 'misuse' (calling code is wrong; fix names its fix case)
--         | 'limit' (something the library can't do) | 'fix' (the fix of a misuse, no todo)
-- Every limitation case needs one.
return {
	['malformed'] = {
		case = 'Track a player whose saved value is not valid data',
		result = 'Returns an error and leaves the value untouched',
		kind = 'limit',
		why = "Anything that isn't a record may be another tool's data or a broken write, so it's never overwritten.",
		todo = 'Fix or delete the value with your own tooling, then let the player rejoin. Back up the store before running scripts on it.',
	},
	['migration_fails,record'] = {
		case = 'Track a player whose data breaks a migration',
		result = 'Returns the migration error and writes nothing',
		kind = 'limit',
		why = "Half migrated data would break code written for the new version, so the player doesn't load; the save keeps its old version and the migration runs again on the next load.",
		todo = 'Make migrations handle every value old saves can hold; once a fixed migration is released, the save upgrades the next time the player joins.',
	},
	['ahead'] = {
		case = 'Track a player saved by a newer version of the game',
		result = 'Returns an "outdated base" error and leaves the data untouched',
		kind = 'limit',
		why = "The save was written by a newer version of the game; this server can't read it without losing the newer fields.",
		todo = 'Kick the player with a "please rejoin" message so they land on an updated server, and shut down old servers when you release.',
	},
	['update_fails'] = {
		case = 'Track a player while the DataStore is down',
		result = 'Returns the error and does not track the player',
		kind = 'limit',
		why = 'DataStore requests fail during outages and throttling, and the player was not loaded.',
		todo = "Retry `track` after a short delay. If it keeps failing, kick the player with a message so they don't play on data that won't save.",
	},
	['write_fails'] = {
		case = 'Track a player when the save fails',
		result = 'Returns the error and does not track the player',
		kind = 'limit',
		why = 'The request reached the DataStore but the save failed, and the player was not loaded.',
		todo = "Retry `track` after a short delay. If it keeps failing, kick the player with a message so they don't play on data that won't save.",
	},
}
