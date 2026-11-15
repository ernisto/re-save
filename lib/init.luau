local schema = require '@self/schema'
local storage = require '@self/storage'
local sync = require '@self/sync'
local syncloop = require '@self/syncloop'
local tx = require '@self/tx'

local operation = require '@self/operation'
type op<T = any> = operation.operation<T>

local record = require '@self/record'
type record<T> = record.record<T>

local session = require '@self/session'
type session<T = any> = session.session<T>
type store<T = any> = session.store<T>

local function anything_just_to_write_default() end

-- api
local function track<T>(st: store<T>, key: string): (string?, session<T>?)
	local cached: session<T> = st.tracking[key]
	if cached then
		while not session.isloaded(cached) and session.istracked(cached) do
			task.wait()
		end
		if session.istracked(cached) then return nil, cached end
	end

	local s = session.identify(st, key)
	st.tracking[key] = s

	local err = sync.reconcilecloudandtx(s, anything_just_to_write_default)
	if err then
		st.tracking[key] = nil
		return err, nil
	end

	return nil, s
end
local function free<T>(s: session<T>): string?
	if not session.istracked(s) then return nil end
	syncloop.dequeue(s)

	if #s.pendingupdates > 0 then
		local err = sync.reconcilecloudandtx(s)
		if err then return err end
	end

	s.store.tracking[s.key] = nil
	table.freeze(s)

	return nil
end
local function view<T>(st: store<T>, key: string): (string?, T?)
	local loaded: session<T> = st.tracking[key]
	if loaded then
		local readerr, cloud = sync.reconcilecloudandtx(loaded)
		if cloud then return nil, cloud.data end

		return readerr, nil
	end

	local err, value = storage.awaitget(st.ds, key)
	if err then return err, nil end
	if value == nil then return nil, nil end

	return nil, record.working(st.schema, value).data
end

local function update<T>(s: session<T>, update: (T) -> ())
	assert(s.store.tracking[s.key] == s, 'you can only update tracked records')

	local err, result = operation.cloneapply(s.data, update :: any)
	assert(result, err)

	table.insert(s.pendingupdates, update :: any)
	s.data = result
end
local function awaitsaveupdate<T>(st: store<T>, key: string, update: (T) -> ()): string?
	local s = session.identify(st, key)
	local err = sync.reconcilecloudandtx(s, function(record)
		-- same checks as queueupdate, on both branches, before anything is written
		local dataerr, data = operation.cloneapply(record.data, update :: any)
		if dataerr then error(dataerr, 0) end

		local tx = record.pendingtx
		if tx then
			local txerr, txdata = operation.cloneapply(tx.newdata, update :: any)
			if txerr then error(`[saveupdate] fails on pending tx branch:\n{txerr}`, 0) end
			tx.newdata = txdata
		end
		record.data = data
	end)
	return err
end

-- transaction
local function locktx<T>(s: session<T>, txid: string, update: op<T>): (string?, record<T>?)
	return sync.reconcilecloudandtx(s, function(record: record<T>)
		if record.pendingtx then error('[withfreetx] pending tx', 0) end

		local err, data = operation.cloneapply(record.data, update)
		assert(data, err)

		record.pendingtx = {
			id = txid,
			newdata = data,
			version = record.version,
			cooltimestamp = os.time() + tx.cooldown,
		}
	end)
end
-- tests every update on the current cloud data before any record is locked
local function batchpretest(updates: { [session]: op }): string?
	local remaining = 0
	local firsterr: string?

	for s, update in updates do
		remaining += 1
		task.spawn(function()
			local err, upstream = sync.fetchcloud(s)
			if upstream then
				local base = operation.rebase(s.pendingupdates, upstream.data)
				err = operation.cloneapply(base, update)
			end
			firsterr = firsterr or err
			remaining -= 1
		end)
	end

	while remaining > 0 do
		task.wait()
	end
	return firsterr
end
local function batchlocktx(sessions: { session }, txid: string, updates: { [session]: op }): (string?, { session })
	local remainingsaves = #sessions
	local lockeds: { session } = {}
	local firsterr: string?

	for s, update in updates do
		task.spawn(function()
			local err = locktx(s, txid, update)
			firsterr = firsterr or err
			remainingsaves -= 1

			if err == nil then table.insert(lockeds, s) end
		end)
	end

	while remainingsaves > 0 do
		task.wait()
	end
	return firsterr, lockeds
end
local function batchadopt(sessions: { session }, txid: string, commited: boolean): { session }
	local remainingsyncs = #sessions
	local doneadopts = {}

	for _, s in sessions do
		task.spawn(function()
			local txupdate = record.txsolver(s.store.schema, txid, commited)
			local readerr, writeerr = sync.reconcilecloud(s, nil, txupdate)

			-- a record that failed to adopt keeps the tx alive, so it resolves on its next load
			if not readerr and not writeerr then table.insert(doneadopts, s) end
			remainingsyncs -= 1
		end)
	end

	while remainingsyncs > 0 do
		task.wait()
	end
	return doneadopts
end
local function awaitsavebatch(builder: (update: <T>(store<T>, key: string, update: (T) -> ()) -> ()) -> ()): string?
	local sessionids = {}
	local ss = {}
	local updates = {}
	local queued = {}

	local function queueupdate<T>(st: store<T>, key: string, update: (T) -> ())
		-- by store and key: untracked keys get a new session per identify
		queued[st] = queued[st] or {}
		assert(not queued[st][key], `already defined a tx for {key}`)
		queued[st][key] = true

		local s = session.identify(st, key)

		updates[s] = update
		table.insert(sessionids, `{s.store.ds.Name}:{s.key}`)
		table.insert(ss, s)
	end
	builder(queueupdate)

	local testerr = batchpretest(updates)
	if testerr then return testerr end

	local err, txid = tx.awaitcreate(sessionids)
	if err or not txid then return err end

	local lockerr, lockeds = batchlocktx(ss, txid, updates)
	local commited = lockerr == nil

	local commiterr = if commited then tx.awaitcommit(txid) else nil
	commited = commited and commiterr == nil

	local aborterr = if not commited then tx.awaitabort(txid) else nil

	local adopters = batchadopt(lockeds, txid, commited)
	local adopterids = {}

	for i, adopter in adopters do
		adopterids[i] = `{adopter.store.ds.Name}:{adopter.key}`
	end

	local adopterr = if commited then tx.awaitadopt(txid, adopterids) else nil
	return lockerr or commiterr or aborterr or adopterr
end

-- routine
local livesync = task.spawn(function()
	while true do
		local s = syncloop.next()
		if not s then
			task.wait()
			continue
		end

		storage.awaitbudget()
		local err = sync.reconcilecloudandtx(s)
		if err then warn(`[livesync] fail to sync '{s.key}'\n{err}`) end

		task.wait(1 / storage.budgetwindow)
	end
end)
game:BindToClose(function()
	task.cancel(livesync)

	for _, st in session.stores do
		for key, s in st.tracking do
			local err = free(s)
			if err then warn(`[bindtoclose] fail to save '{key}'\n{err}`) end
		end
	end
end)

-- module
return table.freeze {
	migrate = schema.migrate,
	schema = schema.schema,

	maybetracked = session.maybetracked,
	istracked = session.istracked,
	delete = session.delete,
	store = session.store,
	track = track,
	free = free,
	view = view,

	saveupdate = awaitsaveupdate,
	savebatch = awaitsavebatch,
	queueupdate = update,
}
