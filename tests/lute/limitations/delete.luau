-- limitation cases of delete: { case, result, kind, why, todo?, fix? } each, keyed like intro/.
--   kind  'known' (library bug) | 'misuse' (calling code is wrong; fix names its fix case)
--         | 'limit' (something the library can't do) | 'fix' (the fix of a misuse, no todo)
-- Every limitation case needs one.
return {
	['remove_fails'] = {
		case = 'Delete a player while the DataStore is down',
		result = 'Returns the error',
		kind = 'limit',
		why = 'The DataStore was down, so the data is still there.',
		todo = 'Retry the deletion, and for data deletion requests keep retrying until it succeeds.',
	},
}
