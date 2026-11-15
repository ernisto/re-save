-- Fake DataStoreService and HttpService, and the state they share with tests:
-- the stores by id, the request budget and the GUID counter.
local datastore = require './datastore'

local DEFAULT_BUDGET = 100

local stores = {}
local state = { budget = DEFAULT_BUDGET, guidcount = 0 }

-- like HttpService:JSONEncode: plain data only; vectors, functions and other
-- engine values raise. Strings keep their bytes, so non-ASCII text shows up as a
-- longer byte length. `__jsonfail` stays as a test marker.
local function encodejson(value: any): string
	local kind = type(value)
	if kind == 'nil' then return 'null' end
	if kind == 'boolean' or kind == 'number' then return tostring(value) end
	if kind == 'string' then return string.format('%q', value) end

	if kind == 'table' then
		if value.__jsonfail then error 'invalid json' end

		local parts = {}
		for k, v in value do
			table.insert(parts, encodejson(tostring(k)) .. ':' .. encodejson(v))
		end
		table.sort(parts)
		return '{' .. table.concat(parts, ',') .. '}'
	end

	error(`Can't convert {typeof(value)} to JSON`)
end

local DataStoreService = {
	GetDataStore = function(_, id: string)
		stores[id] = stores[id] or datastore.newdatastore(id)
		return stores[id]
	end,
	GetRequestBudgetForRequestType = function()
		return state.budget
	end,
}

local HttpService = {
	GenerateGUID = function()
		state.guidcount += 1
		return `guid-{state.guidcount}`
	end,
	JSONEncode = function(_, value)
		if type(value) == 'table' and value.__nonascii then return 'héllo' end
		return encodejson(value)
	end,
}

local SERVICES = { DataStoreService = DataStoreService, HttpService = HttpService }

local function getservice(name: string)
	return SERVICES[name] or error(`no fake for service '{name}'`, 2)
end

local function setbudget(n: number)
	state.budget = n
end

local function guidpeek(): string
	return `guid-{state.guidcount + 1}`
end

-- every store empty and healthy, budget and GUIDs back to the start
local function resetservices()
	for _, ds in stores do
		datastore.resetdatastore(ds)
	end
	state.guidcount = 0
	state.budget = DEFAULT_BUDGET
end

return {
	stores = stores,
	getservice = getservice,
	setbudget = setbudget,
	guidpeek = guidpeek,
	resetservices = resetservices,
}
