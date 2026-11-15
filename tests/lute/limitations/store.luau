-- limitation cases of store: { case, result, kind, why, todo?, fix? } each, keyed like intro/.
--   kind  'known' (library bug) | 'misuse' (calling code is wrong; fix names its fix case)
--         | 'limit' (something the library can't do) | 'fix' (the fix of a misuse, no todo)
-- Every limitation case needs one.
return {
	['registered'] = {
		case = 'Register a store name twice',
		result = 'Throws: each name can be registered once per server',
		kind = 'misuse',
		why = 'Two registrations of one name would share a DataStore under two schemas.',
		todo = 'Register each store once in a single module, and require that module wherever you need the store.',
		fix = 'shared',
	},
	['shared'] = {
		case = 'Fix: other scripts reuse the store from one shared module',
		result = 'No error; every script uses the same store',
		kind = 'fix',
		why = 'The store is registered once, and other scripts require the module that holds it instead of registering again.',
	},
}
