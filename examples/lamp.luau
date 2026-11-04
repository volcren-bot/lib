--!strict
-- Rubs a lamp in the inventory, prints the skills, chooses one and closes the interface again. Keeps the lamp.
local Lamp = require("@lib/main/interfaces/mainscreen/lamp")
local Stats = require("@lib/main/interfaces/gametabs/stats")

local ok, why = Lamp.open()
assert(ok, why)
for _, cell in ipairs(Lamp.skills() or {}) do
	print(cell.name)
end
assert(Lamp.choose(Stats.Skill.Herblore), "couldn't choose Herblore")
print("chosen:", Lamp.selected())
-- To spend the lamp on it: Lamp.confirm()
assert(Lamp.close(), "couldn't close it")
