-- Joins the site's ES modules into the one inline script of the page, so it opens
-- from a file too. Modules come in dependency order with their relative imports and
-- `export` keywords dropped: they all share one scope, so a top-level name may be
-- declared once only. Other imports (the CDN) are kept, once each.
local files = require './files'

local readfile = files.readfile

local function dirof(path: string): string
	return path:match '^(.*)/[^/]*$' or '.'
end

-- `dir` + './x.js' or '../x.js'
local function resolve(dir: string, spec: string): string
	local parts = dir:split '/'
	for _, part in spec:split '/' do
		if part == '..' then
			table.remove(parts)
		elseif part ~= '.' then
			table.insert(parts, part)
		end
	end
	return table.concat(parts, '/')
end

-- names a top-level line declares: `function f`, `const a`, `const [a, b] =`, `const { a, b } =`
local function declared(line: string): { string }
	local single = line:match '^function%s+([%w_$]+)' or line:match '^async function%s+([%w_$]+)'
	single = single or line:match '^const%s+([%w_$]+)' or line:match '^let%s+([%w_$]+)'
	if single then return { single } end

	local list = line:match '^const%s*%[([^%]]+)%]%s*=' or line:match '^const%s*{([^}]+)}%s*='
	local names = {}
	for name in (list or ''):gmatch '[%w_$]+' do
		table.insert(names, name)
	end
	return names
end

local function bundle(entry: string, root: string): string
	local state = {} -- [path] = 'adding' | 'done'
	local chunks, externals, seen = {}, {}, {}
	local owner = {} -- [top-level name] = module that declares it

	local function add(path: string)
		if state[path] == 'done' then return end
		if state[path] == 'adding' then error(`{path}: import cycle`, 0) end
		state[path] = 'adding'

		local where = path:sub(#root + 2)
		local body = {}
		for _, line in (readfile(path):gsub('\r\n', '\n')):split '\n' do
			local spec = line:match '^import .- from "(%.%.?/[^"]+)";$'
			if spec then
				add(resolve(dirof(path), spec))
			elseif line:match '^import ' then
				if not line:match ';$' then error(`{where}: an import must fit on one line`, 0) end
				if not seen[line] then table.insert(externals, line) end
				seen[line] = true
			else
				line = line:gsub('^export ', '')
				for _, name in declared(line) do
					if owner[name] then error(`{where}: '{name}' is already declared by {owner[name]}`, 0) end
					owner[name] = where
				end
				table.insert(body, line)
			end
		end

		state[path] = 'done'
		table.insert(chunks, `// {where}\n{table.concat(body, '\n')}`)
	end

	add(entry)
	return table.concat(externals, '\n') .. '\n\n' .. table.concat(chunks, '\n')
end

return {
	bundle = bundle,
}
