-- intro cases of delete: { case, result } each, keyed by the case's sorted condition ids ('' = none).
-- Every intro case needs one, and every key must be an intro case.
return {
	[''] = { case = 'Delete a player with no data', result = 'Succeeds; there was nothing to delete' },
	['tracked'] = {
		case = 'Delete a player who is playing with unsaved changes',
		result = 'Deletes the saved data; the session keeps its changes',
	},
	['then_free,tracked'] = {
		case = 'Delete a playing player, then they leave',
		result = 'Leaving saves their changes, bringing the data back',
	},
	['then_track'] = { case = 'Delete a player, then they join', result = 'Joining gives default data' },
}
