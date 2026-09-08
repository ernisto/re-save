local REMOVE = table.freeze {}
local NOCHANGE = nil

type REMOVE = {}

-- patch {...} with {} = nil
-- patch  nil  with {} = {}
local function isremove(old: any, diff: any)
	return old ~= nil and type(diff) == 'table' and next(diff) == nil
end

-- functions
local function difffrom<T>(old: T, new: T): T | REMOVE?
	if new == old then return NOCHANGE end
	if new == nil then return REMOVE end
	if type(old) ~= 'table' or type(new) ~= 'table' then return new end

	local diff = {}
	local removes = table.clone(old)

	for key, newnalue in new do
		diff[key] = difffrom(old[key], newnalue)
		removes[key] = nil
	end
	for key in removes do
		diff[key] = REMOVE
	end

	return if next(diff) == nil then NOCHANGE else diff
end

local function applydiff<T>(old: T, diff: any): T?
	if diff == nil then return old end
	if old == nil then return diff end
	if isremove(old, diff) then return nil end
	if type(diff) ~= 'table' or type(old) ~= 'table' then return diff end

	for key, new in diff do
		local newvalue = applydiff(old[key], new)
		if newvalue ~= old[key] then old[key] = newvalue end -- readonly caution
	end
	return old
end

-- module
return table.freeze {
	apply = applydiff,
	from = difffrom,

	no_change = NOCHANGE,
	remove = REMOVE,
}
