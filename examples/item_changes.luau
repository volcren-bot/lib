--!strict
local Host = require("../host")

-- Prints every change to an item container as the client makes it. Callbacks run inside Host.sleep, which they wake early.
Host.on_item_change(function(change)
	print(`container {change.container} slot {change.slot}: {change.old_item} x{change.old_quantity} -> {change.new_item} x{change.new_quantity} (tick {change.tick or "?"})`)
end)

while true do
	Host.sleep(1000)
end
