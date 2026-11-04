--!strict
-- Lists the minigame teleports in both of their places and chooses an activity. Teleports nowhere.
local Minigames = require("@lib/main/interfaces/mainscreen/minigames")
local Grouping = Minigames.Grouping

local opened, why = Minigames.open()
assert(opened, why)
for _, t in ipairs(Minigames.teleports() or {}) do
	print(t.name, t.location)
end
assert(Minigames.close(), "couldn't close the list")

assert(Grouping.choose("Castle Wars"), "couldn't choose Castle Wars")
print("chosen:", Grouping.selected())
-- To teleport, which starts the 20 minute cooldown once it finishes: Minigames.teleport("Castle Wars")
