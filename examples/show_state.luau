--!strict
-- Prints a snapshot of the client: position and plane, run energy and weight, the minimap and compass, the open tab and interfaces,
-- the inventory and worn items, the nearest banker and the players around. Reads only.
local Host = require("@lib/host")
local game_state = Host.game_state
local players = Host.players
local Camera = require("@lib/main/camera")
local Chatbox = require("@lib/main/interfaces/chatbox/chatbox")
local GameVal = require("@lib/utils/game_val")
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Minimap = require("@lib/main/interfaces/minimap")
local Npcs = require("@lib/main/entities/npcs")
local Player = require("@lib/main/player")
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

local state = game_state()
local position = Player.position()
if position then
	print(string.format("position: (%d, %d) plane %d", position.x, position.y, position.plane))
else
	print("position unknown (logged out?)")
end
local run_energy, weight = state.run_energy, state.weight
if run_energy and weight then
	print(string.format("run energy %.2f%%, weight %d kg", run_energy / 100, weight))
end
local minimap = Minimap.state()
if minimap then
	print(`minimap zoom: {minimap.zoom}, compass: {Camera.yaw_degrees()}`)
end

local tab = SidePanels.current()
print("open tab:", tab and SidePanels.name(tab) or "none")
for _, o in ipairs(Toplevel.interfaces() or {}) do
	print(`interface open: {GameVal.interface(o.group) or "?"} ({o.group}, {o.slot})`)
end
for _, group in ipairs(Chatbox.interfaces() or {}) do
	print(`chatbox interface open: {GameVal.interface(group) or "?"} ({group})`)
end

local items = assert(Inventory.items())
print(string.format("inventory: %d items, %d free slots", #items, assert(Inventory.free_slots())))
for _, item in ipairs(items) do
	print(string.format("  slot %d: %s (%d) x%d", item.slot, item.name or "?", item.id, item.quantity))
end
for name, item in pairs(assert(Wornitems.worn())) do
	print(string.format("  wearing %s: item %d", name, item.id))
end

if position then
	local banker = Npcs.nearest("Banker", position)
	if banker then
		print(
			string.format(
				"nearest banker: %d tiles away at (%d, %d)",
				Npcs.distance(banker, position),
				banker.x,
				banker.y
			)
		)
	end
end
print("players around:", #assert(players()))
