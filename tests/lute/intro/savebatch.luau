-- intro cases of savebatch: { case, result } each, keyed by the case's sorted condition ids ('' = none).
-- Every intro case needs one, and every key must be an intro case.
return {
	[''] = {
		case = 'Trade a sword for 50 coins',
		result = 'The seller gets 50 coins and the buyer gets the sword, together',
	},
	['then_track'] = {
		case = 'Trade a sword for 50 coins, then the seller joins',
		result = 'Joining loads the 50 coins',
	},
	['empty'] = {
		case = 'Run a trade where both players removed their items',
		result = 'Does nothing and returns no error',
	},
	['poor'] = {
		case = 'Trade a sword to a buyer with only 10 coins',
		result = 'Returns "not enough coins"; neither player changes',
	},
	['adopt_fails'] = {
		case = "Trade when writing one player's result fails",
		result = 'Returns no error; that player stays locked to the finished trade and gets it on their next load',
	},
}
