--!strict
local Host = require("../host")
local varbit = Host.varbit
local Varbits = {}

Varbits.SPELLBOOK = 4070
Varbits.BUSY = 12393

function Varbits.get(id: number): number?
	return varbit(id)
end

return Varbits
