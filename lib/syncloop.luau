-- todo: balance many servers for a single record
-- maybe memstore to store trackers, updateasync to update schedule
-- keep balance inside 4mb/min throughput limit

local session = require './session'

local queue = {}

-- functions
local function dequeue(s: session.session)
	local index = table.find(queue, s)
	if index then table.remove(queue, index) end
end

local function queueall()
	for _, st in session.stores do
		for _, s in st.tracking do
			if not session.isloaded(s) then continue end
			if #s.pendingupdates == 0 then continue end
			table.insert(queue, s)
		end
	end
end

local function next()
	if #queue == 0 then queueall() end
	return table.remove(queue)
end

-- module
return table.freeze {
	queueall = queueall,
	dequeue = dequeue,
	next = next,
}
