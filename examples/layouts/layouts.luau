--!strict
local Bankmain = require("@lib/main/interfaces/mainscreen/bankmain")
local EquipmentLayout = require("@lib/main/equipment_layout")
local Host = require("@lib/host")
local InventoryLayout = require("@lib/main/inventory_layout")
local PrayerLayout = require("@lib/main/prayer_layout")

local values = Host.settings()
local equipment: EquipmentLayout.Layout? = values.equipment
local inventory: InventoryLayout.Layout? = values.inventory
local prayers: PrayerLayout.Layout? = values.prayers

local function wants(
	item: { stackable: boolean?, min: number?, max: number?, doses: { number }?, locked: boolean? }
): string
	local parts: { string } = {}
	if item.stackable then
		local min, max = item.min or 0, item.max or 0
		table.insert(
			parts,
			if min == 0 and max == 0 then "any amount" elseif min == max then `x{min}` else `{min} to {max}`
		)
	end
	if item.doses then
		table.insert(parts, `doses {table.concat(item.doses, ", ")}`)
	end
	if item.locked then
		table.insert(parts, "required")
	end
	return table.concat(parts, ", ")
end

if equipment then
	print(`equipment layout "{equipment.name}":`)
	for _, slot in ipairs(equipment.slots) do
		if slot.mode == "item" then
			print(`  slot {slot.slot}: {slot.name} (id {slot.id}) {wants(slot)}`)
		else
			print(`  slot {slot.slot}: {slot.mode}`)
		end
	end
	print("  worn now:", EquipmentLayout.matches(equipment))
	if equipment.spell then
		print(
			`  spell: {equipment.spell.name} ({equipment.spell.book}), {if equipment.spell.autocast
				then "autocast"
				else "cast by hand"}`
		)
	end
else
	print("no equipment layout chosen")
end

if inventory then
	print(`inventory layout "{inventory.name}":`)
	for _, slot in ipairs(inventory.slots) do
		print(`  slot {slot.slot}: {slot.name} (id {slot.id}) {wants(slot)}`)
	end
	for _, rune in ipairs(inventory.pouch or {}) do
		print(`  pouch: {rune.name} {wants(rune)}`)
	end
	print("  held now:", InventoryLayout.matches(inventory))
else
	print("no inventory layout chosen")
end

if prayers then
	print(`prayer layout "{prayers.name}": {table.concat(prayers.prayers, ", ")}`)
	print(`  the script's: {table.concat(prayers.locked or {}, ", ")}`)
	print("  on now:", PrayerLayout.is_active(prayers), "quick prayers:", PrayerLayout.is_quick(prayers))
	if values.quick then
		print("  set as quick prayers:", PrayerLayout.set_quick(prayers))
	else
		print("  turned on:", PrayerLayout.activate(prayers))
	end
else
	print("no prayer layout chosen")
end

if not values.act or (equipment == nil and inventory == nil) then
	return
end
local equipment_done = equipment == nil or EquipmentLayout.matches(equipment) == true
local inventory_done = inventory == nil or InventoryLayout.matches(inventory) == true
if equipment_done and inventory_done then
	print("both layouts are already in place")
	return
end

if equipment and not equipment_done then
	if not Bankmain.open() then
		print("couldn't open a bank")
		return
	end
	print("equipped:", EquipmentLayout.prepare(equipment))
end
if inventory and not inventory_done then
	if not Bankmain.open() then
		print("couldn't open a bank")
		return
	end
	if not InventoryLayout.withdraw(inventory) then
		print("couldn't withdraw the inventory")
		return
	end
	Bankmain.close()
	print("reordered:", InventoryLayout.reorder(inventory))
end
