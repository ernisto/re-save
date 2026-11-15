-- The globals a snippet runs with: the wrapped library, DataStore helpers,
-- checkpoints, hover-value capture and a safe subset of the standard library.
local query = require '@std/syntax/query'
local syntax = require '@std/syntax'
local task = require '@lute/task'

local faults = require '@self/faults'
local mock = require './../../mock'
local paths = require './paths'
local printer = require './printer'
local resave = require '@self/resave'
local snapshot = require './snapshot'

-- settle() waits both: real time for the save loop, frames for spawned threads
local BG_FRAMES = 30
local SETTLE_SECONDS = 0.1

-- labels a function by its snippet body (`line 4: d.coins += 1`), else by its source
local function makefnlabel(code: string)
	local lines = code:split '\n'

	-- [line of `function`] = line of its `end`
	local functions = query.findAllFromRoot(syntax.parse(code), function(n)
		return if n.kind == 'expr' and n.tag == 'function' then n else nil
	end)

	local ends = {}
	for _, fn in functions.nodes do
		ends[fn.location.beginLine] = ends[fn.location.beginLine] or fn.location.endLine
	end

	return function(fn)
		local source, line = debug.info(fn, 'sl')
		local insnippet = source == 'snippet' or source == '=snippet' or source == '@snippet'
		if not insnippet then return `fn {paths.cleanpaths(source)}:{line}` end

		local body = {}
		for i = line + 1, (ends[line] or line + 1) - 1 do
			table.insert(body, (lines[i]:gsub('^%s+', '')))
		end

		return `line {line}: {table.concat(body, '; ')}`
	end
end

-- waits real time, not frames: the library's save loop runs every 1/60 s, so a
-- frame count would let it run in some builds and not others
local function settle()
	local start = os.clock()
	local frames = 0

	while os.clock() - start < SETTLE_SECONDS or frames < BG_FRAMES do
		task.wait()
		frames += 1
	end
end

-- appended by instrument() to each top-level `local` line
-- args: (name, value, declared here?) triples; only changed values are kept
local function makecapture(ctx)
	return function(first: number, last: number, ...)
		local args = table.pack(...)

		for i = 1, args.n, 3 do
			local name, value, declares = args[i], args[i + 1], args[i + 2]
			local isnew = printer.issession(value) and not table.find(ctx.sessions, value)
			if isnew then table.insert(ctx.sessions, value) end

			local text = printer.describevalue(value, ctx)
			if declares or ctx.lastvalue[name] ~= text then
				ctx.lastvalue[name] = text
				table.insert(ctx.vars, { name = name, from = first, to = last, declares = declares, value = text })
			end
		end
	end
end

-- os.clock ticks 1, 2, 3… per call: still different on every read, but the same in every run
local function makeos(ctx)
	local fakeos = table.clone(os)
	fakeos.clock = function()
		ctx.clock += 1
		return ctx.clock
	end
	return fakeos
end

local function makeenv(ctx, code: string, realresave)
	ctx.fnlabel = makefnlabel(code)

	return {
		resave = resave.wrapresave(ctx, realresave),
		txcloud = mock.stores.tx.data,
		now = ctx.now,

		cloud = faults.cloud,
		fail = faults.fail,
		heal = faults.heal,
		failwrite = faults.makefailwrite(ctx),
		settle = settle,
		checkpoint = function(label: string)
			snapshot.snapshot(label, ctx)
		end,
		__capture = makecapture(ctx),

		task = task,
		assert = assert,
		error = error,
		pcall = pcall,
		print = print,
		type = type,
		tostring = tostring,
		next = next,
		select = select,
		table = table,
		string = string,
		math = math,
		os = makeos(ctx),
		coroutine = coroutine,
		vector = vector,
	}
end

return {
	makeenv = makeenv,
}
