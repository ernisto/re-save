local operation = require './operation'
local schema = require './schema'
local storage = require './storage'
local tx = require './tx'

-- defs
local stores = {}

export type store<T = any> = {
	ds: DataStore,
	schema: schema.schema<T>,
	tracking: { [string]: any },
}
export type session<T = any> = {
	store: store<T>,
	key: string,

	pendingupdates: { operation.operation<T> },
	syncweight: number,
	base: T,
	data: T,
}

-- functions
local function store<T>(name: string, opts: { schema: schema.schema<T> }): store<T>
	assert(stores[name] == nil, `a data store already was registered for id '{name}'`)

	local store = { ds = storage.store(name), schema = opts.schema, tracking = {} }
	stores[name] = store

	return store
end
local function delete<T>(store: store<T>, key: string): string?
	local err, old = storage.awaitremove(store.ds, key)
	if err then return err end

	local pendingtx = if type(old) == 'table' and type(old.pendingtx) == 'table' then old.pendingtx else nil
	if pendingtx then task.spawn(tx.awaitadopt, pendingtx.id, { `{store.ds.Name}:{key}` }) end

	return nil
end

local function identify<T>(store: store<T>, key: string): session<T>
	local default = store.schema.default
	return store.tracking[key] or { store = store, key = key, pendingupdates = {}, base = default, data = default }
end
local function maybetracked<T>(store: store<T>, key: string): session<T>?
	return store.tracking[key]
end
local function isloaded<T>(session: session<T>): boolean
	return session.data ~= session.store.schema.default
end
local function istracked<T>(session: session<T>): boolean
	return session.store.tracking[session.key] == session
end

-- module
return table.freeze {
	stores = stores,
	store = store,
	delete = delete,

	maybetracked = maybetracked,
	istracked = istracked,
	isloaded = isloaded,
	identify = identify,
}
