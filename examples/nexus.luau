--!strict
-- In a house with a Portal Nexus: prints its teleports and closes the list. Goes nowhere.
local Nexus = require("@lib/main/interfaces/mainscreen/nexus")

local ok, why = Nexus.open()
assert(ok, why)
for _, d in ipairs(Nexus.destinations() or {}) do
	print(`{d.key}: {d.name}`)
end
-- To go: Nexus.select("Barrows")
assert(Nexus.close(), "couldn't close the list")
