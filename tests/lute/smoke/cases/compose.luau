-- Builds the snippet of one case from the checked nodes of its tree.
local seeds = require './seeds'

local hideseeds = seeds.hideseeds

local function fillslots(text: string, slots): string
	for _ = 1, 10 do
		local filled = text:gsub('{{(%w+)}}', function(name)
			local value = slots[name]
			if value == nil then error(`unknown slot '{name}'`) end
			return value
		end)
		if filled == text then return filled end
		text = filled
	end
	error 'slots nest too deep'
end

local function compose(spec, checked: { string }, byid)
	local slots = table.clone(spec.slots or {})
	local setups, arms, posts, bugs, bugids = {}, {}, {}, {}, {}
	local settle = spec.settle == true
	local queue = nil

	local ticked = {}
	for _, id in checked do
		ticked[id] = true
	end

	-- a bug note applies when its node is ticked, all of `bugwhen` too, and none of `bugnot`
	local function bugapplies(node): boolean
		if not node.bug then return false end
		for _, id in node.bugwhen or {} do
			if not ticked[id] then return false end
		end
		for _, id in node.bugnot or {} do
			if ticked[id] then return false end
		end
		return true
	end

	for _, id in checked do
		local node = byid[id]
		if node.setup then table.insert(setups, node.setup) end
		if node.arm then table.insert(arms, node.arm) end
		if node.post then table.insert(posts, node.post) end
		if bugapplies(node) then
			table.insert(bugs, node.bug)
			table.insert(bugids, id)
		end
		if node.settle then settle = true end
		if node.queue then queue = node.queue end
		for name, value in node.slots or {} do
			slots[name] = value
		end
	end

	local tail = {}
	if settle then table.insert(tail, "checkpoint 'returned'\nsettle()") end
	table.move(posts, 1, #posts, #tail + 1, tail)

	local ret = fillslots(spec.ret, slots)
	table.insert(tail, ret)

	local blocks = {}
	local function block(lines)
		local text = table.concat(lines, '\n')
		if text ~= '' then table.insert(blocks, text) end
	end

	block { spec.preamble, table.concat(setups, '\n') }
	block { spec.prep or '', table.concat(arms, '\n') }
	block { spec.call }
	block(tail)

	local code = fillslots(table.concat(blocks, '\n\n'), slots):gsub('\n\n+', '\n\n'):gsub('^\n+', '')
	local seedblock = fillslots(`{spec.preamble}\n{table.concat(setups, '\n')}`, slots)
		:gsub('\n\n+', '\n\n')
		:gsub('^\n+', '')
		:gsub('\n+$', '')
	local upto = if seedblock == '' then 0 else #seedblock:split '\n'
	local shown, ran = hideseeds(code, upto, spec.name)
	return shown, ran, bugs, bugids, queue
end

return {
	compose = compose,
}
