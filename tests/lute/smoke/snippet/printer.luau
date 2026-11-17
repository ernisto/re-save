local paths = require './paths'
local types = require './types'
local cleanpaths = paths.cleanpaths

-- value printer: Luau literal, sorted keys, os.time() shown relative to now
local function issession(value: any): boolean
	return type(value) == 'table' and value.pendingupdates ~= nil and value.store ~= nil
end

local function isstore(value: any): boolean
	return type(value) == 'table' and value.ds ~= nil and value.tracking ~= nil and value.schema ~= nil
end

local function keyorder(a: any, b: any): boolean
	if type(a) == type(b) and (type(a) == 'number' or type(a) == 'string') then return a < b end
	return tostring(a) < tostring(b)
end

local printvalue

local function printtable(t: { [any]: any }, ctx: types.ctx, depth: number): string
	if next(t) == nil then return '{}' end

	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys, keyorder)

	local isarray = #keys == #t
	local pad = string.rep('  ', depth + 1)
	local parts = {}

	for _, k in keys do
		local v = printvalue(t[k], ctx, depth + 1)
		local isident = type(k) == 'string' and k:match '^[%a_][%w_]*$'
		local label = if isarray then '' elseif isident then `{k} = ` else `[{printvalue(k, ctx, 0)}] = `
		table.insert(parts, pad .. label .. v)
	end

	local oneline = '{ ' .. table.concat(parts, ', '):gsub('\n%s*', ' '):gsub('^%s+', ''):gsub(',%s+', ', ') .. ' }'
	if #oneline <= 60 and not oneline:find '\n' then return oneline end

	return '{\n' .. table.concat(parts, ',\n') .. ',\n' .. string.rep('  ', depth) .. '}'
end

function printvalue(value: any, ctx: types.ctx, depth: number?): string
	depth = depth or 0

	if type(value) == 'string' then return string.format('%q', cleanpaths(value)) end
	if type(value) == 'number' and math.abs(value - ctx.now) < 100000 then
		local delta = value - ctx.now
		return if delta >= 0 then `now+{delta}` else `now{delta}`
	end
	if type(value) == 'function' then return ctx.fnlabel(value) end
	if issession(value) then return `<session '{value.key}'>` end
	if isstore(value) then return `<store '{ctx.labels[value] or '?'}'>` end
	if type(value) == 'table' then return printtable(value, ctx, depth :: number) end

	return tostring(value)
end

-- hover text for a snippet variable: like printvalue, but sessions show their state
-- and strings keep real line breaks
local function describevalue(value: any, ctx: types.ctx): string
	if type(value) == 'string' then return `"{cleanpaths(value)}"` end
	if not issession(value) then return printvalue(value, ctx) end

	local state = {
		tracked = value.store.tracking[value.key] == value,
		frozen = table.isfrozen(value),
		data = value.data,
		oplog = #value.pendingupdates,
	}
	if value.base ~= value.data then state.base = value.base end
	return `<session '{value.key}'> ` .. printtable(state, ctx, 0)
end

return {
	issession = issession,
	printvalue = printvalue,
	describevalue = describevalue,
}
