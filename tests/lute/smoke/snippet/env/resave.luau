-- The library as a snippet sees it: store names get a per-run suffix, sessions are
-- recorded for the snapshots, and the documented function's first call takes the
-- "DataStore before" panel.
local snapshot = require '../snapshot'

local function wrapresave(ctx, realresave)
	local resave = table.clone(realresave)

	resave.store = function(name, opts)
		local st = realresave.store(`{name}#{ctx.id}`, opts)
		ctx.labels[st] = name
		table.insert(ctx.stores, st)
		return st
	end

	resave.track = function(...)
		local err, s = realresave.track(...)
		if s then table.insert(ctx.sessions, s) end
		return err, s
	end

	resave.maybetracked = function(...)
		local s = realresave.maybetracked(...)
		if s then table.insert(ctx.sessions, s) end
		return s
	end

	local documented = resave[ctx.fnname]
	resave[ctx.fnname] = function(...)
		if not ctx.input then
			local cloud, tx = snapshot.storesnapshot(ctx)
			ctx.input = { cloud = cloud, tx = tx }
		end
		return documented(...)
	end

	return resave
end

return {
	wrapresave = wrapresave,
}
