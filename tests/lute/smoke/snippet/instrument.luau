local syntax = require '@std/syntax'

-- hover values: after every top-level statement, record the value of every local
-- declared so far. The call goes on the statement's last line so snippet line
-- numbers stay the same. Nothing can follow a `return`, so capturing stops there.
local function instrument(code: string): string
	local lines = code:split '\n'
	-- syntax trees are `any`: luau-lsp cannot narrow the lute AST unions (or read ParseResult.root)
	local ast: any = syntax.parse(code)
	local declared = {}

	local statements = ast.root.statements
	for k, stat in statements do
		if stat.tag == 'return' then break end
		-- a hidden seed shares its line with the next statement, which captures instead
		local after = statements[k + 1]
		if after and after.location.beginLine == stat.location.endLine then continue end

		local fresh = {}
		if stat.tag == 'local' then
			for _, pair in stat.variables do
				local name = pair.node.name.text
				if name ~= '_' then
					fresh[name] = true
					if not table.find(declared, name) then table.insert(declared, name) end
				end
			end
		end
		if #declared == 0 then continue end

		local args = {}
		for _, name in declared do
			table.insert(args, `'{name}', {name}, {if fresh[name] then 'true' else 'false'}`)
		end

		-- right after the statement, before any comment on its line
		local first, last, column = stat.location.beginLine, stat.location.endLine, stat.location.endColumn
		local line = lines[last]
		local call = `; __capture({first}, {last}, {table.concat(args, ', ')})`
		lines[last] = line:sub(1, column - 1) .. call .. line:sub(column)
	end

	return table.concat(lines, '\n')
end

return {
	instrument = instrument,
}
