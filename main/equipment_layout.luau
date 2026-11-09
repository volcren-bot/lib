--!strict
local Host = require("@lib/host")
local sleep = Host.sleep
type EquipmentLayout = Host.EquipmentLayout
type EquipmentLayoutSlot = Host.EquipmentLayoutSlot
type ItemSlot = Host.ItemSlot
local Bankmain = require("@lib/main/interfaces/mainscreen/bankmain")
local Combat = require("@lib/main/interfaces/gametabs/combat")
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Item = require("@lib/utils/item")
local LayoutItems = require("@lib/main/layout_item")
local Log = require("@lib/utils/log")
local Magic = require("@lib/main/interfaces/gametabs/magic")
local Mouse = require("@lib/utils/input/mouse")
local Widgets = require("@lib/main/interfaces/widgets")
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

local EquipmentLayout = {}

export type Layout = EquipmentLayout
export type Slot = EquipmentLayoutSlot

EquipmentLayout.EQUIP_TIMEOUT_MS = 2500
EquipmentLayout.POLL_MS = 50
EquipmentLayout.CONFIRM_MS = 1200
EquipmentLayout.WEAR_ATTEMPTS = 3
EquipmentLayout.SWAP_MOUSE_PACE = 1.2
export type EquipOptions = { stop: (() -> boolean)?, after_clicks: (() -> ())? }

EquipmentLayout.STOP_POLL_MS = 30

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
	Wornitems.SECONDARY_AMMO,
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
	local secondary = Wornitems.secondary_ammo()
	if secondary then
		by_slot[secondary.slot] = secondary
	end
	return by_slot
end

local function slot_of(layout: Layout, slot: number): Slot?
	for _, s in ipairs(layout.slots) do
		if s.slot == slot then
			return s
		end
	end
	return nil
end

local function secondary_holder(layout: Layout): Wornitems.SecondaryHolder?
	local cape = slot_of(layout, Wornitems.CAPE)
	if cape and cape.id and Wornitems.is_quiver(cape.id) then
		return "quiver"
	end
	return Wornitems.secondary_ammo_holder()
end

local function counts(slot: Slot, holder: Wornitems.SecondaryHolder?): boolean
	if slot.slot ~= Wornitems.SECONDARY_AMMO then
		return true
	end
	if holder == nil then
		return false
	end
	return slot.mode ~= "item" or Wornitems.secondary_ammo_accepts(holder, slot.id :: number)
end

local function wanted(slot: Slot): { Item.Item }
	local items = LayoutItems.items(slot)
	if slot.doses == nil and slot.name and slot.name ~= "" then
		table.insert(items, slot.name)
	end
	return items
end

local function carried_at(slot: Slot): number?
	for _, item in ipairs(wanted(slot)) do
		local at = Inventory.index_of(item)
		if at then
			return at
		end
	end
	return nil
end

local function label(slot: Slot): string
	local name = Wornitems.slot_name(slot.slot) or tostring(slot.slot)
	if slot.mode == "item" then
		return `{name}: {if slot.name and slot.name ~= "" then slot.name else slot.id}`
	end
	return `{name}: {slot.mode}`
end

function EquipmentLayout.from_client(name: string?): Layout?
	local worn = worn_by_slot()
	if worn == nil then
		return nil
	end
	local holder = Wornitems.secondary_ammo_holder()
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
			local stackable = item.quantity > 1
			local amount = if stackable then item.quantity else 1
			table.insert(slots, {
				slot = slot,
				mode = "item" :: "item",
				id = item.id,
				ids = { item.id },
				name = if names then names[named] else nil,
				stackable = stackable,
				min = amount,
				max = amount,
				locked = false,
			})
		elseif slot == Wornitems.SECONDARY_AMMO and holder == nil then
			table.insert(slots, { slot = slot, mode = "any" :: "any" })
		else
			table.insert(slots, { slot = slot, mode = "empty" :: "empty" })
		end
	end
	return { name = name or "From client", slots = slots }
end

local function slot_matches(slot: Slot, worn: ItemSlot?): boolean
	if slot.mode == "any" then
		return true
	elseif slot.mode == "empty" then
		return worn == nil
	end
	if worn == nil or not LayoutItems.counts_as(slot, worn.id, nil) then
		return false
	end
	return not slot.stackable or worn.quantity >= (slot.min or 0)
end

function EquipmentLayout.matches(layout: Layout): boolean?
	local worn = worn_by_slot()
	if worn == nil then
		return nil
	end
	local holder = secondary_holder(layout)
	for _, slot in ipairs(layout.slots) do
		if counts(slot, holder) and not slot_matches(slot, worn[slot.slot]) then
			return false
		end
	end
	return true
end

