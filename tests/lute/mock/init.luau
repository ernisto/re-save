-- The Roblox mock: lib/ loaded in a fake server environment, and handles on its
-- fake DataStores (`stores[id]`, plus `stores.tx` for transactions).
local loader = require '@self/loader'
local services = require '@self/services'

return table.freeze {
	require = loader.require,
	stores = services.stores,
	warnings = loader.warnings,

	close = loader.close,
	closed = loader.isclosed,
	reopen = loader.reopen,

	setbudget = services.setbudget,
	guidpeek = services.guidpeek,
	reset = services.resetservices,
}
