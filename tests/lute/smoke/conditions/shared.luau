-- Pieces several condition trees share: stores, saved records, trade locks,
-- DataStore failures and follow-up events.
local nodes = require './node'
type node = nodes.node

local STORE = "local players = resave.store('players', { schema = resave.schema { coins = 0 } })"

-- shop examples (queueupdate, saveupdate, savebatch): players start with 100 coins and no items
local SHOP_STORE = "local players = resave.store('players', { schema = resave.schema { coins = 100, items = {} } })"

local RECORD = [[
cloud(players).p1 = {
	data = { coins = {{coins}} },
	version = 0,{{pendingtx}}
}]]

local function pendingtx(id: string): string
	return `\n\tpendingtx = \{ id = '{id}', newdata = \{ coins = 9 }, version = 0, cooltimestamp = 0 },`
end

local function txnodes(groupname: string): { node }
	return {
		{
			id = 'tx_committed',
			group = groupname,
			label = 'locked by a tx that was committed',
			setup = "txcloud['tx-a'] = { state = 'commited', adopts = {}, committimeout = now + 60 }",
			slots = { pendingtx = pendingtx 'tx-a' },
			settle = true,
		},
		{
			id = 'tx_deleted',
			group = groupname,
			label = 'locked by a tx that no longer exists (aborted)',
			slots = { pendingtx = pendingtx 'tx-a' },
			settle = true,
		},
		{
			id = 'tx_live',
			group = groupname,
			label = 'locked by a pending tx, not expired',
			setup = "txcloud['tx-a'] = { state = 'pending', adopts = {}, committimeout = now + 60 }",
			slots = { pendingtx = pendingtx 'tx-a' },
			settle = true,
		},
		{
			id = 'tx_expired',
			group = groupname,
			label = 'locked by a pending tx past its commit timeout',
			setup = "txcloud['tx-a'] = { state = 'pending', adopts = {}, committimeout = now - 1 }",
			slots = { pendingtx = pendingtx 'tx-a' },
			settle = true,
		},
	}
end

local UPDATE_FAILS: node = {
	id = 'update_fails',
	group = 'fail',
	label = 'UpdateAsync fails before running the callback',
	arm = "fail(players, 'update')",
}
local WRITE_FAILS: node = {
	id = 'write_fails',
	group = 'fail',
	label = 'UpdateAsync runs the callback, then fails to write',
	arm = 'failwrite(players)',
}

-- one list of nodes after another
local function join(first: { node }, rest: { node }): { node }
	local out = table.clone(first)
	table.move(rest, 1, #rest, #out + 1, out)
	return out
end

-- a follow-up event after the call: pick at most one per function.
local function andthen(id: string, label: string, event: string, post: string, extra: { [string]: any }?): node
	local node: any = {
		id = id,
		group = 'then',
		label = `then {label}`,
		post = `checkpoint 'before {event}'\n{post}`,
	}
	if extra then
		for key, value in extra do
			node[key] = value
		end
	end
	return node
end

return {
	STORE = STORE,
	SHOP_STORE = SHOP_STORE,
	RECORD = RECORD,
	UPDATE_FAILS = UPDATE_FAILS,
	WRITE_FAILS = WRITE_FAILS,
	pendingtx = pendingtx,
	txnodes = txnodes,
	join = join,
	andthen = andthen,
}
