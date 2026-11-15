-- seeds: top-level cloud(...) / txcloud[...] writes in the first `upto` lines, made before
-- the documented function runs; the "DataStore before" panel already shows them, so the
-- shown code drops them. The run glues them onto the next statement's line, keeping line numbers.
local query = require '@std/syntax/query'
local syntax = require '@std/syntax'

local function isglobal(expr, name: string): boolean
	return expr.tag == 'global' and expr.name.text == name
end

-- the name a target hangs off: `cloud(players).p1` -> cloud, `txcloud['tx-a']` -> txcloud
local function root(expr)
	while expr.tag == 'index' or expr.tag == 'indexname' or expr.tag == 'call' do
		expr = if expr.tag == 'call' then expr.func else expr.expression
	end
	return expr
end

local function isseed(stat): boolean
	if stat.tag ~= 'assign' then return false end

	local target = root(stat.variables[1].node)
	return isglobal(target, 'cloud') or isglobal(target, 'txcloud')
end

local function calls(stat, fnname: string): boolean
	local found = query.findAllFromRoot(stat, function(n)
		local hit = n.kind == 'expr' and n.tag == 'indexname' and n.index.text == fnname
		return if hit and isglobal(n.expression, 'resave') then n else nil
	end)
	return #found.nodes > 0
end

-- the statement's lines joined into one, each cut where its comment starts
local function oneline(stat, lines: { string }): string
	local tokens = query.findAllFromRoot(stat, function(n)
		return if n.kind == 'token' then n else nil
	end)

	local cuts = {} -- [line] = column its comment starts at
	for _, token in tokens.nodes do
		for _, trivia in token.trailingTrivia do
			if trivia.tag == 'comment' then cuts[trivia.location.beginLine] = trivia.location.beginColumn end
		end
	end

	local out = {}
	for i = stat.location.beginLine, stat.location.endLine do
		local line = if cuts[i] then lines[i]:sub(1, cuts[i] - 1) else lines[i]
		table.insert(out, (line:gsub('%s+$', '')))
	end
	return table.concat(out, ' ')
end

local function hideseeds(code: string, upto: number, fnname: string): (string, string)
	local lines = code:split '\n'
	local hidden, glued = {}, {}
	local seeds = {}
	local called = false

	for _, stat in syntax.parse(code).root.statements do
		local first, last = stat.location.beginLine, stat.location.endLine

		if first <= upto and not called and isseed(stat) then
			table.insert(seeds, oneline(stat, lines))
			for i = first, last do
				hidden[i] = true
			end
		else
			called = called or calls(stat, fnname)
			if #seeds > 0 then
				glued[first] = table.concat(seeds, '; ')
				table.clear(seeds)
			end
		end
	end
	assert(#seeds == 0, 'snippet ends in a DataStore seed')

	local shown, ran = {}, {}
	for i, line in lines do
		if hidden[i] then continue end
		table.insert(shown, line)
		table.insert(ran, if glued[i] then `{glued[i]}; {line}` else line)
	end
	return table.concat(shown, '\n'), table.concat(ran, '\n')
end

return {
	hideseeds = hideseeds,
}
