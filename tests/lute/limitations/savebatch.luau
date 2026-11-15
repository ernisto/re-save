-- limitation cases of savebatch: { case, result, kind, why, todo?, fix? } each, keyed like intro/.
--   kind  'known' (library bug) | 'misuse' (calling code is wrong; fix names its fix case)
--         | 'limit' (something the library can't do) | 'fix' (the fix of a misuse, no todo)
-- Every limitation case needs one.
return {
	['duplicate'] = {
		case = 'Queue the seller twice in one trade',
		result = 'Throws before writing anything',
		kind = 'misuse',
		why = 'The same player twice would apply two changes inside one trade.',
		todo = 'Merge all changes to one player into a single update.',
		fix = 'merged',
	},
	['commit_fails'] = {
		case = 'Trade when the commit write fails',
		result = 'Returns the error and cancels the trade; neither player changes',
		kind = 'limit',
		why = "The commit didn't reach the DataStore, so the trade is cancelled everywhere: the transaction record is deleted and both locks are dropped.",
		todo = 'Retry the trade later, or tell both players it failed.',
	},
	['merged'] = {
		case = "Fix: put all of the seller's changes in one update",
		result = 'The trade goes through with the refund included',
		kind = 'fix',
		why = 'One update per player keeps each player locked once, and the trade applies both changes together.',
	},
	['builder_raises'] = {
		case = 'Build a trade from an offer that was cancelled',
		result = 'Throws on `offer.price` before writing anything',
		kind = 'misuse',
		why = 'The builder reads the offer, but the buyer cancelled it, so `offer` is `nil`. The builder runs before anything is written, so no player changed.',
		todo = "Check the offer at the start of the builder and stop when it's gone.",
		fix = 'builder_checked',
	},
	['builder_checked'] = {
		case = 'Fix: stop the builder when the offer was cancelled',
		result = 'Nothing is traded and nothing throws',
		kind = 'fix',
		why = 'Returning early queues nothing, so `savebatch` runs an empty trade and returns no error.',
	},
	['locked'] = {
		case = 'Trade with a seller who is in another trade',
		result = 'Returns an error; neither player changes',
		kind = 'limit',
		why = "The seller is part of another trade that's still in progress, and a player can only be in one at a time.",
		todo = "Retry after a short wait, and don't let one player open two trades at once.",
	},
	['create_fails'] = {
		case = 'Trade while the transaction store is down',
		result = 'Returns the error before touching any player',
		kind = 'limit',
		why = 'The transaction store is a DataStore too, and it can be down.',
		todo = 'Retry the trade later; no player was changed.',
	},
	['lock_fails'] = {
		case = 'Trade while the player DataStore is down',
		result = 'Returns the error; nothing changes',
		kind = 'limit',
		why = "A player couldn't be locked during the outage, so the trade was cancelled and nothing changed.",
		todo = 'Retry the trade later.',
	},
}
