-- lute loader for server/resave: builds a fake Roblox environment
-- (game/warn/Enum/task/DataStoreService/HttpService), compiles each
-- module into that shared environment with a custom `require`, and
-- returns `module, shim` where shim exposes the fake datastores.

local fs = require '@lute/fs'
local luau = require '@lute/luau'
local task = require '@lute/task'

local here = (debug.info(1, 's') or ''):gsub('^@', '')
local dir = here:match '^(.*)[/\\][^/\\]+$'
local root = `{dir}/../../lib`

-- vars
local guidcount = 0
local handles = {}
local sources = {}

-- functions
local function newdatastore(id)
	local ds: any = { id = id, data = {} }

	function ds:GetAsync(key)
		if ds._failget then error 'get failed' end
		return ds.data[key]
	end
	function ds:UpdateAsync(key, update)
		if ds._failupdate then error 'update failed' end
		local new = update(ds.data[key])
		if new ~= nil then ds.data[key] = new end
		return new
	end
	function ds:RemoveAsync(key)
		if ds._failremove then error 'remove failed' end
		local old = ds.data[key]
		ds.data[key] = nil
		return old
	end

	return ds
end

local function getservice(name)
	if name == 'DataStoreService' then
		return {
			GetDataStore = function(_, id)
				local ds = handles[id]
				if not ds then
					ds = newdatastore(id)
					handles[id] = ds
				end
				return ds
			end,
			GetRequestBudgetForRequestType = function()
				return true
			end,
		}
	end
	if name == 'HttpService' then
		return {
			GenerateGUID = function()
				guidcount += 1
				return `guid-{guidcount}`
			end,
			JSONEncode = function(_, value)
				if type(value) ~= 'table' or value.__jsonfail then error 'invalid json' end
				if value.__nonascii then return 'héllo' end
				return 'json'
			end,
		} :: any
	end
	error(`no fake for service '{name}'`)
end

local function source(path)
	local handle = fs.open(path, 'r')
	local src = fs.read(handle)
	fs.close(handle)
	return src
end

-- env
local modules = {}
local env = {
	game = {
		GetService = function(_, name)
			return getservice(name)
		end,
		BindToClose = function() end,
	},
	warn = print,
	Enum = { DataStoreRequestType = { UpdateAsync = 'update' } },
	task = task,

	assert = assert,
	error = error,
	pcall = pcall,
	xpcall = xpcall,
	select = select,
	type = type,
	typeof = typeof,
	tostring = tostring,
	tonumber = tonumber,
	next = next,
	print = print,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	rawget = rawget,
	rawset = rawset,
	rawequal = rawequal,
	rawlen = rawlen,
	unpack = unpack,
	string = string,
	table = table,
	math = math,
	os = os,
	coroutine = coroutine,
	utf8 = utf8,
	bit32 = bit32,
	buffer = buffer,
	debug = debug,
}

local function resolve(spec: string, from: string): string
	local name, base
	if spec:sub(1, 6) == '@self/' then
		name, base = spec:sub(7), root
	elseif spec:sub(1, 2) == './' then
		name, base = spec:sub(3), from
	else
		error(`unhandled require '{spec}'`)
	end

	local path = base .. '/' .. name
	if sources[path .. '.luau'] then return path .. '.luau' end
	return path .. '/init.luau'
end

function env.require(spec: string): any
	if next(sources) == nil then
		for _, entry in fs.listdir(root) do
			if entry.type == 'file' then
				local path = root .. '/' .. entry.name
				sources[path] = source(path)
			end
		end
	end

	local caller = (debug.info(2, 's') or ''):gsub('^@', ''):gsub('\\', '/')
	local from = caller:match '^(.*)[/\\][^/\\]+$' or root
	local path = resolve(spec, from)

	local loaded = modules[path]
	if loaded ~= nil then return loaded end

	local chunk = luau.compile(sources[path])
	local fn = luau.load(chunk, '@' .. path, env)

	modules[path] = false -- cycle guard: reentrant requires of self get false
	modules[path] = fn()
	return modules[path]
end

return table.freeze {
	require = env.require,
	stores = handles,
	guidpeek = function()
		return `guid-{guidcount + 1}`
	end,
	reset = function()
		for _, ds in handles do
			table.clear(ds.data)
			ds._failget = nil
			ds._failupdate = nil
			ds._failremove = nil
		end
		guidcount = 0
	end,
}
