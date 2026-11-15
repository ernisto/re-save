-- Types as token lists the page can colour and link:
--   { t = text, k = 'punct' | 'type' | 'generic' | 'prop' | 'lit' | 'space', href = url? }
local query = require '@std/syntax/query'

local resolvemod = require './resolve'

local FUNCTION_DOCS, resolve = resolvemod.FUNCTION_DOCS, resolvemod.resolve

-- every node under `node` that pick returns non-nil for, in source order
local function findall(node, pick)
	return query.findAllFromRoot(node, pick).nodes
end

local function generican(names, list)
	for _, pair in list or {} do
		names[pair.node.name.text] = true
	end
	return names
end

-- reference name tokens (and their module prefixes) inside node, so the walker can tag them
local function collectrefs(node)
	local refs = {}

	for _, ref in
		findall(node, function(n)
			return if n.kind == 'type' and n.tag == 'reference' then n else nil
		end)
	do
		refs[ref.name] = ref
		if ref.prefix then refs[ref.prefix] = ref end
	end
	return refs
end

-- generic function types like `<T>(store<T>) -> ()` bring their own generics
local function addnestedgenerics(node, names)
	for _, fn in
		findall(node, function(n)
			return if n.kind == 'type' and n.tag == 'function' then n else nil
		end)
	do
		generican(names, fn.generics)
	end
end

-- token list for any node, spacing rebuilt from source positions
local function totokens(mod, node, generics, libdir: string, multiline: boolean?)
	local tokens = findall(node, function(n)
		return if n.kind == 'token' then n else nil
	end)
	local refs = collectrefs(node)
	generics = table.clone(generics)
	addnestedgenerics(node, generics)

	local out = {}
	local last
	local baseindent

	for _, token in tokens do
		local loc = token.location

		if last then
			if loc.beginLine ~= last.location.endLine then
				if multiline then
					local line = mod.lines[loc.beginLine] or ''
					local indent = line:match '^%s*'
					baseindent = baseindent or ''
					table.insert(out, { t = '\n' .. indent:sub(#baseindent + 1), k = 'space' })
				else
					table.insert(out, { t = ' ', k = 'space' })
				end
			elseif loc.beginColumn > last.location.endColumn then
				table.insert(out, { t = ' ', k = 'space' })
			end
		else
			baseindent = (mod.lines[loc.beginLine] or ''):match '^%s*'
		end

		local text = token.text
		local ref = refs[token]
		local entry

		if ref and ref.prefix == token then
			entry = { t = text, k = 'prefix' }
		elseif ref then
			local target = resolve(mod, ref, generics, libdir)
			entry = { t = text, k = target.kind, href = target.href }
		elseif text == '->' then
			entry = { t = text, k = 'punct', href = FUNCTION_DOCS }
		elseif text:match '^[%a_][%w_]*$' then
			entry = { t = text, k = 'prop' }
		elseif text:match '^["\']' then
			entry = { t = text, k = 'lit' }
		else
			entry = { t = text, k = 'punct' }
		end

		table.insert(out, entry)
		last = token
	end

	return out
end

return {
	generican = generican,
	totokens = totokens,
}
