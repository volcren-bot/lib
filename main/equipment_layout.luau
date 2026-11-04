--!strict
-- Equipment layouts: what an `equipment` form field gives a script (the user reads them from the client in the loader), checked against and put on with the worn items, the inventory and the bank.
-- A slot wants an item (by id), nothing (`empty`) or doesn't care (`any`). Nothing here guesses an id: an item is the id the client holds, found in the inventory and the bank by that id or by its name, since some items are worn under another id than they are held (graceful pieces).
local Host = require("@lib/host")
local sleep = Host.sleep
local time = Host.time
type EquipmentLayout = Host.EquipmentLayout
type EquipmentLayoutSlot = Host.EquipmentLayoutSlot
type ItemSlot = Host.ItemSlot
local Bankmain = require("@lib/main/interfaces/mainscreen/bankmain")
local Combat = require("@lib/main/interfaces/gametabs/combat")
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Item = require("@lib/utils/item")
local Log = require("@lib/utils/log")
local Magic = require("@lib/main/interfaces/gametabs/magic")
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

local EquipmentLayout = {}

export type Layout = EquipmentLayout
export type Slot = EquipmentLayoutSlot

-- How long to wait for the worn items to change after a click, and between looks.
EquipmentLayout.EQUIP_TIMEOUT_MS = 2500
EquipmentLayout.POLL_MS = 50

-- The worn items slots a layout lists, in the container's order.
EquipmentLayout.SLOTS = table.freeze({
	Wornitems.HEAD,
	Wornitems.CAPE,
	Wornitems.AMULET,
	Wornitems.WEAPON,
	Wornitems.BODY,
	Wornitems.SHIELD,
	Wornitems.LEGS,
	Wornitems.HANDS,
	Wornitems.FEET,
	Wornitems.RING,
	Wornitems.AMMO,
})

local function worn_by_slot(): { [number]: ItemSlot }?
	local items = Wornitems.slots()
	if items == nil then
		return nil
	end
	local by_slot: { [number]: ItemSlot } = {}
	for _, s in ipairs(items) do
		if s.id ~= -1 then
			by_slot[s.slot] = s
		end
	end
	return by_slot
end

-- What to look for in the inventory or the bank for a slot's item: its id, or its name, since some items are worn under another id than they are held (graceful pieces).
local function wanted(slot: Slot): { Item.Item }
	local items: { Item.Item } = { slot.id :: number }
	if slot.name and slot.name ~= "" then
		table.insert(items, slot.name)
	end
	return items
end

local function label(slot: Slot): string
	local name = Wornitems.slot_name(slot.slot) or tostring(slot.slot)
	if slot.mode == "item" then
		return `{name}: {slot.name or slot.id}`
	end
	return `{name}: {slot.mode}`
end

-- A layout of what is worn now: every slot its item, or `empty`. Nil when the worn items can't be read. `stackable` is only known for a stack of more than one.
function EquipmentLayout.from_client(name: string?): Layout?
	local worn = worn_by_slot()
	if worn == nil then
		return nil
	end
	local ids: { number } = {}
	for _, slot in ipairs(EquipmentLayout.SLOTS) do
		local item = worn[slot]
		if item then
			table.insert(ids, item.id)
		end
	end
	local names = if #ids > 0 then Item.names(ids) else {}
	local slots: { Slot } = {}
	local named = 0
	for _, slot in ipairs(EquipmentLayout.SLOTS) do
		local item = worn[slot]
		if item then
			named += 1
			table.insert(slots, {
				slot = slot,
				mode = "item" :: "item",
				id = item.id,
				quantity = item.quantity,
				name = if names then names[named] else nil,
				stackable = item.quantity > 1,
			})
		else
			table.insert(slots, { slot = slot, mode = "empty" :: "empty" })
		end
	end
	return { name = name or "From client", slots = slots }
end

-- Whether a slot's rule holds for what is worn in it.
local function slot_matches(slot: Slot, worn: ItemSlot?): boolean
	if slot.mode == "any" then
		return true
	elseif slot.mode == "empty" then
		return worn == nil
	end
	return worn ~= nil and worn.id == slot.id
end

-- Whether every slot of the layout holds: its item worn (by id), or nothing worn where it wants nothing. Nil when the worn items can't be read.
function EquipmentLayout.matches(layout: Layout): boolean?
	local worn = worn_by_slot()
	if worn == nil then
		return nil
	end
	for _, slot in ipairs(layout.slots) do
		if not slot_matches(slot, worn[slot.slot]) then
			return false
		end
	end
	return true
end

-- The slots whose item is neither worn nor in the inventory: what has to come out of the bank.
function EquipmentLayout.missing(layout: Layout): { Slot }
	local worn = worn_by_slot() or {}
	local missing: { Slot } = {}
	for _, slot in ipairs(layout.slots) do
		if
			slot.mode == "item"
			and not slot_matches(slot, worn[slot.slot])
			and not Inventory.contains_any(wanted(slot))
		then
			table.insert(missing, slot)
		end
	end
	return missing
