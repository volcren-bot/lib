--!strict
local Draw = require("../utils/draw")
-- cleared and drawn in one overlay update
Draw.batch(function()
	Draw.clear()
	Draw.rect(100, 100, 200, 200, Draw.RED)
end)
print("drew a red box at (100, 100)-(200, 200)")
