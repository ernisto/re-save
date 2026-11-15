-- intro cases of view: { case, result } each, keyed by the case's sorted condition ids ('' = none).
-- Every intro case needs one, and every key must be an intro case.
return {
	[''] = { case = 'Read a player with no data', result = 'Returns nothing and creates no data' },
	['record'] = { case = 'Read a player with data', result = 'Returns the saved data without changing it' },
	['tracked'] = { case = 'Read a player who is playing on this server', result = 'Returns their current data' },
	['pending,tracked'] = {
		case = 'Read a playing player with unsaved changes',
		result = 'Saves the changes first, then returns them',
	},
	['rewritten,tracked'] = {
		case = 'Read a playing player after another server wrote their data',
		result = 'Returns the newer data and updates the session',
	},
	['pending,rewritten,tracked'] = {
		case = 'Read a playing player with changes after another server wrote',
		result = 'Saves the changes on top of the newer data and returns it',
	},
}
