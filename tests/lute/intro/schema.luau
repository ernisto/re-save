-- intro cases of schema: { case, result } each, keyed by the case's sorted condition ids ('' = none).
-- Every intro case needs one, and every key must be an intro case.
return {
	[''] = { case = 'Create a schema from a default table', result = 'Returns the default with no migrations' },
}
