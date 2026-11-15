-- limitation cases of saveupdate: { case, result, kind, why, todo?, fix? } each, keyed like intro/.
--   kind  'known' (library bug) | 'misuse' (calling code is wrong; fix names its fix case)
--         | 'limit' (something the library can't do) | 'fix' (the fix of a misuse, no todo)
-- Every limitation case needs one.
return {
	['yields'] = {
		case = 'Check the receipt with a web request inside the purchase',
		result = 'Returns an error: purchases may not yield',
		kind = 'limit',
		why = "The purchase runs inside `UpdateAsync`, where yielding isn't allowed, so it's checked like `queueupdate` and rejected before anything is saved.",
		todo = 'Check the receipt before calling `saveupdate`, and keep the update to the coin and item changes.',
	},
	['update_fails'] = {
		case = 'Buy a sword while the DataStore is down',
		result = 'Returns the error and saves nothing',
		kind = 'limit',
		why = 'The DataStore was down, so nothing was saved.',
		todo = "Don't give the sword. For developer products, return `NotProcessedYet` so Roblox retries the receipt later.",
	},
	['write_fails'] = {
		case = 'Buy a sword when the save fails',
		result = 'Returns the error and saves nothing',
		kind = 'limit',
		why = 'The save failed after reaching the DataStore, so nothing was saved.',
		todo = "Don't give the sword. For developer products, return `NotProcessedYet` so Roblox retries the receipt later.",
	},
}
