--!strict
local NPC_NAME = "Banker"
local NPC_OPTION = "Talk-to"
local OBJECT_NAME = "Bank chest"
local OBJECT_OPTION = "Use"

local Host = require("@lib/host")
local sleep = Host.sleep
local Clickbox = require("@lib/main/clickbox")
local Draw = require("@lib/utils/draw")
local Npcs = require("@lib/main/entities/npcs")
local Objects = require("@lib/main/entities/objects")
local Walker = require("@lib/main/walker")

local me = assert(Walker.position())

local function show(box: () -> Clickbox.Clickbox?)
	for _ = 1, 30 do
		local b = box()
		Draw.batch(function()
			Draw.clear()
			if b then
				for _, t in ipairs(b.triangles or {}) do
					Draw.polygon(t, Draw.color(255, 255, 0, 90))
				end
				Clickbox.draw(b)
			end
		end)
		sleep(100)
	end
	Draw.clear()
end

if NPC_NAME ~= "" then
	local npc = Npcs.nearest(NPC_NAME, me)
	if npc == nil then
		print(`no {NPC_NAME} around`)
	else
		print(`nearest {npc.name} ({npc.id}) at {npc.x}, {npc.y}, {Npcs.distance(npc, me)} tiles away`)
		local ok = Npcs.interact(npc, NPC_OPTION)
		print(if ok then `{NPC_OPTION} {npc.name}` else `couldn't {NPC_OPTION} {npc.name}`)
		show(function()
			return Npcs.clickbox(npc)
		end)
	end
end

if OBJECT_NAME ~= "" then
	local loc = Objects.nearest(OBJECT_NAME, me)
	if loc == nil then
		print(`no {OBJECT_NAME} around`)
	else
		print(`nearest {loc.name} ({loc.id}) at {loc.x}, {loc.y}, {Objects.distance(loc, me)} tiles away`)
		local ok = Objects.interact(loc, OBJECT_OPTION)
		print(if ok then `{OBJECT_OPTION} {loc.name}` else `couldn't {OBJECT_OPTION} {loc.name}`)
		show(function()
			return Objects.clickbox(loc)
		end)
	end
end
