local deepdiff = require './deepdiff'
local utils = require './utils'

-- defs
export type operation<T = any> = (T) -> T

-- functions
local function cloneapply<T>(base: T, op: operation<T>): (string?, T?)
	local mutbase = utils.deepclone(base)
	local err, outdata = utils.noyield(op, mutbase)

	if err then return `[cloneapply] execution failed:\n{err}`, nil end
	local result = outdata or mutbase

	local ok, json = pcall(utils.json, mutbase)
	if not ok then return `[cloneapply] result not savable as json:\n{json}`, nil end

	if utf8.len(json) ~= string.len(json) then return '[cloneapply] result contains non-ascii characters', nil end

	local mutdata2 = utils.deepclone(base)
	local err2, outdata2 = utils.noyield(op, mutdata2)

	if err2 then return `[cloneapply] 2nd execution failed:\n{err2}`, nil end
	local result2 = outdata2 or mutdata2

	local diff = deepdiff.from(result, result2)
	if diff then return `[cloneapply] 2nd execution produced a different result from 1st result:\n{diff}` end

	return nil, result
end
local function rebase<T>(oplog: { operation<T> }, base: T): (T, number)
	local successed = 0
	for i, op in oplog do
		local err, result = cloneapply(base, op)

		if err then
			local path, line = debug.info(op, 'sl')
			warn(`[rebase] fail to apply update #{i} ({path}:{line})\n{err}`)
		elseif result then
			base = result
		else
			break
		end

		successed += 1
	end
	return base, successed
end

-- module
return table.freeze {
	cloneapply = cloneapply,
	rebase = rebase,
}
