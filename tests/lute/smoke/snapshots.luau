-- tests/lute/smoke/snapshots.json: what every smoke case did when last updated,
-- as { [function]: { [case key]: snippet.signature } }. One case per line, so a
-- behaviour change shows up as a one-line diff.
local fs = require '@lute/fs'
local json = require '@std/json'

local snippet = require './snippet'

local here = (debug.info(1, 's') or ''):gsub('^@', ''):gsub('\\', '/')
local path = `{here:match '^(.*)/[^/]+$'}/snapshots.json`

local loaded

local function readfile(): string
	local handle = fs.open(path, 'r')
	local text = fs.read(handle)
	fs.close(handle)
	return text
end

local function get(fnname: string, key: string): string
	if not loaded then loaded = if fs.exists(path) then json.deserialize(readfile()) else {} end

	local snapshot = loaded[fnname] and loaded[fnname][key]
	if not snapshot then
		error(`no snapshot for {fnname} '{key}': run lute run tests/lute/smoke/testgen.luau update`, 2)
	end
	return snapshot
end

local function sortedkeys(t): { string }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

local function write(results): string
	local blocks = {}
	for _, fnname in sortedkeys(results) do
		local rows = {}
		for _, key in sortedkeys(results[fnname]) do
			table.insert(rows, `\t\t{snippet.tojson(key)}: {snippet.tojson(results[fnname][key])}`)
		end
		table.insert(blocks, `\t{snippet.tojson(fnname)}: \{\n{table.concat(rows, ',\n')}\n\t}`)
	end

	local handle = fs.open(path, 'w+')
	fs.write(handle, `\{\n{table.concat(blocks, ',\n')}\n}\n`)
	fs.close(handle)
	return path
end

return {
	get = get,
	write = write,
}
