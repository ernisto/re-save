local HttpService = game and game:GetService 'HttpService'

-- functions
local function deepclone<T>(t: T): T
	local out = table.clone(t :: any)
	for k, v in out do
		if type(v) == 'table' then out[k] = deepclone(v) end
	end
	return out :: any
end
local function deepfreeze<T>(t: T): T
	if table.isfrozen(t :: any) then return t end

	local out = t :: any
	for k, v in out do
		if type(v) == 'table' then out[k] = deepfreeze(v) end
	end
	return table.freeze(out) :: any
end
local function noyield<R, T...>(fn: (T...) -> R, ...: T...): (string?, R?)
	local t = coroutine.create(fn)

	local ok, result = coroutine.resume(t, ...)
	if not ok then return debug.traceback(t, result), nil end

	if coroutine.status(t) == 'suspended' then return debug.traceback(t, 'attempt to yield in a update'), nil end
	return nil, result :: any
end

local function json(value: any): string
	return HttpService:JSONEncode(value)
end
local function id(): string
	return HttpService:GenerateGUID(false)
end

-- module
return {
	deepclone = deepclone,
	deepfreeze = deepfreeze,
	noyield = noyield,

	json = json,
	id = id,
}
