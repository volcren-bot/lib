--!strict
local Host = require("../host")
local game_state = Host.game_state
local players = Host.players
local Inventory = require("../main/interfaces/gametabs/inventory")
local Wornitems = require("../main/interfaces/gametabs/wornitems")
local SidePanels = require("../main/interfaces/gametabs/side_panels")
local Npcs = require("../main/entities/npcs")

local state = game_state()
local run_energy, weight = state.run_energy, state.weight
if run_energy and weight then
	print(string.format("run energy %.2f%%, weight %d kg", run_energy / 100, weight))
end

local tab = SidePanels.current()
print("open tab:", tab and SidePanels.name(tab) or "none")

local items = assert(Inventory.items())
print(string.format("inventory: %d items, %d free slots", #items, assert(Inventory.free_slots())))
for _, item in ipairs(items) do
	print(string.format("  slot %d: item %d x%d", item.slot, item.id, item.quantity))
end

for name, item in pairs(assert(Wornitems.worn())) do
	print(string.format("  wearing %s: item %d", name, item.id))
end

local position = state.position
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
