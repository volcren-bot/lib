--!strict
local Player = require("../main/player")

local plane = Player.plane()
print("plane:", plane)
local position = Player.position()
if position then
	print(string.format("position: (%d, %d) plane %d", position.x, position.y, position.plane))
end
