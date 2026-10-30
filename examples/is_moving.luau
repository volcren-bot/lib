--!strict
local Host = require("../host")

-- Prints, at each game tick, whether the server moved you and to which tile. Server packet 2 ends a tick in this game revision.
while true do
	if Host.wait_packet({ 2 }, 1200) then
		local m = Host.movement()
		if m then
			print(
				`tick {m.tick}: {if m.moving then "moving" else "still"} at {m.x}, {m.y} (from {m.from_x}, {m.from_y})`
			)
		end
	end
end
