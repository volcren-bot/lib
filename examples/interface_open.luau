--!strict
local Toplevel = require("../main/interfaces/mainscreen/toplevel")
local GameVal = require("../utils/game_val")

local open = Toplevel.interfaces()
if open == nil or #open == 0 then
	print("no interface open")
else
	for _, o in ipairs(open) do
		print(`interface open: {GameVal.interface(o.group) or "?"} ({o.group}, {o.slot})`)
	end
end
