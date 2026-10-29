--!strict
-- Gets the nearest NPC called NAME stuck where it can't reach you, without attacking it.
local NAME = "Lesser demon"
-- how long to show the tiles for
local SHOW_MS = 5000

local Host = require("../host")
local sleep = Host.sleep
local Draw = require("../utils/draw")
local Npcs = require("../main/entities/npcs")
local Projection = require("../main/projection/projection")
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local me = Walker.position()
if me == nil then
	print("log in first")
	return
end
local npc = Npcs.nearest(NAME, me)
if npc == nil then
	print(`no {NAME} around`)
	return
end
local size = SafeSpot.size(npc)
print(`trapping {NAME} {npc.index} ({size}x{size}) at {npc.x}, {npc.y}`)

local tile, how = SafeSpot.trap(npc.index, { size = size })
if tile == nil then
	print("not trapped:", how)
	return
end
local stuck = how :: SafeSpot.Chaser
print(`safe on {tile.x}, {tile.y}; the {NAME} is stuck on {stuck.x}, {stuck.y}`)

-- our tile in green, the NPC's in red, drawn as one overlay update
for _ = 1, SHOW_MS // 100 do
	Draw.batch(function()
		Draw.clear()
		local mine = Projection.tile(tile)
		if mine then
			Draw.quad(mine, Draw.GREEN)
		end
		local c = SafeSpot.locate(npc.index, size)
		if c then
			for i = 0, c.size - 1 do
				for j = 0, c.size - 1 do
					local q = Projection.tile({ x = c.x + i, y = c.y + j })
					if q then
						Draw.quad(q, Draw.RED)
					end
				end
			end
		end
	end)
	sleep(100)
end
Draw.clear()
