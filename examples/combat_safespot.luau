--!strict
-- Attacks the nearest NAME nobody else is fighting and kills it from a safe spot with a ranged weapon: it gets
-- stuck where it can't hit back, but in your range and sight. Then the next one, KILLS times.
-- Turn auto retaliate off first, or you walk up to whatever hits you.
local NAME = "Lesser demon"
local KILLS = 3
-- other monsters around to keep out of reach of too ({} for none)
local AVOID = { "Lesser demon", "Black demon" }
-- eat one of these (best first) when the hitpoints fall to EAT_AT; stop at STOP_AT
local FOOD = { "Shark", "Cake", "2/3 cake", "Slice of cake" }
local EAT_AT, STOP_AT = 60, 30

local CombatSafeSpot = require("../main/combat_safespot")
local Inventory = require("../main/interfaces/gametabs/inventory")
local Player = require("../main/player")

local function eat(): boolean
	local items = Inventory.items() or {}
	for _, food in ipairs(FOOD) do
		for _, item in ipairs(items) do
			if item.name == food then
				return Inventory.interact_slot(item.slot, "Eat")
			end
		end
	end
	return false
end

local function on_tick(): boolean?
	local hitpoints = Player.hitpoints() or 99
	if hitpoints <= STOP_AT then
		return false
	end
	if hitpoints <= EAT_AT then
		eat()
	end
	return nil
end

if Player.position() == nil then
	print("log in first")
	return
end
print(`killing {KILLS} {NAME} with a range of {CombatSafeSpot.weapon_range()}`)
for kill = 1, KILLS do
	local target = CombatSafeSpot.free_target(NAME)
	if target == nil then
		print(`no {NAME} free around`)
		break
	end
	-- walks to a spot it's in range from, attacks it, and keeps it stuck while we shoot
	local killed, why = CombatSafeSpot.fight(target.index, { avoid = AVOID, on_tick = on_tick })
	if not killed then
		print(`stopped: {why}`)
		break
	end
	print(`killed {kill} of {KILLS}`)
end
