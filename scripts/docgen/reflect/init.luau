-- Reads the public API straight from lib/ with @std/syntax.
-- reflect(libdir) -> { functions = { fn }, types = { typedef }, links }
local modules = require '@self/modules'
local resolvemod = require '@self/resolve'
local tokens = require '@self/tokens'

local loadmodule = modules.loadmodule
local ROBLOX, BUILTINS, ENGINE, queue = resolvemod.ROBLOX, resolvemod.BUILTINS, resolvemod.ENGINE, resolvemod.queue
local generican, totokens = tokens.generican, tokens.totokens

-- public functions
local function findfunction(mod, value, libdir: string)
	if value.tag == 'local' then
		local stat = mod.functions[value.token.text]
		if not stat then error(`{mod.file}: '{value.token.text}' is not a local function`) end
		return mod, stat
	end

	if value.tag == 'indexname' and value.expression.tag == 'local' then
		local target = mod.requires[value.expression.token.text]
		if not target then error(`{mod.file}: '{value.expression.token.text}' is not a required module`) end

		local other = loadmodule(target, libdir)
		local exported = other.exports and other.exports[value.index.text]
		if not exported then error(`{other.file}: does not export '{value.index.text}'`) end
		return findfunction(other, exported, libdir)
	end

	error(`{mod.file}: cannot follow export of kind '{value.tag}'`)
end

local function reflectfunction(name: string, mod, stat, libdir: string)
	local func = stat.func
	local generics = generican({}, func.generics)

	local genericnames = {}
	for _, pair in func.generics or {} do
		table.insert(genericnames, pair.node.name.text)
	end

	local params = {}
	for _, pair in func.parameters do
		local param = pair.node
		if not param.annotation then error(`{mod.file}: parameter '{param.name.text}' of {name} has no type`) end
		table.insert(params, {
			name = param.name.text,
			type = totokens(mod, param.annotation, generics, libdir),
		})
	end

	local returns = {}
	local annotation = func.returnAnnotation
	if annotation and annotation.tag == 'explicit' then
		for _, pair in annotation.types do
			table.insert(returns, totokens(mod, pair.node, generics, libdir))
		end
	elseif annotation then
		table.insert(returns, totokens(mod, annotation, generics, libdir))
	end

	return {
		name = name,
		source = `lib/{mod.file}:{stat.location.beginLine}`,
		generics = genericnames,
		params = params,
		returns = returns,
	}
end

local function reflect(libdir: string)
	local root = loadmodule(`{libdir}/init.luau`, libdir)
	if not root.exports then error 'lib/init.luau must return a table of exports' end

	local functions = {}
	for name, value in root.exports do
		local mod, stat = findfunction(root, value, libdir)
		functions[name] = reflectfunction(name, mod, stat, libdir)
	end

	local types = {}
	local i = 1
	while queue[i] do
		local entry = queue[i]
		local alias = entry.alias
		local generics = generican({}, alias.generics)

		local genericnames = {}
		for _, pair in alias.generics or {} do
			table.insert(genericnames, pair.node.name.text)
		end

		table.insert(types, {
			name = entry.name,
			source = `lib/{entry.module.file}:{alias.location.beginLine}`,
			generics = genericnames,
			body = totokens(entry.module, alias.type, generics, libdir, true),
		})
		i += 1
	end
	table.sort(types, function(a, b)
		return a.name < b.name
	end)

	local links = {}
	for name, path in BUILTINS do
		links[name] = ROBLOX .. path
	end
	for name, path in ENGINE do
		links[name] = ROBLOX .. path
	end

	return { functions = functions, types = types, links = links }
end

return reflect
