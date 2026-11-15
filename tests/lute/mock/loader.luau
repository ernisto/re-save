-- Loads lib/ inside a fake Roblox environment (game, warn, Enum, task) with its
-- own `require`, so the library runs under lute as it would on a server.
local fs = require '@lute/fs'
local luau = require '@lute/luau'
local task = require '@lute/task'

local services = require './services'

local here = (debug.info(1, 's') or ''):gsub('^@', ''):gsub('\\', '/')
local dir = here:match '^(.*)/[^/]+$'
local repo = dir:match '^(.*)/tests/lute/mock$' or '.'
local root = `{repo}/lib`

local sources = {}
local modules = {}
local closers = {}
local warnings = {}
local state = { closed = false }

local robloxtask = table.clone(task)
robloxtask.cancel = coroutine.close

local function readsource(path: string): string
	local handle = fs.open(path, 'r')
	local text = fs.read(handle)
	fs.close(handle)
	return text
end

local env = {
	game = {
		GetService = function(_, name)
			return services.getservice(name)
		end,
		BindToClose = function(_, fn)
			table.insert(closers, fn)
		end,
	},
	warn = function(...)
		table.insert(warnings, table.concat({ ... }, ' '))
		print(...)
	end,
	Enum = { DataStoreRequestType = { UpdateAsync = 'update' } },
	task = robloxtask,

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
	vector = vector,
	debug = debug,
}

-- `@self/x` from anywhere, `./x` from inside lib/
local function resolve(spec: string, from: string): string
	local name, base
	if spec:sub(1, 6) == '@self/' then
		name, base = spec:sub(7), root
	elseif spec:sub(1, 2) == './' then
		name, base = spec:sub(3), from
	else
		error(`unhandled require '{spec}'`, 3)
	end

	local path = base .. '/' .. name
	if sources[path .. '.luau'] then return path .. '.luau' end
	return path .. '/init.luau'
end

local function loadsources()
	for _, entry in fs.listdir(root) do
		if entry.type == 'file' then sources[`{root}/{entry.name}`] = readsource(`{root}/{entry.name}`) end
	end
end

function env.require(spec: string): any
	if next(sources) == nil then loadsources() end

	local caller = (debug.info(2, 's') or ''):gsub('^@', ''):gsub('\\', '/')
	local from = caller:match '^(.*)/[^/]+$' or root
	local path = resolve(spec, from)

	local loaded = modules[path]
	if loaded ~= nil then return loaded end
	if not sources[path] then error(`no lib module at {path}`, 2) end

	local fn = luau.load(luau.compile(sources[path]), '@' .. path, env)
	modules[path] = false -- cycle guard: reentrant requires of self get false
	modules[path] = fn()
	return modules[path]
end

-- runs every BindToClose callback, like a server shutting down
local function close()
	state.closed = true
	for _, fn in closers do
		fn()
	end
end

local function isclosed(): boolean
	return state.closed
end

-- after close, the loaded library has stopped its save loop for good: the next
-- require loads a fresh copy (callers keep the copy they already have)
local function reopen()
	state.closed = false
	table.clear(modules)
end

return {
	require = env.require,
	warnings = warnings,
	close = close,
	isclosed = isclosed,
	reopen = reopen,
}
