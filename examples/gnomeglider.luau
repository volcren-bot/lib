--!strict
-- Opens the gnome glider map at the nearest pilot, prints the landing places and closes it again. Travels nowhere.
local Gnomeglider = require("@lib/main/interfaces/mainscreen/gnomeglider")

local ok, why = Gnomeglider.open()
assert(ok, why)
for _, d in ipairs(Gnomeglider.destinations() or {}) do
	print(d.name)
end
-- To travel: Gnomeglider.select(Gnomeglider.Site.KarHewo)
assert(Gnomeglider.close(), "couldn't close the map")
