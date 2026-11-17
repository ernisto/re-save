-- What one snippet run records. Library values (stores, sessions) stay `any`: the run only
-- reads their fields to print them.

-- a DataStore row (`store` unset for the tx store)
export type row = { store: string?, key: string, value: string }

export type sessionrow = {
	key: string,
	store: string,
	tracked: boolean,
	frozen: boolean,
	loaded: boolean,
	oplog: { string },
	base: string,
	data: string,
}

export type checkpoint = {
	label: string,
	cloud: { row },
	tx: { row },
	sessions: { sessionrow },
	warnings: { string },
}

-- a snippet variable's recorded value, taken after the statement on lines from..to
export type var = { name: string, from: number, to: number, declares: boolean, value: string }

export type ctx = {
	id: string,
	fnname: string,
	now: number,
	stores: { any },
	labels: { [any]: string },
	sessions: { any },
	checkpoints: { checkpoint },
	vars: { var },
	lastvalue: { [string]: string },
	restores: { () -> () },
	warnseen: number,
	clock: number,
	input: { cloud: { row }, tx: { row } }?, -- the DataStore before the documented call
	fnlabel: (fn: any) -> string,
}

-- what a run ended with (see run in init.luau)
export type result = {
	thrown: string?,
	returned: { { text: string, isstring: boolean } },
	checkpoints: { checkpoint },
	vars: { var },
	input: { cloud: { row }, tx: { row } },
}

-- types only
return nil
