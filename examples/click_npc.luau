--!strict
local NAME = "Spirit Angler"
local OPTION = "Talk-to"

local Host = require("../host")
local sleep = Host.sleep
local Clickbox = require("../main/clickbox")
local Draw = require("../utils/draw")
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local npc = Npcs.nearest(NAME, me)
if npc == nil then
	print(`no {NAME} around`)
	return
end
print(`nearest {npc.name} ({npc.id}) at {npc.x}, {npc.y}, {Npcs.distance(npc, me)} tiles away`)

-- The NPC's clickbox: model outline in yellow (cyan when only the box is known), the client's 3D click box for size-1 NPCs in blue.
local function highlight()
	local box = Npcs.clickbox(npc)
	Draw.clear()
	if box then
		Clickbox.draw(box)
	end
end

highlight()
local ok = Npcs.interact(npc, OPTION)
print(if ok then `{OPTION} {npc.name}` else `couldn't {OPTION} {npc.name}`)

for _ = 1, 30 do
	highlight()
	sleep(100)
end
Draw.clear()
