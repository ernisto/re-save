local DataStoreService = game:GetService 'DataStoreService'

-- defs
local budgetwindow = 1 * 60
local working = {}

-- functions
local function store(id: string): DataStore
	return DataStoreService:GetDataStore(id)
end

local function awaitlock(ds: DataStore, key: string)
	if not working[ds] then working[ds] = {} end
	if not working[ds][key] then working[ds][key] = {} end

	local id = {}
	table.insert(working[ds][key], id)

	while working[ds][key] and working[ds][key][1] ~= id do
		task.wait()
	end
end
local function unlock(ds: DataStore, key: string)
	if not working[ds] then return end
	if not working[ds][key] then return end

	table.remove(working[ds][key], 1)

	if next(working[ds][key]) then working[ds][key] = nil end
	if next(working[ds]) then working[ds] = nil end
end

local function awaitbudget()
	while not DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync) do
		task.wait()
	end
	return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
end

local function awaitget<T>(ds: DataStore, key: string): (string?, T?)
	awaitlock(ds, key)
	local success, result = xpcall(ds.GetAsync, debug.traceback :: any, ds, key)
	unlock(ds, key)

	if success then
		return nil, result
	else
		return result, nil
	end
end
local function awaitupdate<T>(ds: DataStore, key: string, update: (any) -> T?): (string?, T?)
	awaitlock(ds, key)
	local success, result = xpcall(ds.UpdateAsync, debug.traceback :: any, ds, key, update)
	unlock(ds, key)

	if success then
		return nil, result
	else
		return result, nil
	end
end
local function awaitremove<T>(ds: DataStore, key: string): (string?, T?)
	awaitlock(ds, key)
	local success, result = xpcall(ds.RemoveAsync, debug.traceback :: any, ds, key)
	unlock(ds, key)

	if success then
		return nil, result
	else
		return result, nil
	end
end

-- export
return {
	budgetwindow = budgetwindow,

	store = store,
	awaitget = awaitget,
	awaitupdate = awaitupdate,
	awaitremove = awaitremove,
	awaitbudget = awaitbudget,
}
