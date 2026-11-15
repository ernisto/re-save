-- limitation cases of view: { case, result, kind, why, todo?, fix? } each, keyed like intro/.
--   kind  'known' (library bug) | 'misuse' (calling code is wrong; fix names its fix case)
--         | 'limit' (something the library can't do) | 'fix' (the fix of a misuse, no todo)
-- Every limitation case needs one.
return {
	['ahead'] = {
		case = 'Read a player saved by a newer version of the game',
		result = 'Returns an "outdated base" error',
		kind = 'limit',
		why = "The save was written by a newer version of the game; this server can't read it without losing the newer fields.",
		todo = 'Handle it like `track` does: the data is fine, this server is just older.',
	},
	['get_fails'] = {
		case = 'Read a player while the DataStore is down',
		result = 'Returns the error',
		kind = 'limit',
		why = 'Reads fail during outages and throttling.',
		todo = 'Show the data as unavailable and try again later; never treat the failure as empty data.',
	},
}
