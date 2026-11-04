--!strict
-- Prints what the client logs as it happens: each game tick (the server's tick packet, 2, with whether the server moved you and to
-- which tile) and every change to an item container. Callbacks run inside Host.sleep, which they wake early; a script that never
-- sleeps never runs them.
local Host = require("@lib/host")

local last: number? = nil
Host.on_packet({ 2 }, function(packet)
	local since = if last then ` (+{packet.time_ms - last} ms)` else ""
	last = packet.time_ms
	local m = Host.movement()
	if m then
		print(
			`tick {m.tick}{since}: {if m.moving then "moving" else "still"} at {m.x}, {m.y} (from {m.from_x}, {m.from_y})`
		)
	else
		print(`tick{since}`)
	end
end)

Host.on_item_change(function(change)
	print(
		`container {change.container} slot {change.slot}: {change.old_item} x{change.old_quantity} -> {change.new_item} x{change.new_quantity} (tick {change.tick or "?"})`
	)
end)

while true do
	Host.sleep(1000)
end
