-- Builds scripts/docgen/site/index.html, one self-contained page: site/shell.html with
-- its styles, its app (site/app, one script) and the page data: the API reference (every
-- case of tests/lute/smoke/conditions run against the test mock), the tutorials and the
-- examples.
-- usage: lute run scripts/docgen/build.luau
local bundle = require './bundle'
local files = require './files'
local mock = require '../../tests/lute/mock'
local pages = require './pages'
local reference = require './reference'
local reflect = require './reflect'
local snippet = require '../../tests/lute/smoke/snippet'

local SITE = `{files.repo}/scripts/docgen/site`
local STYLES = { 'base', 'header', 'members', 'code', 'tryit', 'result', 'tooltip', 'pages', 'tutorials', 'walk' }

-- the shell's /*NAME*/ marker becomes `text`
local function fill(shell: string, name: string, text: string): string
	local start, finish = shell:find(`/*{name}*/`, 1, true)
	if not start then error(`scripts/docgen/site/shell.html is missing /*{name}*/`, 2) end

	return shell:sub(1, start - 1) .. text .. shell:sub(finish + 1)
end

local function readstyles(): string
	local parts = {}
	for _, name in STYLES do
		table.insert(parts, files.readfile(`{SITE}/style/{name}.css`))
	end
	return table.concat(parts, '\n')
end

local function build()
	local reflected = reflect(`{files.repo}/lib`)
	local functions, total = reference.buildreference(reflected)
	local version = files.readfile(`{files.repo}/wally.toml`):match 'version%s*=%s*"([^"]+)"'

	local data = {
		functions = functions,
		types = reflected.types,
		links = reflected.links,
		version = version,
		tutorials = pages.readtutorials(version),
		examples = pages.readexamples(version),
	}

	-- the data and the app sit in <script> tags: no `</` may end them early
	local json = snippet.tojson(data):gsub('</', '<\\/')
	local app = bundle.bundle(`{SITE}/app/main.js`, `{SITE}/app`)
	if app:find('</script', 1, true) then error('scripts/docgen/site/app: "</script" would end the page script', 0) end

	-- last marker first, so text put in never holds a marker still to fill
	local page = files.readfile(`{SITE}/shell.html`)
	page = fill(page, 'SCRIPT', app)
	page = fill(page, 'DATA', json)
	page = fill(page, 'STYLE', readstyles())
	files.writefile(`{SITE}/index.html`, page)
	print(`wrote {SITE}/index.html ({#functions} functions, {#reflected.types} types, {total} combinations)`)
end

-- the library's background sync loop keeps lute running: stop it even when the build fails
local ok, err = pcall(build)
mock.close()
if not ok then error(err, 0) end
