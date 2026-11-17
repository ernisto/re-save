local json = require './json'
local types = require './types'

local tojson = json.tojson

-- what a run ended with: returns or throw, final DataStore, tx store and sessions,
-- warnings. Errors keep their message only: tracebacks and line numbers move with
-- every edit of the library, the mock or the snippet. Used to spot conditions that
-- make no difference, and as the smoke tests' snapshot.
local function brief(text: string): string
	return ((text:match '^[^\n]*' :: string):gsub(':%d+', ''):gsub('line %d+', 'line'))
end

local function resultsignature(run: types.result): string
	local last = run.checkpoints[#run.checkpoints]
	local warnings = {}
	for _, cp in run.checkpoints do
		for _, w in cp.warnings do
			-- retries repeat a warning as often as the clock allows: count it once
			local text = brief(w)
			if warnings[#warnings] ~= text then table.insert(warnings, text) end
		end
	end

	local returned = {}
	for _, r in run.returned do
		table.insert(returned, if r.isstring then brief(r.text) else r.text)
	end

	local text = tojson {
		thrown = brief(run.thrown or ''),
		returned = returned,
		cloud = last.cloud,
		tx = last.tx,
		sessions = last.sessions,
		warnings = warnings,
	}
	return (text:gsub('snippet:%d+', 'snippet'):gsub('line %d+:', 'line:'))
end

return {
	signature = resultsignature,
}
