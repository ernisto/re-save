-- docs/<folder>/<n>-<slug>.md, in file name order: `# Title`, then the body.
local fs = require '@lute/fs'

local files = require './files'
local tutorials = require './tutorials/check'

local function readpages(folder: string, version: string, check: ((file: string, body: string) -> ())?)
	local names = {}
	for _, entry in fs.listdir(`{files.repo}/docs/{folder}`) do
		if entry.type == 'file' and entry.name:match '%.md$' then table.insert(names, entry.name) end
	end
	table.sort(names)

	local pages = {}
	for _, file in names do
		local text = files.readfile(`{files.repo}/docs/{folder}/{file}`):gsub('\r\n', '\n'):gsub('{{version}}', version)
		local title, body = text:match '^# ([^\n]+)\n(.*)$'
		if not title then error(`docs/{folder}/{file} must start with a '# Title' line`) end

		if check then check(file, body) end
		table.insert(pages, { slug = file:gsub('^%d+%-', ''):gsub('%.md$', ''), title = title, md = body })
	end
	return pages
end

-- `## ` steps checked phrase by phrase, or plain markdown when no phrase lights code
local function readtutorials(version: string)
	return readpages('tutorials', version, function(file, body)
		local isstory = body:find '%]%(code:' or body:find '%]%(mark:'
		if isstory then tutorials.checktutorial(file, body) end
	end)
end

local function readexamples(version: string)
	return readpages('examples', version)
end

return {
	readtutorials = readtutorials,
	readexamples = readexamples,
}
