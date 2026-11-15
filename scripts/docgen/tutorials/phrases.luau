-- The phrases of a tutorial line: [text](code:needle) and [text](mark:needle -> value).
-- the phrase targets of a line, and the line without its phrases (same rules as inline())
local function beatlinks(line: string, where: string): ({ string }, string)
	local targets, rest = {}, {}
	local i, n = 1, #line

	while i <= n do
		local c = line:sub(i, i)
		if c == '[' then
			local j = i + 1
			while j <= n and line:sub(j, j) ~= ']' do
				local close = if line:sub(j, j) == '`' then line:find('`', j + 1, true) else nil
				j = (close or j) + 1
			end

			local kind = line:sub(j, j + 6)
			if kind == '](code:' or kind == '](mark:' then
				local k, depth = j + 2, 0
				while k <= n do
					local ch = line:sub(k, k)
					if ch == ')' and depth == 0 then break end
					depth += if ch == '(' then 1 elseif ch == ')' then -1 else 0
					if depth > 1 then
						error(`{where}: nested parentheses in a phrase target: {line:sub(j + 2, k)}`, 0)
					end
					k += 1
				end
				if k > n then error(`{where}: unclosed phrase target: {line:sub(i)}`, 0) end

				table.insert(targets, line:sub(j + 2, k - 1))
				i = k + 1
				continue
			end
		end
		table.insert(rest, c)
		i += 1
	end
	return targets, table.concat(rest)
end

local function beatneedles(target: string): { string }
	if target:sub(1, 5) == 'code:' then return target:sub(6):split '|' end
	local spec = target:sub(6):split(' -> ')[1]
	return { (spec:gsub('»', '')) }
end

return {
	beatlinks = beatlinks,
	beatneedles = beatneedles,
}
