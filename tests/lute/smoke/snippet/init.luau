-- Runs one docs snippet in a clean mock and records what it did.
-- Used by the docs build (API reference) and tests/lute/smoke/tests (its snapshots).
local luau = require '@lute/luau'

local env = require '@self/env'
local instrument = require '@self/instrument'
local json = require '@self/json'
local mock = require './../mock'
local paths = require '@self/paths'
local printer = require '@self/printer'
local signature = require '@self/signature'
local snapshot = require '@self/snapshot'
local types = require '@self/types'

-- the library, loaded on the first run: a module can't yield while it loads
local realresave: any
local runcount = 0

-- after mock.close() the loaded library's save loop is gone for good: load a fresh one
local function preparelibrary()
	if mock.closed() then
		mock.reopen()
		realresave = nil
	end
	realresave = realresave or mock.require '@self/init'

	-- sessions other tests left tracked would share the save loop and shift its timing
	for _, st in mock.require('@self/session').stores do
		table.clear(st.tracking)
	end
	mock.reset()
end

local function newctx(fnname: string, code: string): types.ctx
	runcount += 1

	return {
		id = `{fnname}{runcount}`,
		fnname = fnname,
		now = os.time(),
		stores = {},
		labels = {},
		sessions = {},
		checkpoints = {},
		vars = {},
		lastvalue = {},
		restores = {},
		warnseen = #mock.warnings,
		clock = 0,
		input = nil,
		fnlabel = env.makefnlabel(code),
	}
end

local function collectreturns(results: { n: number, [number]: any }, ctx: types.ctx)
	local returned = {}

	for i = 1, results.n - 1 do
		local v = results[i]
		if printer.issession(v) then table.insert(ctx.sessions, v) end

		local isstring = type(v) == 'string'
		local text = if isstring then paths.cleanpaths(v) else printer.printvalue(v, ctx)
		table.insert(returned, { text = text, isstring = isstring })
	end

	return returned
end

-- undo failwrite patches and untrack the run's sessions, so the next run starts clean
local function cleanup(ctx: types.ctx)
	for i = #ctx.restores, 1, -1 do
		ctx.restores[i]()
	end

	for _, st in ctx.stores do
		table.clear(st.tracking)
	end
end

-- `code` = the shown snippet (for function labels), `ran` = what actually runs (same lines)
local function run(fnname: string, code: string, ran: string): types.result
	preparelibrary()
	local ctx = newctx(fnname, code)

	local globals = env.makeenv(ctx, realresave)
	local fn = luau.load(luau.compile(instrument.instrument(ran)), '=snippet', globals)

	local results = table.pack(pcall(fn))
	local ok = table.remove(results, 1)
	local returned = if ok then collectreturns(results, ctx) else {}

	snapshot.snapshot(if ok then 'end' else 'after throw', ctx)
	cleanup(ctx)

	return {
		thrown = if ok then nil else paths.cleanpaths(tostring(results[1])),
		returned = returned,
		checkpoints = ctx.checkpoints,
		vars = ctx.vars,
		input = ctx.input or { cloud = {}, tx = {} },
	}
end

local function outcome(result: types.result): 'throws' | 'err' | 'warn' | 'ok'
	if result.thrown then return 'throws' end

	for _, r in result.returned do
		if r.isstring then return 'err' end
	end

	for _, cp in result.checkpoints do
		if #cp.warnings > 0 then return 'warn' end
	end

	return 'ok'
end

return {
	run = run,
	outcome = outcome,
	signature = signature.signature,
	tojson = json.tojson,
}