local function in_other_ammo_slot(slot: Slot, worn: { [number]: ItemSlot }): boolean
	local other = if slot.slot == Wornitems.AMMO
		then Wornitems.SECONDARY_AMMO
		elseif slot.slot == Wornitems.SECONDARY_AMMO then Wornitems.AMMO
		else nil
	local item = if other then worn[other] else nil
	return item ~= nil and LayoutItems.counts_as(slot, item.id, nil)
end

local function stack_held(slot: Slot, worn: { [number]: ItemSlot }): number
	local on = worn[slot.slot]
	local wearing = if on and LayoutItems.counts_as(slot, on.id, nil) then on.quantity else 0
	return wearing + (Inventory.count_ex(wanted(slot)) or 0)
end

local function short(slot: Slot, worn: { [number]: ItemSlot }): boolean
	if slot.stackable then
		return not in_other_ammo_slot(slot, worn) and LayoutItems.top_up(slot, stack_held(slot, worn)) ~= nil
	end
	return not slot_matches(slot, worn[slot.slot])
		and not in_other_ammo_slot(slot, worn)
		and not Inventory.contains_any(wanted(slot))
end

function EquipmentLayout.missing(layout: Layout): { Slot }
	local worn = worn_by_slot() or {}
	local holder = secondary_holder(layout)
	local missing: { Slot } = {}
	for _, slot in ipairs(layout.slots) do
		if slot.mode == "item" and counts(slot, holder) and short(slot, worn) then
			table.insert(missing, slot)
		end
	end
	return missing
end

local function take(slot: Slot, worn: { [number]: ItemSlot }): boolean
	local items = wanted(slot)
	if slot.stackable then
		local amount = LayoutItems.top_up(slot, stack_held(slot, worn))
		return amount == nil or Bankmain.withdraw(items, amount, false)
	end
	for _, item in ipairs(items) do
		if (Bankmain.count_ex(item) or 0) > 0 then
			return Bankmain.withdraw(item, 1, false)
		end
	end
	return false
end

function EquipmentLayout.withdraw(layout: Layout): boolean
	if not Bankmain.is_open() then
		Log.log("EquipmentLayout", "withdraw: the bank isn't open")
		return false
	end
	local worn = worn_by_slot() or {}
	for _, slot in ipairs(EquipmentLayout.missing(layout)) do
		if not take(slot, worn) then
			Log.log("EquipmentLayout", `withdraw: couldn't take {label(slot)}`)
			return false
		end
	end
	return #EquipmentLayout.missing(layout) == 0
end

local function wait_slot(slot: Slot): boolean
	return Widgets.wait_within(function()
		local worn = worn_by_slot()
		return worn ~= nil and slot_matches(slot, worn[slot.slot])
	end, EquipmentLayout.EQUIP_TIMEOUT_MS, EquipmentLayout.POLL_MS)
end

local function take_off(slot: Slot): boolean
	if Inventory.is_full() then
		Log.log("EquipmentLayout", `equip: no room to take off {label(slot)}`)
		return false
	end
	if not Wornitems.remove(slot.slot) or not wait_slot(slot) then
		Log.log("EquipmentLayout", `equip: couldn't take off {label(slot)}`)
		return false
	end
	return true
end

local function click_all(slots: { [number]: Slot }, opts: EquipOptions): boolean
	if not Inventory.open() then
		return false
	end
	local list: { number } = {}
	for at in pairs(slots) do
		table.insert(list, at)
	end
	local pace = Mouse.pace
	Mouse.pace = pace * EquipmentLayout.SWAP_MOUSE_PACE
	local queued = true
	for _, at in ipairs((Inventory.pattern(list))) do
		if slots[at] then
			local box = Inventory.box(at)
			if box == nil or not Mouse.click_async(box, nil, true) then
				queued = false
				break
			end
		end
	end
	Mouse.pace = pace
	if not queued then
		Mouse.cancel()
		return false
	end
	local stop = opts.stop
	while stop and Mouse.busy() do
		if stop() then
			Mouse.cancel()
			Log.log("EquipmentLayout", "equip: stopped")
			return false
		end
		sleep(EquipmentLayout.STOP_POLL_MS)
	end
	return Mouse.wait()
end

local function wait_worn(slots: { [number]: Slot })
	Widgets.wait_within(function()
		local worn = worn_by_slot()
		if worn == nil then
			return false
		end
		for _, slot in pairs(slots) do
			if not slot_matches(slot, worn[slot.slot]) then
				return false
			end
		end
		return true
	end, EquipmentLayout.CONFIRM_MS, EquipmentLayout.POLL_MS)
end

