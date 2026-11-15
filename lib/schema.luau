local operation = require './operation'
local utils = require './utils'

-- defs
export type schema<T = any, B = any> = { default: T, migrations: { (B) -> T } }

-- functions
local function schema<T>(default: T): schema<T>
	return { default = default, migrations = {} }
end
local function migrate<B, T>(base: schema<B>, migrate: (B) -> T): schema<T>
	local newmigrations = table.clone(base.migrations)
	table.insert(newmigrations, migrate :: any)

	local testsubject = utils.deepclone(base.default)
	for v, migration in newmigrations do
		local err, newsubject = operation.cloneapply(testsubject, migration :: any)
		assert(newsubject, err)

		testsubject = newsubject
	end

	return table.freeze { default = base.default :: any, migrations = table.freeze(newmigrations :: any) }
end
-- throws if a migration fails: half migrated data must never load or be saved
local function workingdata<T>(workingschema: schema<T>, inputversion: number, input: unknown): T
	local workingversion = #workingschema.migrations
	assert(inputversion <= workingversion, 'outdated base')

	for midversion = inputversion + 1, workingversion do
		local migration = workingschema.migrations[midversion]
		local err, newdata = operation.cloneapply(input, migration :: any)

		if err then
			local path, line = debug.info(migration, 'sl')
			error(`[workingdata] fail to migrate to v{midversion} ({path}:{line})\n{err}`, 0)
		else
			input = newdata
		end
	end

	return input :: any
end

-- export
return table.freeze {
	schema = schema,
	migrate = migrate,
	workingdata = workingdata,
}
