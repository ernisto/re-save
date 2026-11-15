-- known issues: for each bug note, its root case is the smallest case where it
-- applies (preferring one where every condition matters). Root cases are listed as
-- known issues; larger cases with the same bug are variants, listed with the more cases.
local function markknownissues(runs)
	local function size(key: string): number
		return if key == '' then 0 else #key:split ','
	end
	local function isedge(run): boolean
		return run.irrelevant ~= nil or run.combined ~= nil
	end
	local function better(a: string, b: string): boolean
		if size(a) ~= size(b) then return size(a) < size(b) end
		if isedge(runs[a]) ~= isedge(runs[b]) then return not isedge(runs[a]) end
		return a < b
	end

	local roots = {}
	for key, run in runs do
		for _, id in run.bugids do
			if not roots[id] or better(key, roots[id]) then roots[id] = key end
		end
	end

	for key, run in runs do
		if #run.bugids == 0 then continue end

		local variantof = {}
		for _, id in run.bugids do
			if roots[id] == key then
				run.knownissue = true
			else
				table.insert(variantof, id)
			end
		end
		if not run.knownissue then run.bugvariant = variantof end
	end
end

-- queue group of every case (the page walks them in this order):
--   intro       succeeds, at most one top-level condition
--   limitation  a known issue's smallest case, or at most one top-level condition that
--               throws, returns an error or warns
--   more        everything else: two or more top-level conditions, a condition that
--               makes no difference, or a variant of a known issue
local function markgroups(runs, roots)
	for key, run in runs do
		local independent = 0
		for _, id in (if key == '' then {} else key:split ',') do
			if roots[id] then
				independent += 1
			end
		end

		if run.knownissue then
			run.group = 'limitation'
		elseif run.irrelevant or run.combined or run.bugvariant or independent > 1 then
			run.group = 'more'
		elseif run.queue then
			run.group = run.queue -- picked by a ticked condition (a node's `queue`, see tests/lute/smoke/conditions/node.luau)
		elseif run.outcome == 'ok' then
			run.group = 'intro'
		else
			run.group = 'limitation'
		end
	end
end

return {
	markknownissues = markknownissues,
	markgroups = markgroups,
}
