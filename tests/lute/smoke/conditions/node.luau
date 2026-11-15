-- One condition of a function's tree; every valid combination of checked
-- conditions is a case (tests/lute/smoke/cases).
--
-- snippet = preamble + setup* | prep + arm* | call | settle? + post* + ret
-- node fields:
--   label     what the checkbox says
--   group     siblings sharing a group are exclusive (pick at most one)
--   setup     lines before prep (seed cloud, register things)
--   arm       lines right before the call (fail flags, last changes)
--   post      lines after the call
--   slots     replaces {{slot}} text in any part of the snippet
--   settle    wait for background work after the call
--   bug       known issue on this path, shown when checked
--   conflicts ids that cannot be checked together with this one
--   children  only checkable while this node is checked
--   keep      never mark this condition as making no difference (a more case)
--   bugwhen   the bug note applies only when all of these are ticked too
--   bugnot    the bug note does not apply when any of these is ticked
--   queue     'intro' | 'limitation': the case's queue group when the outcome alone would
--             pick wrong (an expected error belongs in intro, a silent misuse in limitations)

export type node = {
	id: string,
	label: string,
	group: string?,
	setup: string?,
	arm: string?,
	post: string?,
	slots: { [string]: string }?,
	settle: boolean?,
	bug: string?,
	conflicts: { string }?,
	children: { node }?,
}

-- types only
return nil
