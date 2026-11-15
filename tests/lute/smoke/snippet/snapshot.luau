-- What the DataStore, the tx store and the sessions hold at a checkpoint.
local mock = require '../../mock'
local paths = require './paths'
local printer = require './printer'

local cleanpaths = paths.cleanpaths
local printvalue = printer.printvalue

local function snapshotsession(s, ctx)
	local oplog = {}
	for i, op in s.pendingupdates do
		oplog[i] = ctx.fnlabel(op)
	end

	return {
		key = s.key,
		store = ctx.labels[s.store] or '?',
		tracked = s.store.tracking[s.key] == s,
		frozen = table.isfrozen(s),
		loaded = s.data ~= s.store.schema.default,
		oplog = oplog,
		base = printvalue(s.base, ctx),
		data = printvalue(s.data, ctx),
	}
end

-- what the DataStore and the tx store hold right now
local function storesnapshot(ctx)
	local cloud = {}
	for _, st in ctx.stores do
		local keys = {}
		for key in st.ds.data do
			table.insert(keys, key)
		end
		table.sort(keys)

		for _, key in keys do
			table.insert(cloud, { store = ctx.labels[st], key = key, value = printvalue(st.ds.data[key], ctx) })
		end
	end

	local tx = {}
	local txkeys = {}
	for key in mock.stores.tx.data do
		table.insert(txkeys, key)
	end
	table.sort(txkeys)
	for _, key in txkeys do
		table.insert(tx, { key = key, value = printvalue(mock.stores.tx.data[key], ctx) })
	end

	return cloud, tx
end

local function snapshot(label: string, ctx)
	local cloud, tx = storesnapshot(ctx)

	local seen = {}
	local sessions = {}
	local function add(s)
		if seen[s] then return end
		seen[s] = true
		table.insert(sessions, snapshotsession(s, ctx))
	end
	for _, st in ctx.stores do
		for _, s in st.tracking do
			add(s)
		end
	end
	for _, s in ctx.sessions do
		add(s)
	end

	local warnings = {}
	for i = ctx.warnseen + 1, #mock.warnings do
		table.insert(warnings, cleanpaths(mock.warnings[i]))
	end
	ctx.warnseen = #mock.warnings

	table.insert(ctx.checkpoints, {
		label = label,
		cloud = cloud,
		tx = tx,
		sessions = sessions,
		warnings = warnings,
	})
end

return {
	storesnapshot = storesnapshot,
	snapshot = snapshot,
}
