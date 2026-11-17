-- Condition tree of resave.schema (node fields: node.luau).
local nodes = require './node'

local spec: nodes.spec = {
	name = 'schema',
	preamble = '',
	call = 'local s = resave.schema { coins = 0 }',
	ret = 'return s',
	tree = {},
}

return spec
