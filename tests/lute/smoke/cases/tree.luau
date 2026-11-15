-- Walks a condition tree: every valid set of checked ids.
-- combinations
local function groupsof(nodes)
	local groups = {}
	local byname = {}

	for _, node in nodes do
		local name = node.group
		if name and byname[name] then
			table.insert(byname[name], node)
		else
			local group = { node }
			if name then byname[name] = group end
			table.insert(groups, group)
		end
	end
	return groups
end

-- every valid set of checked ids, as arrays in tree order
local function combinations(nodes): { { string } }
	local result = { {} }

	for _, group in groupsof(nodes) do
		local options = { {} }
		for _, node in group do
			for _, below in combinations(node.children or {}) do
				local option = { node.id }
				table.move(below, 1, #below, 2, option)
				table.insert(options, option)
			end
		end

		local nextresult = {}
		for _, partial in result do
			for _, option in options do
				local merged = table.clone(partial)
				table.move(option, 1, #option, #merged + 1, merged)
				table.insert(nextresult, merged)
			end
		end
		result = nextresult
	end

	return result
end

local function indexnodes(nodes, out)
	for _, node in nodes do
		if out[node.id] then error(`duplicate condition id '{node.id}'`, 2) end
		out[node.id] = node
		indexnodes(node.children or {}, out)
	end
	return out
end

local function isvalid(checked: { string }, byid): boolean
	local set = {}
	for _, id in checked do
		set[id] = true
	end
	for _, id in checked do
		for _, other in byid[id].conflicts or {} do
			if set[other] then return false end
		end
	end
	return true
end

return {
	combinations = combinations,
	indexnodes = indexnodes,
	isvalid = isvalid,
}
