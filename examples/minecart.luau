--!strict
-- Opens the minecart list at the nearest Lovakengj minecart (Zeah), prints the stops and closes it again. Travels nowhere.
local Minecart = require("@lib/main/interfaces/mainscreen/minecart")

assert(Minecart.open(), "couldn't open the minecart list")
for _, d in ipairs(Minecart.destinations() or {}) do
	print(`{d.key}: {d.name}`)
end
-- To travel: Minecart.select(Minecart.Stop.Lovakengj)
assert(Minecart.close(), "couldn't close the list")
