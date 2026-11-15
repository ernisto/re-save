-- intro cases of istracked: { case, result } each, keyed by the case's sorted condition ids ('' = none).
-- Every intro case needs one, and every key must be an intro case.
return {
	[''] = { case = 'Check a session that is in use', result = 'Returns true' },
	['freed'] = { case = 'Check a session after the player left', result = 'Returns false' },
	['retracked'] = {
		case = 'Check an old session after the player rejoined',
		result = 'Returns false: the new session owns the player',
	},
}
