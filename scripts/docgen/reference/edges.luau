local snippet = require '../../../tests/lute/smoke/snippet'

-- conditions that make no difference: the case without one ends the same way
-- (snippet.signature: returns or throw, final stores and sessions, warnings)
local MAX_INDEPENDENT = 2

local function markedges(runs, byid, roots)
	local signatures = {}
	for key, run in runs do
		signatures[key] = snippet.signature(run)
	end

	for key, run in runs do
		local ids = if key == '' then {} else key:split ','
		local ticked = {}
		for _, id in ids do
			ticked[id] = true
		end

		local irrelevant = {}
		for _, id in ids do
			-- only conditions with no ticked children can be dropped on their own
			local haschild = false
			for _, child in byid[id].children or {} do
				haschild = haschild or ticked[child.id] == true
			end
			-- `keep`, and a chosen queue group (a fix, an expected error), always matter
			if haschild or byid[id].keep or byid[id].queue then continue end

			local rest = {}
			for _, other in ids do
				if other ~= id then table.insert(rest, other) end
			end
			local without = table.concat(rest, ',')

			if signatures[without] and signatures[without] == signatures[key] then table.insert(irrelevant, id) end
		end

		if #irrelevant > 0 then run.irrelevant = irrelevant end

		-- more than MAX_INDEPENDENT top-level conditions at once is hard to read;
		-- each of them already shows up in simpler cases (children only refine a parent)
		local independent = 0
		for _, id in ids do
			if roots[id] then
				independent += 1
			end
		end
		if independent > MAX_INDEPENDENT then run.combined = independent end
	end
end

return {
	markedges = markedges,
}