end

-- With the bank open, withdraws each missing item (a stack's whole quantity, else one). True when none is missing afterwards.
function EquipmentLayout.withdraw(layout: Layout): boolean
	if not Bankmain.is_open() then
		Log.log("EquipmentLayout", "withdraw: the bank isn't open")
		return false
	end
	for _, slot in ipairs(EquipmentLayout.missing(layout)) do
		local amount = if slot.stackable then slot.quantity else 1
		if not Bankmain.withdraw(wanted(slot), amount, false) then
			Log.log("EquipmentLayout", `withdraw: couldn't take {label(slot)}`)
			return false
		end
	end
	return #EquipmentLayout.missing(layout) == 0
end

local function wait_slot(slot: Slot): boolean
	local deadline = time() + EquipmentLayout.EQUIP_TIMEOUT_MS
	while time() < deadline do
		local worn = worn_by_slot()
		if worn and slot_matches(slot, worn[slot.slot]) then
			return true
		end
		sleep(EquipmentLayout.POLL_MS)
	end
	return false
end

-- Wears each of the layout's items from the inventory, in one of the inventory's click patterns, then takes off what is worn where the layout wants nothing. The bank must be closed (a click in the inventory would deposit). True when the layout matches afterwards.
function EquipmentLayout.equip(layout: Layout): boolean
	if EquipmentLayout.matches(layout) then
		return true
	end
	if Bankmain.is_open() then
		Log.log("EquipmentLayout", "equip: close the bank first")
		return false
	end
	local worn = worn_by_slot()
	if worn == nil then
		return false
	end
	local by_inventory_slot: { [number]: Slot } = {}
	local to_remove: { Slot } = {}
	for _, slot in ipairs(layout.slots) do
		if slot_matches(slot, worn[slot.slot]) then
			continue
		end
		if slot.mode == "item" then
			local at = Inventory.index_of(wanted(slot))
			if at == nil then
				Log.log("EquipmentLayout", `equip: {label(slot)} isn't in the inventory`)
				return false
			end
			by_inventory_slot[at] = slot
		elseif slot.mode == "empty" then
			table.insert(to_remove, slot)
		end
	end
	if next(by_inventory_slot) ~= nil and not Inventory.open() then
		return false
	end
	for _, at in ipairs(Inventory.random_pattern()) do
		local slot = by_inventory_slot[at]
		if slot == nil then
			continue
		end
		-- the item may have moved: a two handed weapon puts the shield back in the inventory
		local now = Inventory.index_of(wanted(slot))
		if now == nil or not Inventory.click_slot(now) or not wait_slot(slot) then
			Log.log("EquipmentLayout", `equip: couldn't wear {label(slot)}`)
			return false
		end
	end
	for _, slot in ipairs(to_remove) do
		-- wearing something else there may have taken it off already
		local again = worn_by_slot()
		if again and again[slot.slot] ~= nil then
			if Inventory.is_full() then
				Log.log("EquipmentLayout", `equip: no room to take off {label(slot)}`)
				return false
			end
			if not Wornitems.remove(slot.slot) or not wait_slot(slot) then
				Log.log("EquipmentLayout", `equip: couldn't take off {label(slot)}`)
				return false
			end
		end
	end
	return EquipmentLayout.matches(layout) == true
end

-- The layout's spell as the spellbook knows it, nil when the layout has none or the book can't be read.
function EquipmentLayout.spell(layout: Layout): Magic.Spell?
	local spell = layout.spell
	if spell == nil then
		return nil
	end
	return Magic.spell(spell.name, spell.book)
end

-- Whether the layout's spell is one to autocast: the weapon read into the layout offered autocast.
function EquipmentLayout.autocasts(layout: Layout): boolean
	return layout.spell ~= nil and layout.spell.autocast
end

-- Sets the layout's spell as the autocast (defensively with `defensive`), through the combat tab. True when the layout has no spell to autocast, or once it is set.
function EquipmentLayout.set_autocast(layout: Layout, defensive: boolean?): boolean
	local spell = layout.spell
	if spell == nil or not spell.autocast then
		return true
	end
	return Combat.set_autocast(spell.name, defensive)
end

-- Gets the layout worn: with the bank open it withdraws what is missing and closes the bank, then equips and sets the autocast spell when the layout has one. True when the layout matches at the end.
function EquipmentLayout.prepare(layout: Layout): boolean
	if EquipmentLayout.matches(layout) then
		return EquipmentLayout.set_autocast(layout)
	end
	if Bankmain.is_open() then
		if not EquipmentLayout.withdraw(layout) then
			return false
		end
		if not Bankmain.close() then
			return false
		end
	elseif #EquipmentLayout.missing(layout) > 0 then
		Log.log(
			"EquipmentLayout",
			"prepare: some items are in neither the inventory nor the worn items, and the bank isn't open"
		)
		return false
	end
	return EquipmentLayout.equip(layout) and EquipmentLayout.set_autocast(layout)
end

return EquipmentLayout
