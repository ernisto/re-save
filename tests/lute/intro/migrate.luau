-- intro cases of migrate: { case, result } each, keyed by the case's sorted condition ids ('' = none).
-- Every intro case needs one, and every key must be an intro case.
return {
	[''] = { case = 'Turn coins into gold with a migration', result = 'Returns a new schema one version newer' },
	['chained'] = {
		case = 'Add a migration to a schema that already has one',
		result = 'Returns a schema two versions newer; both migrations run in order',
	},
}
