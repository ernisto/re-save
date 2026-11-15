-- intro cases of saveupdate: { case, result } each, keyed by the case's sorted condition ids ('' = none).
-- Every intro case needs one, and every key must be an intro case.
return {
	[''] = {
		case = 'Buy a sword for a new player',
		result = 'Creates the data with 100 coins, then spends 10 on the sword, in one write',
	},
	['record'] = {
		case = 'Buy a sword for a player with saved data',
		result = 'Spends 10 of their 25 coins and adds the sword',
	},
	['tracked'] = {
		case = 'Buy a sword for a player who is playing',
		result = 'Saves the purchase and updates their session',
	},
	['pending,tracked'] = {
		case = 'Buy a sword while the player has unsaved earnings',
		result = 'Saves the earnings and the purchase in one write',
	},
	['poor'] = {
		case = 'Buy a sword for a player with 4 coins',
		result = 'Returns "not enough coins" and saves nothing',
	},
	['record,tx_live'] = {
		case = 'Buy a sword for a player in the middle of a trade',
		result = "Applies the purchase to both the current data and the trade's copy",
	},
	['then_track'] = { case = 'Buy a sword, then the player joins', result = 'Joining loads the sword' },
	['then_retry'] = {
		case = 'Buy a sword, then run the same purchase again',
		result = 'Charges twice and gives two swords: retries must not repeat a successful purchase',
	},
	['record,tx_committed'] = {
		case = 'Buy a sword for a player with a finished trade not applied yet',
		result = 'Applies the trade, then the purchase on top, once',
	},
}
