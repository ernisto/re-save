-- Every case of a function: each valid combination of checked conditions in its
-- tree (tests/lute/smoke/conditions), composed into the snippet that case runs.
local compose = require '@self/compose'
local nodes = require './conditions/node'
local tree = require '@self/tree'

-- { key, checked, code, ran, bugs, bugids, queue } per valid combination, in tree order;
-- key = the checked ids, sorted and comma-separated ('' = none)
local function cases(spec: nodes.spec)
	local byid = tree.indexnodes(spec.tree, {})
	local out = {}
	for _, checked in tree.combinations(spec.tree) do
		if not tree.isvalid(checked, byid) then continue end

		local sorted = table.clone(checked)
		table.sort(sorted)

		local code, ran, bugs, bugids, queue = compose.compose(spec, checked, byid)
		table.insert(out, {
			key = table.concat(sorted, ','),
			checked = checked,
			code = code,
			ran = ran,
			bugs = bugs,
			bugids = bugids,
			queue = queue,
		})
	end
	return out, byid
end

return {
	cases = cases,
}
