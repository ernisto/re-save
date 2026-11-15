-- intro cases of free: { case, result } each, keyed by the case's sorted condition ids ('' = none).
-- Every intro case needs one, and every key must be an intro case.
return {
	[''] = { case = 'Let a player leave with nothing changed', result = 'Releases the session without saving' },
	['record'] = { case = 'Let a player with data leave', result = 'Releases the session; the saved data stays' },
	['pending'] = {
		case = 'Let a player leave with unsaved changes',
		result = 'Saves the changes, then releases the session',
	},
	['record,tx_committed'] = {
		case = 'Let a player leave after a finished trade was applied on load',
		result = 'Releases the session; the traded data stays',
	},
	['record,tx_live'] = {
		case = 'Let a player leave in the middle of a trade',
		result = 'Releases the session and leaves the trade running',
	},
	['then_track'] = { case = 'Let a player leave, then rejoin', result = 'Rejoining loads a new session' },
}
