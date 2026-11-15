-- Snippet helpers that reach into the mock DataStores: read them raw, make them
-- fail, heal them. `st` is a store, or 'tx' for the transaction store.
local mock = require '../../../mock'

local function rawds(st: any)
	if st == 'tx' then return mock.stores.tx end
	return st.ds
end

local function cloud(st)
	return rawds(st).data
end

local function fail(st, method: 'get' | 'update' | 'remove')
	rawds(st)[`_fail{method}`] = true
end

-- the DataStore works again: clears fail flags and any failwrite still waiting
local function heal(st)
	local ds = rawds(st)
	ds._failget, ds._failupdate, ds._failremove = nil, nil, nil

	if ds._realupdate then
		ds.UpdateAsync = ds._realupdate
		ds._realupdate = nil
	end
end

-- nth UpdateAsync from now runs the callback, then fails to write
local function makefailwrite(ctx)
	return function(st, nth: number?)
		local ds = rawds(st)
		local real = ds.UpdateAsync
		local count = 0
		ds._realupdate = ds._realupdate or real

		-- the tx store is shared by every run: undo this even if the nth write never comes
		table.insert(ctx.restores, function()
			ds.UpdateAsync = real
			ds._realupdate = nil
		end)

		ds.UpdateAsync = function(self, key, update)
			count += 1
			if count ~= (nth or 1) then return real(self, key, update) end

			ds.UpdateAsync = real
			ds._realupdate = nil
			return real(self, key, function(value)
				update(value)
				error 'write failed'
			end)
		end
	end
end

return {
	cloud = cloud,
	fail = fail,
	heal = heal,
	makefailwrite = makefailwrite,
}
