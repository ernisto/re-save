-- Paths in errors and labels, relative to the repo.
local here = (debug.info(1, 's') or ''):gsub('^@', ''):gsub('\\', '/')
local repo = here:match '^(.*)/tests/lute/smoke/snippet/[^/]+$'

local function cleanpaths(text: string): string
	local slashed = text:gsub('\\', '/')
	local root = repo:gsub('\\', '/')
	local escaped = root:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]', '%%%0')

	local relative = slashed:gsub(escaped .. '/', '')

	-- store names get a per-run suffix to stay unique; hide it
	return (relative:gsub('#%a+%d+', ''))
end

return {
	cleanpaths = cleanpaths,
}
