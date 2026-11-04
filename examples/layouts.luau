--!strict
-- Asks for an equipment, an inventory and a prayer layout, which adds Equipment, Inventory and Prayer tabs to the script's page in the loader.
-- Make a layout there (Read from client, Save), pick it in Settings, then press Start: the script says what it got, and if a layout
-- isn't matched yet it goes to the bank for it, equips it and puts the inventory in order.
local Bankmain = require("@lib/main/interfaces/mainscreen/bankmain")
local EquipmentLayout = require("@lib/main/equipment_layout")
local Host = require("@lib/host")
local InventoryLayout = require("@lib/main/inventory_layout")
local PrayerLayout = require("@lib/main/prayer_layout")

local values = Host.form({
	title = "Layouts example",
	submit = "Start",
	fields = {
		{ kind = "label", text = "Pick the layouts to use. Make them in the Equipment and Inventory tabs." },
		{ id = "equipment", kind = "equipment", label = "Equipment" },
		{ id = "inventory", kind = "inventory", label = "Inventory" },
		{ id = "prayers", kind = "prayer", label = "Prayers" },
		{ id = "act", kind = "check", label = "Go to the bank and get them", default = true },
		{
			id = "quick",
			kind = "check",
			label = "Make the prayers the quick prayers (else turn them on)",
			default = true,
		},
	},
})
if values == nil then
	print("form cancelled")
	return
end
local equipment: EquipmentLayout.Layout? = values.equipment
local inventory: InventoryLayout.Layout? = values.inventory
local prayers: PrayerLayout.Layout? = values.prayers

if equipment then
	print(`equipment layout "{equipment.name}":`)
	for _, slot in ipairs(equipment.slots) do
		if slot.mode == "item" then
			print(`  slot {slot.slot}: {slot.name} (id {slot.id}) x{slot.quantity}`)
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
		print(`  slot {slot.slot}: {slot.name} (id {slot.id}) x{slot.quantity}`)
	end
	for _, rune in ipairs(inventory.pouch or {}) do
		print(`  pouch: {rune.name} x{rune.quantity}`)
	end
	print("  held now:", InventoryLayout.matches(inventory))
else
	print("no inventory layout chosen")
end

if prayers then
	print(`prayer layout "{prayers.name}": {table.concat(prayers.prayers, ", ")}`)
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

if not Bankmain.open() then
	print("couldn't open a bank")
	return
end
if equipment and not EquipmentLayout.withdraw(equipment) then
	print("couldn't withdraw the equipment")
	return
end
if inventory and not InventoryLayout.withdraw(inventory) then
	print("couldn't withdraw the inventory")
	return
end
Bankmain.close()
if equipment then
	print("equipped:", EquipmentLayout.equip(equipment), "autocast set:", EquipmentLayout.set_autocast(equipment))
end
if inventory then
	print("reordered:", InventoryLayout.reorder(inventory))
end
