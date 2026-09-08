local record = require '../../lib/record'
local test = require '@std/test'

-- vars
local uid = 0
local shim

-- functions
local function init()
	if shim then return end
	shim = require './roblox'
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
	shim.stores.tx.data[txid] = {
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
			shim.reset()
		end)
		fn(s)
	end)
end

-- module
return {
	unique = unique,
	record = makerecord,
	maketest = maketx,
	throwscontains = throwscontains,
	suite = suite,
}
