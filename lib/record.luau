local schema = require './schema'
local utils = require './utils'

-- defs
export type record<T> = {
	data: T,
	version: number,
	pendingtx: txlock<T>?,
}
export type txlock<T> = {
	id: string,
	cooltimestamp: number, -- time since you can try fetchtx to solve

	newdata: T,
	version: number,
}

-- functions
local function isrecord<T>(value: any): record<T>?
	return if type(value) == 'table'
			and type(value.version) == 'number'
			and type(value.data) == 'table'
		then value
		else nil
end
local function workingrecord<T>(workingschema: schema.schema<T>, value: unknown): record<T>
	-- never overwrite a value we can't read: someone else's data or a broken write
	if value ~= nil and not isrecord(value) then error('[record] stored value is not a record', 0) end
	local record: record<T> = isrecord(value) or { data = utils.deepclone(workingschema.default), version = 0 }
	record.data, record.version = schema.workingdata(workingschema, record.version, record.data)

	local tx = record.pendingtx
	if tx then
		tx.newdata, tx.version = schema.workingdata(workingschema, tx.version, tx.newdata)
	end

	return record
end

local function txsolver<T>(workingschema: schema.schema<T>, txid: string, commited: boolean): (record<T>) -> ()
	return function(record: record<T>)
		if not record.pendingtx then return end

		local tx = record.pendingtx
		if tx.id ~= txid then return end

		record.pendingtx = nil
		if commited then
			record.data, record.version = schema.workingdata(workingschema, tx.version, tx.newdata)
		end
	end
end

-- module
return table.freeze {
	isrecord = isrecord,
	working = workingrecord,
	txsolver = txsolver,
}
