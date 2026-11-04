--!strict
-- In a house with a mounted Xeric's talisman: teleports to Xeric's Glade.
local House = require("@lib/main/house")
local Mounted = require("@lib/main/interfaces/mainscreen/mounted")

assert(House.inside(), "not in a house")
local started, why = Mounted.teleport("talisman", "Glade")
assert(started, why)
