--!strict
-- Opens the jewellery box in your house, prints its destinations and closes it again. Teleports nowhere.
local Jewellerybox = require("@lib/main/interfaces/mainscreen/jewellerybox")

local ok, why = Jewellerybox.open()
assert(ok, why)
for _, d in ipairs(Jewellerybox.destinations() or {}) do
	print(d.key, d.name, d.jewellery, d.available)
end
-- To travel: Jewellerybox.select(Jewellerybox.Place.GrandExchange)
assert(Jewellerybox.close(), "couldn't close the menu")
