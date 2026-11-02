--!strict
-- Opens the mushtree list at the nearest Magic Mushtree, prints the trees and closes it again. Travels nowhere.
local Mushtree = require("@lib/main/interfaces/mainscreen/mushtree")

assert(Mushtree.open(), "couldn't open the mushtree list")
for _, d in ipairs(Mushtree.destinations() or {}) do
	print(`{d.number}: {d.name}`)
end
-- To travel: Mushtree.select(Mushtree.Tree.VerdantValley)
assert(Mushtree.close(), "couldn't close the list")
