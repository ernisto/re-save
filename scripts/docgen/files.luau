-- Whole-file reads and writes, and where the repo is.
local fs = require '@lute/fs'

local here = (debug.info(1, 's') or ''):gsub('^@', ''):gsub('\\', '/')
local repo = here:match '^(.*)/scripts/docgen/[^/]+$'

local function readfile(path: string): string
	local handle = fs.open(path, 'r')
	local text = fs.read(handle)
	fs.close(handle)
	return text
end

local function writefile(path: string, text: string)
	local handle = fs.open(path, 'w+')
	fs.write(handle, text)
	fs.close(handle)
end

return {
	repo = repo,
	readfile = readfile,
	writefile = writefile,
}
