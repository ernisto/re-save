-- Parses lib/ modules once: their requires, local functions, type aliases and exports.
local syntax = require '@std/syntax'

local files = require '../files'

local readfile = files.readfile

local function requirepath(stat, libdir: string): string?
	local value = stat.values[1] and stat.values[1].node
	if not value or value.tag ~= 'call' then return nil end
	if value.func.tag ~= 'global' or value.func.name.text ~= 'require' then return nil end

	local arg = value.arguments[1] and value.arguments[1].node
	if not arg or arg.tag ~= 'string' then return nil end

	local spec = arg.token.text
	local name = spec:match '^@self/(.+)$' or spec:match '^%./(.+)$'
	if not name then error(`unhandled require '{spec}'`) end
	return `{libdir}/{name}.luau`
end

local modules = {}

local function loadmodule(path: string, libdir: string)
	if modules[path] then return modules[path] end

	local source = readfile(path):gsub('\r\n', '\n')
	local ast = syntax.parse(source)
	local mod = {
		path = path,
		file = path:match '([^/\\]+)$',
		lines = source:split '\n',
		requires = {},
		functions = {},
		aliases = {},
		exports = nil,
	}
	modules[path] = mod

	for _, stat in ast.root.statements do
		if stat.tag == 'local' then
			local target = requirepath(stat, libdir)
			if target then mod.requires[stat.variables[1].node.name.text] = target end
		elseif stat.tag == 'localfunction' then
			mod.functions[stat.name.name.text] = stat
		elseif stat.tag == 'typealias' then
			mod.aliases[stat.name.text] = stat
		elseif stat.tag == 'return' then
			local expr = stat.expressions[1].node
			if expr.tag == 'call' then expr = expr.arguments[1].node end
			if expr.tag ~= 'table' then error(`{mod.file}: module must return a table`) end

			mod.exports = {}
			for _, entry in expr.entries do
				if entry.kind == 'record' then mod.exports[entry.key.text] = entry.value end
			end
		end
	end

	return mod
end

return {
	loadmodule = loadmodule,
}
