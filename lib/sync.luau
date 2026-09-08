local operation = require './operation'
local storage = require './storage'
local syncloop = require './syncloop'
local tx = require './tx'
local utils = require './utils'

local session = require './session'
type session<T> = session.session<T>

local record = require './record'
type record<T> = record.record<T>

-- functions
local function fetchcloud<T>(s: session<T>): (string?, record<T>?)
	return storage.awaitget(s.store.ds, s.key)
end

local function reconcilecloud<T>(
	s: session<T>,
	job: nil | (record<T>) -> (),
	txupdate: nil | (record<T>) -> ()
): (string?, string?, record<T>?)
	local successedrebases = 0
	local upstream

	local innererr
	local dserr = storage.awaitupdate(s.store.ds, s.key, function(value: unknown): record<T>?
		if value == nil and job == nil and #s.pendingupdates == 0 then return nil end

		upstream = record.working(s.store.schema, value)
		if txupdate then txupdate(upstream) end

		if upstream.pendingtx ~= nil then
			innererr = '[reconcilecloud] pending tx'
			return nil
		end
		upstream.data, successedrebases = operation.rebase(s.pendingupdates, upstream.data)

		if not job then return upstream end
		local newupstream = utils.deepclone(upstream)

		local ok, joberr = xpcall(job :: any, debug.traceback :: any, newupstream)
		if ok then
			upstream = newupstream
			return newupstream
		else
			innererr = joberr
			return upstream
		end
	end)
	local readerr = if dserr and upstream == nil then dserr else nil
	if readerr then return readerr, nil end

	local writeerr = if upstream == nil then nil else dserr or innererr
	if not writeerr then syncloop.dequeue(s) end

	if upstream then
		table.move(s.pendingupdates, successedrebases + 1, #s.pendingupdates + 1, 1)
		s.base = utils.deepfreeze(upstream.data)
		s.data = utils.deepfreeze((operation.rebase(s.pendingupdates, s.base)))
	end

	return readerr, writeerr, upstream
end

local function handletxlock<T>(s: session<T>, curtx: record.txlock<T>, inheritjob): (string?, record<T>?)
	local txerr, txdata = tx.awaitfetch(curtx.id)
	if txerr then return txerr, nil end

	if txdata and txdata.state == 'pending' and os.time() < txdata.committimeout then
		return '[handletxlock] pending tx', nil
	end

	local commited = txdata ~= nil and txdata.state == 'commited'
	local txupdate = record.txsolver(s.store.schema, curtx.id, commited)

	local readerr, writeerr, upstream = reconcilecloud(s, inheritjob, txupdate)
	if readerr or writeerr then return readerr or writeerr, upstream end

	local newtxerr = tx.awaitadopt(curtx.id, { `{s.store.ds.Name}:{s.key}` })
	return newtxerr, upstream
end

local function reconcilecloudandtx<T>(s: session<T>, job: nil | (record<T>) -> ()): (string?, record<T>?)
	if job == nil and #s.pendingupdates == 0 then
		local readerr, upstream = fetchcloud(s)
		if upstream == nil then return readerr, nil end

		s.base = utils.deepfreeze(upstream.data)
		s.data = s.base

		return readerr, upstream
	end

	local readerr, writeerr, upstream = reconcilecloud(s, job)
	if upstream == nil then return readerr, nil end

	local curtx = upstream.pendingtx
	if writeerr and curtx and os.time() > curtx.cooltimestamp then -- todo: assign cooltimestamp
		local txerr, upstream2 = handletxlock(s, curtx, job)
		return txerr and `{writeerr}\n{txerr}`, upstream2 or upstream
	end

	return writeerr, upstream
end

-- module
return table.freeze {
	reconcilecloud = reconcilecloud,
	reconcilecloudandtx = reconcilecloudandtx,
}
