-- JSON with sorted keys, so the same data always gives the same text.
local function jsonstring(s: string): string
	local escaped = s:gsub('[%c"\\]', function(c)
		if c == '"' then return '\\"' end
		if c == '\\' then return '\\\\' end
		if c == '\n' then return '\\n' end
		if c == '\t' then return '\\t' end
		return string.format('\\u%04x', string.byte(c))
	end)
	return '"' .. escaped .. '"'
end

local function tojson(value: any): string
	if type(value) == 'string' then return jsonstring(value) end
	if type(value) == 'boolean' or type(value) == 'number' then return tostring(value) end
	if value == nil then return 'null' end

	local isarray = #value > 0 or next(value) == nil
	local parts = {}

	if isarray then
		for _, v in value do
			table.insert(parts, tojson(v))
		end
		return '[' .. table.concat(parts, ',') .. ']'
	end

	local keys = {}
	for k in value do
		table.insert(keys, k)
	end
	table.sort(keys)

	for _, k in keys do
		table.insert(parts, jsonstring(k) .. ':' .. tojson(value[k]))
	end
	return '{' .. table.concat(parts, ',') .. '}'
end

return {
	tojson = tojson,
}
