-- limitation cases of queueupdate: { case, result, kind, why, todo?, fix? } each, keyed like intro/.
--   kind  'known' (library bug) | 'misuse' (calling code is wrong; fix names its fix case)
--         | 'limit' (something the library can't do) | 'fix' (the fix of a misuse, no todo)
-- Every limitation case needs one.
return {
	['buy_rebased'] = {
		case = 'Fix: check the coins inside the update, while another server spends them first',
		result = 'When the purchase is replayed on the 5 coins left, the check fails, so no sword and no negative coins',
		kind = 'fix',
		why = 'The check is part of the update, so it runs again every time the update is replayed on newer data.',
	},
	['buy_stale'] = {
		case = 'Check the coins before queueing a purchase, while another server spends them first',
		result = 'The purchase is replayed on the 5 coins left without checking again: -5 coins and a free sword',
		kind = 'misuse',
		why = "Queued updates are replayed (rebased) on the newest cloud data when they're saved. The check ran once, against old data, so it isn't repeated when the update is replayed on the 5 coins another server left.",
		todo = 'Put the check inside the update, `if d.coins >= 10 then ... end`, so it runs again every time the update is replayed.',
		fix = 'buy_rebased',
	},
	['freed'] = {
		case = 'Give coins to a player who already left',
		result = 'Throws: only tracked players can be changed',
		kind = 'misuse',
		why = 'The session was released when the player left, so a change to it could never be saved.',
		todo = "Stop a player's timers and connections when they leave, and check `istracked` before changing a session you kept around.",
		fix = 'freed_checked',
	},
	['freed_checked'] = {
		case = 'Fix: check the player is still tracked before changing them',
		result = 'Nothing is queued and nothing throws',
		kind = 'fix',
		why = '`resave.istracked(s)` is false once the player left, so the change is skipped instead of thrown away.',
	},
	['raises'] = {
		case = 'Add an amount the client never sent',
		result = 'Throws on `coins + nil`, and nothing changes',
		kind = 'misuse',
		why = "The RemoteEvent arrived without an amount, so the update does arithmetic on `nil`. Updates run as soon as they're queued, so the crash shows up right away.",
		todo = 'Check every value that comes from a RemoteEvent before using it: its type, its range, and that the player may send it.',
		fix = 'raises_checked',
	},
	['raises_checked'] = {
		case = 'Fix: check the amount the client sent',
		result = 'The missing amount is ignored; nothing throws',
		kind = 'fix',
		why = 'The amount is checked for type and range before it reaches the update, so a bad RemoteEvent changes nothing.',
	},
	['yields'] = {
		case = "Look up the player's rank with a web request inside the update",
		result = 'Throws: updates may not yield',
		kind = 'limit',
		why = "Updates are replayed inside DataStore callbacks, where yielding isn't allowed.",
		todo = 'Do the web request first, then queue an update that only writes the result.',
	},
	['not_json'] = {
		case = 'Save the spawn point as a vector',
		result = "Throws: a vector can't be saved",
		kind = 'misuse',
		why = "DataStores only store JSON, and vectors, CFrames, Colors and Instances aren't JSON. This is caught when you change the data instead of later, when the save would fail.",
		todo = 'Save plain values instead, like `{ x = 10, y = 0, z = 5 }`, and rebuild the vector when you load it.',
		fix = 'vector_plain',
	},
	['vector_plain'] = {
		case = 'Fix: save the spawn point as plain numbers',
		result = 'Queued fine; rebuild the vector when loading',
		kind = 'fix',
		why = '`{ x = 10, y = 0, z = 5 }` is plain JSON, and `vector.create(spawn.x, spawn.y, spawn.z)` turns it back into a vector.',
	},
	['returns_not_json'] = {
		case = 'Return data that holds a function',
		result = "Throws: functions can't be saved",
		kind = 'misuse',
		why = "A returned value is checked the same way as one changed in place, and functions aren't JSON.",
		todo = 'Keep callbacks in your game code, not in saved data.',
		fix = 'returns_plain',
	},
	['returns_plain'] = {
		case = 'Fix: return plain data and keep the callback in game code',
		result = 'Queued fine',
		kind = 'fix',
		why = 'Only plain values are saved; the callback lives in the script that needs it.',
	},
	['non_ascii'] = {
		case = 'Save a pet name the player typed',
		result = 'Throws: "Señor Bigotes" has non-ASCII characters',
		kind = 'limit',
		why = "The library rejects any text with non-ASCII characters so a save can't fail on it later, even though Roblox accepts valid UTF-8.",
		todo = 'Filter the name with `TextService` as usual, then keep it ASCII or store it encoded, for example as a list of `utf8.codepoint` numbers.',
	},
	['impure'] = {
		case = 'Stamp the daily reward time inside the update',
		result = 'Throws: the two runs read different times',
		kind = 'misuse',
		why = 'Updates are replayed on newer cloud data, so each must give the same result every time; each one runs twice to check.',
		todo = 'Read the time, or roll any random value, before queueing, and pass it into the update.',
		fix = 'impure_fixed',
	},
	['impure_fixed'] = {
		case = 'Fix: read the time before queueing',
		result = 'Queued fine; every replay writes the same time',
		kind = 'fix',
		why = 'The time is read once outside the update and passed in, so both runs, and any later replay, agree.',
	},
}
