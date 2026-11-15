-- intro cases of queueupdate: { case, result } each, keyed by the case's sorted condition ids ('' = none).
-- Every intro case needs one, and every key must be an intro case.
return {
	[''] = {
		case = 'Give a tracked player 5 coins',
		result = 'The session shows the coins at once; nothing is saved yet',
	},
	['buy'] = {
		case = 'Buy a sword, checking the coins inside the update',
		result = 'The session shows 90 coins and the sword at once; nothing is saved yet',
	},
	['queued'] = {
		case = 'Give coins to a player who already has a change waiting',
		result = 'Both changes wait in line to be saved',
	},
	['livesync'] = {
		case = 'Give coins, then wait for the background save',
		result = 'The background loop saves the coins',
	},
	['then_saveupdate'] = {
		case = 'Give coins, then save a purchase right away',
		result = 'Saves the coins and the purchase in one write',
	},
	['then_free'] = {
		case = 'Give coins, then let the player leave',
		result = 'Saves the coins when the player leaves',
	},
	['then_view'] = {
		case = "Give coins, then read the player's data",
		result = 'Reading saves the coins first and returns them',
	},
	['then_queue'] = {
		case = 'Give coins, then double them',
		result = 'Both changes wait in line; the session shows both',
	},
}
