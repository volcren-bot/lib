--!strict
-- Lists the ports of an open charter trader's menu, from the side list and from the map. Sails nowhere.
local Chartering = require("@lib/main/interfaces/mainscreen/chartering")
local Map = Chartering.Map
local Tab = Chartering.Tab

print("list open:", Tab.is_open(), "map open:", Map.is_open())
for _, d in ipairs(Tab.destinations() or {}) do
	print(`list: {d.key} {d.name}`)
end
for index, name in pairs(Map.names() or {}) do
	print(`map marker {index}: {name}`)
end
-- To sail, by chance a key, the map or the list: Chartering.select(Chartering.Port.Catherby)
