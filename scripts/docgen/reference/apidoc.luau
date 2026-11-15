local fs = require '@lute/fs'

local files = require '../files'

local readfile, repo = files.readfile, files.repo

-- docs/api/<name>.md: `---` front matter of `key: value` lines, then markdown.
-- `## Parameters` (| Name | Description |) and `## Returns` (| Description |)
-- are taken out and matched against the real signature from reflect.
local function readdoc(name: string)
	local path = `{repo}/docs/api/{name}.md`
	if not fs.exists(path) then error(`missing {path}`, 2) end

	local text = readfile(path):gsub('\r\n', '\n')
	local front, body = text:match '^%-%-%-\n(.-)%-%-%-\n(.*)$'
	if not front then error(`{path} has no front matter`, 2) end

	local meta = {}
	for key, value in front:gmatch '([%w_]+):%s*([^\n]*)' do
		meta[key] = value
	end

	local sections = {}
	local kept = {}
	local current

	for _, line in body:split '\n' do
		local title = line:match '^## (.+)$'
		if title == 'Parameters' or title == 'Returns' then
			current = title
			sections[title] = {}
		elseif title then
			current = nil
			table.insert(kept, line)
		elseif current then
			local isrow = line:match '^|'
				and not line:match '^|%-'
				and not line:match '^| *Name *|'
				and not line:match '^| *Description *|$'
			if isrow then
				local cells = {}
				local inner = line:gsub('\\|', '\0'):match '^|(.*)|%s*$'
				for _, cell in inner:split '|' do
					table.insert(cells, (cell:gsub('%z', '|'):match '^%s*(.-)%s*$'))
				end
				table.insert(sections[current], cells)
			end
		else
			table.insert(kept, line)
		end
	end

	return {
		path = path,
		meta = meta,
		body = table.concat(kept, '\n'):match '^%s*(.-)%s*$',
		params = sections.Parameters or {},
		returns = sections.Returns or {},
	}
end

local function joindoc(doc, fn)
	local descs = {}
	for _, row in doc.params do
		local name = row[1]:gsub('`', '')
		descs[name] = row[2]
	end

	local params = {}
	for _, p in fn.params do
		local desc = descs[p.name]
		if not desc then error(`{doc.path}: no description for parameter '{p.name}' (from {fn.source})`) end
		descs[p.name] = nil
		table.insert(params, { name = p.name, type = p.type, desc = desc })
	end
	local extra = next(descs)
	if extra then error(`{doc.path}: describes '{extra}', which is not a parameter of {fn.source}`) end

	if #doc.returns ~= #fn.returns then
		error(`{doc.path}: {#doc.returns} return descriptions, but {fn.source} returns {#fn.returns} values`)
	end
	local returns = {}
	for i, r in fn.returns do
		table.insert(returns, { type = r, desc = doc.returns[i][1] })
	end

	return params, returns
end

-- [text](case:a,b) links in the page text must name a recorded case of the function
local function checkcaselinks(doc, params, returns, runs, fnname: string)
	local texts = { doc.body }
	for _, p in params do
		table.insert(texts, p.desc)
	end
	for _, r in returns do
		table.insert(texts, r.desc)
	end

	for _, text in texts do
		for ids in text:gmatch '%]%(case:([^)]*)%)' do
			local list = if ids == '' then {} else ids:split ','
			table.sort(list)
			local key = table.concat(list, ',')
			if not runs[key] then
				error(`{doc.path}: link to case '{ids}', which is not a recorded case of {fnname}`)
			end
		end
	end
end

return {
	readdoc = readdoc,
	joindoc = joindoc,
	checkcaselinks = checkcaselinks,
}
