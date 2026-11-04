--!strict
-- Beside a Wilderness obelisk, with the Wilderness hard diary: prints the destinations and closes the list. Goes nowhere.
local Obelisk = require("@lib/main/interfaces/mainscreen/obelisk")

assert(Obelisk.open(), "couldn't open the list")
for _, d in ipairs(Obelisk.destinations() or {}) do
	print(d.name)
end
-- To go: Obelisk.select(Obelisk.Level.Level19), then Obelisk.teleport()
assert(Obelisk.close(), "couldn't close the list")