local function wear_items(layout: Layout, skip: { [number]: boolean }, opts: EquipOptions): boolean
	for attempt = 1, EquipmentLayout.WEAR_ATTEMPTS + 1 do
		local worn = worn_by_slot()
		if worn == nil then
			return false
		end
		local by_inventory_slot: { [number]: Slot } = {}
		for _, slot in ipairs(layout.slots) do
			if slot.mode ~= "item" or skip[slot.slot] or slot_matches(slot, worn[slot.slot]) then
				continue
			end
			if attempt > EquipmentLayout.WEAR_ATTEMPTS then
				Log.log("EquipmentLayout", `equip: couldn't wear {label(slot)}`)
				return false
			end
			local at = carried_at(slot)
			if at == nil then
				Log.log("EquipmentLayout", `equip: {label(slot)} isn't in the inventory`)
				return false
			end
			by_inventory_slot[at] = slot
		end
		if next(by_inventory_slot) == nil then
			return true
		end
		if not click_all(by_inventory_slot, opts) then
			return false
		end
		local after = opts.after_clicks
		if after then
			opts.after_clicks = nil
			after()
		end
		wait_worn(by_inventory_slot)
	end
	return false
end

local function wear(layout: Layout, skip: { [number]: boolean }, opts: EquipOptions): boolean
	if not wear_items(layout, skip, opts) then
		return false
	end
	for _, slot in ipairs(layout.slots) do
		if slot.mode ~= "empty" or skip[slot.slot] then
			continue
		end
		local again = worn_by_slot()
		if again and again[slot.slot] ~= nil and not take_off(slot) then
			return false
		end
	end
	return true
end

local function settle_ammo(layout: Layout): boolean
	local secondary = slot_of(layout, Wornitems.SECONDARY_AMMO)
	local worn = worn_by_slot()
	if worn == nil then
		return false
	end
	if secondary and counts(secondary, Wornitems.secondary_ammo_holder()) then
		if not slot_matches(secondary, worn[secondary.slot]) then
			if secondary.mode == "empty" then
				if not take_off(secondary) then
					return false
				end
			elseif secondary.mode == "item" then
				local ammo: Slot = { slot = Wornitems.AMMO, mode = "item", id = secondary.id }
				if not slot_matches(ammo, worn[Wornitems.AMMO]) then
					local at = carried_at(secondary)
					if at == nil then
						Log.log("EquipmentLayout", `equip: {label(secondary)} isn't in the inventory`)
						return false
					end
					if not Inventory.open() or not Inventory.click_slot(at) or not wait_slot(ammo) then
						Log.log("EquipmentLayout", `equip: couldn't wear {label(secondary)}`)
						return false
					end
				end
				if not Wornitems.swap_ammo() or not wait_slot(secondary) then
					Log.log("EquipmentLayout", `equip: couldn't move {label(secondary)} across`)
					return false
				end
			end
		end
	end
	local main = slot_of(layout, Wornitems.AMMO)
	worn = worn_by_slot()
	if main == nil or main.mode ~= "item" or worn == nil then
		return worn ~= nil
	end
	if not slot_matches(main, worn[main.slot]) and in_other_ammo_slot(main, worn) then
		if not Wornitems.swap_ammo() or not wait_slot(main) then
			Log.log("EquipmentLayout", `equip: couldn't swap {label(main)} back`)
			return false
		end
	end
	return true
end

function EquipmentLayout.equip(layout: Layout, options: EquipOptions?): boolean
	local opts: EquipOptions = table.clone(options or {})
	if EquipmentLayout.matches(layout) then
		return true
	end
	if Bankmain.is_open() then
		Log.log("EquipmentLayout", "equip: close the bank first")
		return false
	end
	local without_secondary = { [Wornitems.SECONDARY_AMMO] = true }
	if slot_of(layout, Wornitems.SECONDARY_AMMO) == nil or secondary_holder(layout) == nil then
		if not wear(layout, without_secondary, opts) then
			return false
		end
	elseif
		not wear(layout, { [Wornitems.AMMO] = true, [Wornitems.SECONDARY_AMMO] = true }, opts)
		or not settle_ammo(layout)
		or not wear(layout, without_secondary, opts)
	then
		return false
	end
	return EquipmentLayout.matches(layout) == true
end

function EquipmentLayout.spell(layout: Layout): Magic.Spell?
	local spell = layout.spell
	if spell == nil then
		return nil
	end
	return Magic.spell(spell.name, spell.book)
end

function EquipmentLayout.autocasts(layout: Layout): boolean
	return layout.spell ~= nil and layout.spell.autocast
end

function EquipmentLayout.set_autocast(layout: Layout, defensive: boolean?): boolean
	local spell = layout.spell
	if spell == nil or not spell.autocast then
		return true
	end
	return Combat.set_autocast(spell.name, defensive)
end

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
