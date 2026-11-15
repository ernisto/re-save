-- limitation cases of free: { case, result, kind, why, todo?, fix? } each, keyed like intro/.
--   kind  'known' (library bug) | 'misuse' (calling code is wrong; fix names its fix case)
--         | 'limit' (something the library can't do) | 'fix' (the fix of a misuse, no todo)
-- Every limitation case needs one.
return {
	['pending,rewritten'] = {
		case = 'Let a player leave with changes after another server rewrote their data',
		result = 'Saves and releases the session without the change, and returns why it was dropped',
		kind = 'limit',
		why = "The queued change failed on the other server's data, so it was dropped; everything else was saved.",
		todo = "Write updates that check the data's shape before changing it, and log the error `free` returns.",
	},
	['bumped,pending'] = {
		case = 'Let a player leave with changes after a newer version of the game saved their data',
		result = 'Returns an "outdated base" error and keeps the session; every retry fails the same way',
		kind = 'limit',
		why = "A server on a newer release saved the player with a version this server's schema doesn't know. It can't migrate down, so the queued changes can never be saved here and are lost when the server shuts down.",
		todo = 'Shut down old servers when you release, so no player is on two versions at once.',
	},
	['then_queue'] = {
		case = 'Change a player after they left',
		result = 'Throws: only tracked players can be changed',
		kind = 'misuse',
		why = 'The session was released when the player left.',
		todo = 'Stop gameplay code for the player in `PlayerRemoving` before calling `free`.',
		fix = 'then_queue_checked',
	},
	['then_queue_checked'] = {
		case = "Fix: change the player only while they're still tracked",
		result = 'Nothing is queued after the player left, and nothing throws',
		kind = 'fix',
		why = '`resave.istracked(s)` is false after `free`, so late gameplay code skips the change.',
	},
}
