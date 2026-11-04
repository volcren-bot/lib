--!strict
-- Reads the log storage beside a balloon, opens the map, lists the places and closes it again. Flies nowhere.
local Balloon = require("@lib/main/interfaces/mainscreen/balloon")

for name, count in Balloon.check() or {} do
	print(name, count)
end
local ok, why = Balloon.open()
assert(ok, why)
for _, d in ipairs(Balloon.destinations() or {}) do
	print(d.name, d.log.name, if d.unlocked then "unlocked" else "locked")
end
-- To fly, spending a log: Balloon.select(Balloon.Place.Varrock)
assert(Balloon.close(), "couldn't close the map")
