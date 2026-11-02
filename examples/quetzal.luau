--!strict
-- Opens the quetzal map at the nearest Renu, prints the sites and closes it again. Travels nowhere.
local Quetzal = require("@lib/main/interfaces/mainscreen/quetzal")

assert(Quetzal.open(), "couldn't open the quetzal map")
for index, name in pairs(Quetzal.names() or {}) do
	print(`marker {index}: {name}`)
end
-- To travel: Quetzal.select(Quetzal.Site.Aldarin)
assert(Quetzal.close(), "couldn't close the map")
