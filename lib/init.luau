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

local function any_job_to_resolve_tx() end

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

	local err = sync.reconcilecloudandtx(s, any_job_to_resolve_tx)
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
		local pusherr, cloud = sync.reconcilecloudandtx(loaded)
		if cloud then return nil, cloud.data end

		return pusherr, nil
	end
	local cacheddata = loaded and loaded.data

	local err, value = storage.awaitget(st.ds, key)
	if err then return err, cacheddata end
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
	return (sync.reconcilecloudandtx(s, function(record)
		update(record.data)
	end))
end

-- transaction
local function locktx<T>(s: session<T>, txid: string, update: op<T>): (string?, record<T>?)
	return sync.reconcilecloudandtx(s, function(record: record<T>)
		local err, data = operation.cloneapply(record.data, update)
		assert(data, err)

		record.pendingtx = { id = txid, newdata = data, version = record.version, cooltimestamp = 0 }
	end)
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
			local err = sync.reconcilecloud(s, nil, txupdate)

			if err == nil then table.insert(doneadopts, s) end
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

	local function queueupdate<T>(st: store<T>, key: string, update: (T) -> ())
		local s = session.identify(st, key)
		assert(updates[s] == nil, `already defined a tx for {key}`)

		updates[s] = update
		table.insert(sessionids, `{s.store.ds.Name}:{s.key}`)
		table.insert(ss, s)
	end
	builder(queueupdate)

	local err, txid = tx.awaitcreate(sessionids)
	if err or not txid then return err end

	local lockerr, lockeds = batchlocktx(ss, txid, updates)
	local commited = lockerr == nil

	local commiterr, aborterr, adopterr
	if commited then
		commiterr = tx.awaitcommit(txid)
		commited = commiterr == nil
	else
		aborterr = tx.awaitabort(txid)
	end

	local adopters = batchadopt(lockeds, txid, commited)
	local adopterids = {}

	for i, adopter in adopters do
		adopterids[i] = `{adopter.store.ds.Name}:{adopter.key}`
	end

	if commited then adopterr = tx.awaitadopt(txid, adopterids) end
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
		sync.reconcilecloudandtx(s)

		task.wait(1 / storage.budgetwindow)
	end
end)
game:BindToClose(function()
	task.cancel(livesync)

	for name, st in session.stores do
		for key, s in st.tracking do
			free(s)
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
