local fs = require '@lute/fs'
local luau = require '@lute/luau'
local process = require '@lute/process'

local files = require '../files'

local readfile, repo = files.readfile, files.repo

-- tests/lute/<folder>/<function>.luau: hand-written { case, result } for every intro
-- and limitation case. Every other case is a more case and has none; one where a
-- condition makes no difference shows the case it equals.
-- known: library bug · misuse: wrong calling code, always paired with a `fix` case
-- limit: something the library can't do · fix: the suggested fix for a misuse
local LIMIT_KINDS = { known = true, misuse = true, limit = true, fix = true }
local CASE_FOLDERS = { intro = 'intro', limitations = 'limitation' }

local function attachdescriptions(fnname: string, runs)
	-- DRAFT=1 skips descriptions entirely, to list the cases while writing them
	if process.env.DRAFT == '1' then return end

	for folder, group in CASE_FOLDERS do
		local where = `tests/lute/{folder}/{fnname}.luau`
		local path = `{repo}/{where}`
		if not fs.exists(path) then continue end
		local written = luau.load(luau.compile(readfile(path)), where)()

		for key, text in written do
			local list = if key == '' then {} else key:split ','
			table.sort(list)
			local sorted = table.concat(list, ',')
			if sorted ~= key then error(`{where}: key "{key}" must be sorted: "{sorted}"`) end
			if not runs[key] then error(`{where}: {fnname} has no case "{key}"`) end
			if runs[key].group ~= group then error(`{where}: "{key}" is a {runs[key].group} case`) end
			if not text.case or not text.result then error(`{where}: "{key}" needs case and result`) end
			runs[key].description = { case = text.case, result = text.result }

			-- the limitation note (kind, why it happens, what to do) belongs on limitation cases only
			local islimit = group == 'limitation'
			local haslimit = text.kind ~= nil or text.why ~= nil or text.todo ~= nil
			local needstodo = text.kind ~= 'fix' -- a fix explains why it works; there is nothing left to do
			if islimit and not (text.kind and text.why and (text.todo or not needstodo)) then
				error(`{where}: "{key}" needs kind, why and todo`)
			end
			if haslimit and not islimit then error(`{where}: "{key}" has a limitation note but is a {group} case`) end
			if islimit then
				if not LIMIT_KINDS[text.kind] then error(`{where}: "{key}" has unknown kind "{text.kind}"`) end
				if (text.kind == 'known') ~= (runs[key].knownissue == true) then
					error(`{where}: "{key}": kind "known" must match the case's known issue`)
				end
				if (text.kind == 'misuse') ~= (text.fix ~= nil) then
					error(`{where}: "{key}": a misuse needs a fix case, and only a misuse has one`)
				end
				runs[key].limit = { kind = text.kind, why = text.why, todo = text.todo, fix = text.fix }
			end
		end
	end

	-- every misuse points to a written fix case, and every fix case is pointed to
	local pointed = {}
	for key, run in runs do
		local fix = run.limit and run.limit.fix
		if not fix then continue end
		local target = runs[fix]
		if not target or not target.limit or target.limit.kind ~= 'fix' then
			error(`tests/lute/limitations/{fnname}.luau: "{key}" points to fix "{fix}", which is not a fix case`)
		end
		pointed[fix] = true
	end
	for key, run in runs do
		if run.limit and run.limit.kind == 'fix' and not pointed[key] then
			error(`tests/lute/limitations/{fnname}.luau: fix case "{key}" is not the fix of any misuse`)
		end
	end

	local missing = {}
	for key, run in runs do
		if run.group ~= 'more' and not run.description then
			table.insert(missing, if key == '' then '(no conditions)' else key)
		end
	end
	table.sort(missing)
	if #missing > 0 then
		error(
			`tests/lute/intro|limitations/{fnname}.luau: {fnname} needs a description for: {table.concat(missing, ' | ')}`
		)
	end

	-- a more case whose extra condition makes no difference reads like the case it equals
	for key, run in runs do
		if run.description or not run.irrelevant then continue end
		local drop = {}
		for _, id in run.irrelevant do
			drop[id] = true
		end
		local rest = {}
		for _, id in (if key == '' then {} else key:split ',') do
			if not drop[id] then table.insert(rest, id) end
		end
		local same = runs[table.concat(rest, ',')]
		if same and same.description then
			run.description = same.description
			run.sameas = table.concat(rest, ',')
		end
	end
end

return {
	attachdescriptions = attachdescriptions,
}
