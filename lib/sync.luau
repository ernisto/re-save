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
	local err, value = storage.awaitget(s.store.ds, s.key)
	if err then return err, nil end

	local ok, result = pcall(record.working, s.store.schema, value)
	if not ok then return `[fetchcloud] {result}`, nil end

	return nil, result
end

local function reconcilecloud<T>(
	s: session<T>,
	job: nil | (record<T>) -> (),
	txupdate: nil | (record<T>) -> ()
): (string?, string?, record<T>?, string?)
	local successedrebases = 0
	local droperr
	local upstream

	local innererr
	local dserr = storage.awaitupdate(s.store.ds, s.key, function(value: unknown): record<T>?
		if value == nil and job == nil and #s.pendingupdates == 0 then return nil end

		upstream = record.working(s.store.schema, value)
		if txupdate then txupdate(upstream) end

		local lockedtx = upstream.pendingtx
		if lockedtx then lockedtx.newdata = operation.rebase(s.pendingupdates, lockedtx.newdata) end
		upstream.data, successedrebases, droperr = operation.rebase(s.pendingupdates, upstream.data)

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

	-- updates queued during the yield stay pending; a failed write keeps all of them
	if upstream and not dserr then
		s.pendingupdates = table.move(s.pendingupdates, successedrebases + 1, #s.pendingupdates, 1, {})
		s.base = utils.deepfreeze(upstream.data)
		s.data = utils.deepfreeze((operation.rebase(s.pendingupdates, s.base)))
	end

	return readerr, writeerr, upstream, if dserr then nil else droperr
end

-- resolves a stale tx lock; never reruns the caller's job, it was already applied to both branches
local function handletxlock<T>(s: session<T>, curtx: record.txlock<T>): (string?, record<T>?)
	local txerr, txdata = tx.awaitfetch(curtx.id)
	if txerr then return txerr, nil end

	if txdata and txdata.state == 'pending' and os.time() < txdata.committimeout then return nil, nil end

	local commited = txdata ~= nil and txdata.state == 'commited'
	local txupdate = record.txsolver(s.store.schema, curtx.id, commited)

	local readerr, writeerr, upstream = reconcilecloud(s, nil, txupdate)
	if readerr or writeerr then return readerr or writeerr, upstream end

	local newtxerr = tx.awaitadopt(curtx.id, { `{s.store.ds.Name}:{s.key}` })
	return newtxerr, upstream
end

-- 3rd return: why pending updates were saved without some of them (they failed on the cloud data)
local function reconcilecloudandtx<T>(s: session<T>, job: nil | (record<T>) -> ()): (string?, record<T>?, string?)
	local readerr, writeerr, upstream, droperr

	if job == nil and #s.pendingupdates == 0 then
		readerr, upstream = fetchcloud(s)
		if upstream == nil then return readerr, nil end

		s.base = utils.deepfreeze(upstream.data)
		s.data = s.base
	else
		readerr, writeerr, upstream, droperr = reconcilecloud(s, job)
	end

	if upstream == nil then return readerr, nil end

	local curtx = upstream.pendingtx
	if curtx then
		-- in background: a stuck tx must not fail or delay the caller
		task.spawn(function()
			local txerr = handletxlock(s, curtx)
			if txerr then warn(`[handletxlock] fail to resolve tx '{curtx.id}' for '{s.key}'\n{txerr}`) end
		end)
	end

	return writeerr, upstream, droperr
end

-- module
return table.freeze {
	fetchcloud = fetchcloud,
	reconcilecloud = reconcilecloud,
	reconcilecloudandtx = reconcilecloudandtx,
}
