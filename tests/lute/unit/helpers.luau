local record = require '../../../lib/record'
local test = require '@std/test'

-- vars
local uid = 0
local mock

-- functions
local function init()
	if mock then return end
	mock = require '../mock'
end

local function unique()
	uid += 1
	return `resave{uid}`
end

local function makerecord<T>(data: T, version: number?, pendingtx: record.txlock<T>?)
	return { data = data, version = version or 0, pendingtx = pendingtx }
end

local function maketx(txid: string, extra: { state: string?, adopts: { string }?, committimeout: number? })
	extra = extra or {}
	mock.stores.tx.data[txid] = {
		state = extra.state or 'pending',
		adopts = extra.adopts or {},
		committimeout = extra.committimeout or os.time() + 60,
	}
end

local function throwscontains(t, fn, needle)
	local ok, err = pcall(fn)
	t.that(not ok, `expected an error containing '{needle}'`)
	t.strContains(tostring(err), needle)
end

local function suite(name, fn)
	init()
	test.suite(name, function(s)
		s:afterEach(function()
			mock.reset()
		end)
		fn(s)
	end)
end

-- a library whose background save loop still runs: mock.close() stops it for good
local function liveresave()
	init()
	if mock.closed() then mock.reopen() end
	return mock.require '@self/init'
end

-- module
return {
	liveresave = liveresave,
	unique = unique,
	record = makerecord,
	maketest = maketx,
	throwscontains = throwscontains,
	suite = suite,
}
