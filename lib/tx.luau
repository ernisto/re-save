local storage = require './storage'
local utils = require './utils'

-- defs
local txstore = storage.store 'tx'
local RESOLVE_COOLDOWN = 10

type tx = { state: txstate, committimeout: number, adopts: { [string]: boolean } }
type txstate = 'pending' | 'aborted' | 'commited'

-- functions
local function awaitcreatetx(ids: { string }): (string?, string?)
	local txid = utils.id()
	local adopts = {}

	for _, id in ids do
		adopts[id] = false
	end

	local err = storage.awaitupdate(txstore, txid, function(existing): tx
		assert(existing == nil, `a transaction with same id '{txid}' already exists`)
		return { state = 'pending', adopts = adopts, committimeout = os.time() + 5 * 60 }
	end)
	if err then return err, nil end
	return nil, txid
end

local function awaitfetchtx(txid: string): (string?, tx?)
	return storage.awaitget<<tx>>(txstore, txid)
end

local function awaitdeletetx(txid: string): (string?, tx?)
	return storage.awaitremove<<tx>>(txstore, txid)
end

local function awaitcommittx(txid: string): string?
	local writeerr
	local readerr = storage.awaitupdate<<tx>>(txstore, txid, function(tx)
		if not tx or tx.state == 'aborted' then
			writeerr = 'already aborted'
			return nil
		end
		tx.state = 'commited'
		return tx
	end)

	return readerr or writeerr
end

local function awaitaborttx(txid: string): string?
	return awaitdeletetx(txid)
end

local function awaitadopttx(txid: string, adopterids: { string }): string?
	local err, tx = storage.awaitupdate<<tx>>(txstore, txid, function(tx)
		if not tx then return nil end

		for _, id in adopterids do
			tx.adopts[id] = true
		end

		return tx
	end)
	if err then return err, nil end
	if tx == nil then return nil end

	for _, adopted in tx.adopts do
		if not adopted then return nil end
	end

	task.spawn(awaitdeletetx, txid)
	return nil
end

-- module
return table.freeze {
	awaitcreate = awaitcreatetx,
	awaitdelete = awaitdeletetx,
	awaitfetch = awaitfetchtx,

	awaitcommit = awaitcommittx,
	awaitabort = awaitaborttx,
	awaitadopt = awaitadopttx,

	cooldown = RESOLVE_COOLDOWN,
}
