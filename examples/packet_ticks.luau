--!strict
local Host = require("../host")

-- Prints each game tick as the server's tick packet (2) arrives, with the time since the last one. Callbacks run inside Host.sleep.
local last: number? = nil
Host.on_packet({ 2 }, function(packet)
	print(`tick {if last then `+{packet.time_ms - last} ms` else ""}`)
	last = packet.time_ms
end)

while true do
	Host.sleep(1000)
end
