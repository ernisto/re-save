-- intro cases of track: { case, result } each, keyed by the case's sorted condition ids ('' = none).
-- Every intro case needs one, and every key must be an intro case.
return {
	[''] = { case = 'Track a player with no data', result = 'Gives the default data and saves it' },
	['record'] = { case = 'Track a player with data', result = 'Returns the saved data' },
	['outdated,record'] = {
		case = 'Track a player with data in an outdated version',
		result = 'Migrates the old data to the latest version and saves it',
	},
	['tracked'] = {
		case = 'Track a player who is already tracked',
		result = 'Returns the same session without loading again',
	},
	['record,tx_committed'] = {
		case = 'Track a player whose data has a finished trade not applied yet',
		result = 'Applies the trade and returns the traded data',
	},
	['record,tx_live'] = {
		case = 'Track a player in the middle of a trade',
		result = 'Returns the data from before the trade and leaves the trade running',
	},
	['outdated,record,tx_committed'] = {
		case = 'Track a player with outdated data and a finished trade not applied yet',
		result = 'Migrates both copies, then applies the trade',
	},
	['outdated,record,tx_live'] = {
		case = 'Track a player with outdated data in the middle of a trade',
		result = 'Migrates both copies and leaves the trade running',
	},
	['then_queue_free'] = {
		case = 'Track a new player, give a coin, then let them leave',
		result = 'Saves the coin when the player leaves',
	},
}
