-- intro cases of maybetracked: { case, result } each, keyed by the case's sorted condition ids ('' = none).
-- Every intro case needs one, and every key must be an intro case.
return {
	[''] = { case = 'Look up a player who never joined', result = 'Returns nil' },
	['tracked'] = { case = 'Look up a player who is playing', result = 'Returns their session' },
	['freed,tracked'] = { case = 'Look up a player who left', result = 'Returns nil' },
}
