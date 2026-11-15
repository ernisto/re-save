-- Where each type is documented: Roblox docs for builtins and engine classes,
-- the page itself for lib types (queued here so reflect lists them).
local modules = require './modules'

local loadmodule = modules.loadmodule

local ROBLOX = 'https://create.roblox.com/docs/'

local BUILTINS = {
	number = 'luau/numbers',
	string = 'luau/strings',
	boolean = 'luau/booleans',
	['nil'] = 'luau/nil',
	table = 'luau/tables',
	any = 'luau/type-checking',
	unknown = 'luau/type-checking',
	never = 'luau/type-checking',
}

local ENGINE = {
	DataStore = 'reference/engine/classes/DataStore',
}

local GENERIC_DOCS = ROBLOX .. 'luau/type-checking'
local FUNCTION_DOCS = ROBLOX .. 'luau/functions'

-- resolve a type reference to where it is documented
local resolvealias

local function resolve(mod, ref, generics, libdir: string)
	local name = ref.name.text

	if ref.prefix then
		local target = mod.requires[ref.prefix.text]
		if not target then error(`{mod.file}: unknown module '{ref.prefix.text}' in type {ref.prefix.text}.{name}`) end
		return resolvealias(loadmodule(target, libdir), name, libdir)
	end

	if generics[name] then return { kind = 'generic', href = GENERIC_DOCS } end
	if BUILTINS[name] then return { kind = 'type', href = ROBLOX .. BUILTINS[name] } end
	if ENGINE[name] then return { kind = 'type', href = ROBLOX .. ENGINE[name] } end
	if mod.aliases[name] then return resolvealias(mod, name, libdir) end

	error(
		`{mod.file}: cannot resolve type '{name}'; add it to BUILTINS or ENGINE in scripts/docgen/reflect/resolve.luau`
	)
end

local documented = {} -- [module path .. ':' .. name] = typedef stub
local queue = {}

-- follows `type x<T> = other.x<T>` re-exports down to the defining module
function resolvealias(mod, name: string, libdir: string)
	local alias = mod.aliases[name]
	if not alias then error(`{mod.file}: no type named '{name}'`) end

	local body = alias.type
	local isforward = body.tag == 'reference' and body.prefix ~= nil and mod.requires[body.prefix.text] ~= nil
	if isforward then
		return resolvealias(loadmodule(mod.requires[body.prefix.text], libdir), body.name.text, libdir)
	end

	local key = `{mod.path}:{name}`
	if not documented[key] then
		documented[key] = { name = name, module = mod, alias = alias }
		table.insert(queue, documented[key])
	end
	return { kind = 'type', href = `#type-{name}` }
end

return {
	ROBLOX = ROBLOX,
	BUILTINS = BUILTINS,
	ENGINE = ENGINE,
	FUNCTION_DOCS = FUNCTION_DOCS,
	queue = queue,
	resolve = resolve,
}
