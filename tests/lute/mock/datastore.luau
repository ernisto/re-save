-- A fake DataStore: plain `data` table, plus `_failget` / `_failupdate` /
-- `_failremove` flags tests set to make the next calls fail.

-- roblox serializes every value, so callers never share tables with the store
local function deepcopy(value: any): any
	if type(value) ~= 'table' then return value end

	local out = {}
	for k, v in value do
		out[k] = deepcopy(v)
	end
	return out
end

local function newdatastore(id: string)
	local ds: any = { id = id, Name = id, data = {} }

	ds.GetAsync = function(_, key)
		if ds._failget then error 'get failed' end
		return deepcopy(ds.data[key])
	end

	ds.UpdateAsync = function(_, key, update)
		if ds._failupdate then error 'update failed' end

		local new = update(deepcopy(ds.data[key]))
		if new ~= nil then ds.data[key] = deepcopy(new) end
		return deepcopy(new)
	end

	ds.RemoveAsync = function(_, key)
		if ds._failremove then error 'remove failed' end

		local old = ds.data[key]
		ds.data[key] = nil
		return old
	end

	return ds
end

-- empties the store and clears its fail flags
local function resetdatastore(ds)
	table.clear(ds.data)
	ds._failget = nil
	ds._failupdate = nil
	ds._failremove = nil
end

return {
	newdatastore = newdatastore,
	resetdatastore = resetdatastore,
}
