-- Server shutdown: BindToClose waits for a running save and warns when one fails.
local mock = require '../../mock'
local task = require '@lute/task'
local resave: typeof(require '../../../../lib') = mock.require '@self/init'

local helpers = require '../helpers'
local suite = helpers.suite
local unique = helpers.unique

local function haswarning(needle: string): boolean
	for _, warning in mock.warnings do
		if string.find(warning, needle, 1, true) then return true end
	end
	return false
end

local function add(amount: number)
	return function(d: any)
		d.coins += amount
	end
end

suite('sync close', function(s)
	s:case('close_waits_for_running_sync', function(t)
		local name = unique()
		local key = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, session = resave.track(st, key)
		assert(session, err)

		-- the next save yields inside the storage lock
		local ds = mock.stores[name]
		local realupdate = ds.UpdateAsync
		local entered = false
		ds.UpdateAsync = function(self, k, fn)
			entered = true
			task.wait(0.2)
			return realupdate(self, k, fn)
		end
		resave.queueupdate(session, add(1))

		local deadline = os.clock() + 3
		while not entered and os.clock() < deadline do
			task.wait()
		end
		local closed = false
		task.spawn(function()
			mock.close()
			closed = true
		end)
		deadline = os.clock() + 3
		while not closed and os.clock() < deadline do
			task.wait()
		end
		ds.UpdateAsync = realupdate

		t.that(entered, 'expected livesync to start a save')
		t.that(closed, 'close hung on the lock of the stopped sync')
		t.eq(ds.data[key].data, { coins = 1 })
	end)

	s:case('close_warns_when_save_fails', function(t)
		local name = unique()
		local key = unique()
		local st = resave.store(name, { schema = resave.schema { coins = 0 } })

		local err, session = resave.track(st, key)
		assert(session, err)

		mock.stores[name]._failupdate = true
		resave.queueupdate(session, add(1))
		mock.close()
		mock.stores[name]._failupdate = nil

		t.that(haswarning(`[bindtoclose] fail to save '{key}'`), 'expected bindtoclose warning')
	end)
end)
