-- The API reference: every function's signature, page text and recorded cases.
local apidoc = require '@self/apidoc'
local cases = require './../../tests/lute/smoke/cases'
local conditions = require './../../tests/lute/smoke/conditions'
local descriptions = require '@self/descriptions'
local edges = require '@self/edges'
local groups = require '@self/groups'
local snippet = require './../../tests/lute/smoke/snippet'

local function exporttree(nodes)
	local out = {}
	for _, node in nodes do
		table.insert(out, {
			id = node.id,
			label = node.label,
			group = node.group,
			conflicts = node.conflicts,
			children = exporttree(node.children or {}),
		})
	end
	return out
end

-- every case of the function, run against the mock and sorted into queue groups
local function recordruns(spec)
	local list, byid = cases.cases(spec)
	local runs = {}

	for _, case in list do
		local run = snippet.run(spec.name, case.code, case.ran)
		run.code = case.code
		run.bugs = case.bugs
		run.bugids = case.bugids
		run.queue = case.queue
		run.outcome = snippet.outcome(run)
		runs[case.key] = run
	end

	local roots = {}
	for _, root in spec.tree do
		roots[root.id] = true
	end

	edges.markedges(runs, byid, roots)
	groups.markknownissues(runs)
	groups.markgroups(runs, roots)
	descriptions.attachdescriptions(spec.name, runs)

	return runs, #list
end

local function buildfunction(spec, fn)
	local runs, count = recordruns(spec)
	local doc = apidoc.readdoc(spec.name)
	local params, returns = apidoc.joindoc(doc, fn)
	apidoc.checkcaselinks(doc, params, returns, runs, spec.name)

	local entry = {
		name = spec.name,
		source = fn.source,
		generics = fn.generics,
		params = params,
		returns = returns,
		yields = doc.meta.yields == 'true',
		group = doc.meta.group or error(`{doc.path} has no group`),
		md = doc.body,
		tree = exporttree(spec.tree),
		runs = runs,
	}
	return entry, count
end

local function checkexports(reflected)
	local listed = {}
	for _, spec in conditions do
		if not reflected.functions[spec.name] then
			error(`tests/lute/smoke/conditions: '{spec.name}' is not exported by lib/init.luau`)
		end
		listed[spec.name] = true
	end

	for name in reflected.functions do
		if not listed[name] then
			error(`lib/init.luau exports '{name}', but tests/lute/smoke/conditions has no entry for it`)
		end
	end
end

-- (functions in page order, number of cases run)
local function buildreference(reflected)
	checkexports(reflected)

	local out = {}
	local total = 0
	for _, spec in conditions do
		local entry, count = buildfunction(spec, reflected.functions[spec.name])
		table.insert(out, entry)
		total += count
	end
	return out, total
end

return {
	buildreference = buildreference,
}
