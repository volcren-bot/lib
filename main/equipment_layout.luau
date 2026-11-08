--!strict
-- Equipment layouts: what an `equipment` form field gives a script (the user reads them from the client in the loader), checked against and put on with the worn items, the inventory and the bank.
-- A slot wants an item (by its ids, or a dose or charge item by its accepted doses), nothing (`empty`) or doesn't care (`any`). Nothing here guesses an id: an item is the id the client holds, found in the inventory and the bank by its ids or by its name, since some items are worn under another id than they are held (graceful pieces). A worn stack (ammo) wants at least its `min`; a worn stack over its `max` stays, since only all of it can be taken off.
-- The secondary ammo slot only exists with a bolt pouch or Dizana's quiver, which a layout can't promise, so without one (or when a pouch can't store the item) the slot is ignored.
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
local LayoutItems = require("@lib/main/layout_item")
local Log = require("@lib/utils/log")
local Magic = require("@lib/main/interfaces/gametabs/magic")
local Mouse = require("@lib/utils/input/mouse")
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

local EquipmentLayout = {}

export type Layout = EquipmentLayout
export type Slot = EquipmentLayoutSlot

-- How long to wait for the worn items to change after a click, and between looks.
EquipmentLayout.EQUIP_TIMEOUT_MS = 2500
EquipmentLayout.POLL_MS = 50
-- After clicking the items: how long they get to show as worn, and how many rounds of clicks they get.
EquipmentLayout.CONFIRM_MS = 1200
EquipmentLayout.WEAR_ATTEMPTS = 3
-- How many times faster the mouse moves while clicking the items of a swap (`Mouse.pace`).
EquipmentLayout.SWAP_MOUSE_PACE = 1.2
-- What `equip` does besides the swap: `stop` is asked while the clicks run and drops them once true (the swap fails);
-- `after_clicks` runs once, as soon as the clicks are in, while equip waits for them to show as worn (an async hover of
-- what comes next).
export type EquipOptions = { stop: (() -> boolean)?, after_clicks: (() -> ())? }

-- How often `equip`'s `stop` is asked while the clicks run.
EquipmentLayout.STOP_POLL_MS = 30

-- The worn items slots a layout lists, in the container's order, then the secondary ammo.
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

-- What gives the secondary ammo slot once the layout is on: a quiver it wears, else what the player carries.
local function secondary_holder(layout: Layout): Wornitems.SecondaryHolder?
	local cape = slot_of(layout, Wornitems.CAPE)
	if cape and cape.id and Wornitems.is_quiver(cape.id) then
		return "quiver"
	end
	return Wornitems.secondary_ammo_holder()
end

-- Whether a slot's rule counts: every slot but the secondary ammo, which needs a holder that can take its item.
local function counts(slot: Slot, holder: Wornitems.SecondaryHolder?): boolean
	if slot.slot ~= Wornitems.SECONDARY_AMMO then
		return true
	end
	if holder == nil then
		return false
	end
	return slot.mode ~= "item" or Wornitems.secondary_ammo_accepts(holder, slot.id :: number)
end

-- What to look for in the inventory or the bank for a slot's item, in the order to take it: its accepted doses by name, else its ids and then its name, since some items are worn under another id than they are held (graceful pieces).
local function wanted(slot: Slot): { Item.Item }
	local items = LayoutItems.items(slot)
	if slot.doses == nil and slot.name and slot.name ~= "" then
		table.insert(items, slot.name)
	end
	return items
end

-- The first inventory slot holding the slot's item, taking its items in order.
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

-- A layout of what is worn now: every slot its item, or `empty` (`any` for a secondary ammo slot nothing gives). Nil when the worn items can't be read. `stackable` is only known for a stack of more than one.
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

-- Whether a slot's rule holds for what is worn in it: its item, and a stack at least its `min`.
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

-- Whether every slot of the layout holds: its item worn (a stack at least its `min`), or nothing worn where it wants nothing. A secondary ammo slot that doesn't count is ignored. Nil when the worn items can't be read.
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

-- Whether the item of an ammo slot is worn in the other ammo slot, a swap away.
local function in_other_ammo_slot(slot: Slot, worn: { [number]: ItemSlot }): boolean
	local other = if slot.slot == Wornitems.AMMO
		then Wornitems.SECONDARY_AMMO
		elseif slot.slot == Wornitems.SECONDARY_AMMO then Wornitems.AMMO
		else nil
	local item = if other then worn[other] else nil
	return item ~= nil and LayoutItems.counts_as(slot, item.id, nil)
end

-- How much of a slot's stack the player has: worn there and carried.
local function stack_held(slot: Slot, worn: { [number]: ItemSlot }): number
	local on = worn[slot.slot]
	local wearing = if on and LayoutItems.counts_as(slot, on.id, nil) then on.quantity else 0
	return wearing + (Inventory.count_ex(wanted(slot)) or 0)
end

-- Whether the worn items and the inventory fall short of a slot: its item is in neither, or a stack is under its `min` with both.
local function short(slot: Slot, worn: { [number]: ItemSlot }): boolean
	if slot.stackable then
		return not in_other_ammo_slot(slot, worn) and LayoutItems.top_up(slot, stack_held(slot, worn)) ~= nil
	end
	return not slot_matches(slot, worn[slot.slot])
		and not in_other_ammo_slot(slot, worn)
		and not Inventory.contains_any(wanted(slot))
end

-- The slots whose item is neither worn nor in the inventory, or whose stack is under its `min` with both: what has to come out of the bank. A secondary ammo slot that doesn't count isn't listed.
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

-- Takes a missing slot's item out of the bank: a stack up to its `max` (all of it for any amount), else one, of the first of its items the bank has.
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

-- With the bank open, withdraws what each missing slot needs. True when none is missing afterwards.
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

-- Queues a click on each inventory slot in the order `Inventory.pattern` gives, with no wait between them, and waits for the mouse to finish.
local function click_all(slots: { [number]: Slot }, opts: EquipOptions): boolean
	if not Inventory.open() then
		return false
	end
	local list: { number } = {}
	for at in pairs(slots) do
		table.insert(list, at)
	end
	-- each queued move takes the pace it was queued with
	local pace = Mouse.pace
	Mouse.pace = pace * EquipmentLayout.SWAP_MOUSE_PACE
	local queued = true
	for _, at in ipairs((Inventory.pattern(list))) do
		if slots[at] then
			local box = Inventory.box(at)
			-- forced: the queue runs later, so where the mouse is now says nothing about where it will be
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

-- Waits for the items to show as worn; the game applies a click on its next tick.
local function wait_worn(slots: { [number]: Slot })
	local deadline = time() + EquipmentLayout.CONFIRM_MS
	while time() < deadline do
		local worn = worn_by_slot()
		local done = worn ~= nil
		for _, slot in pairs(slots) do
			if worn == nil or not slot_matches(slot, worn[slot.slot]) then
				done = false
				break
			end
		end
		if done then
			return
		end
		sleep(EquipmentLayout.POLL_MS)
	end
end

-- Wears the items of the slots not in `skip`, then looks at what is worn and clicks again whatever didn't change.
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
		-- the clicks are in: what comes next can start while they show as worn (once per swap)
		if opts.after_clicks then
			local after = opts.after_clicks
			opts.after_clicks = nil
			after()
		end
		wait_worn(by_inventory_slot)
	end
	return false
end

-- Wears the items of the slots not in `skip` from the inventory, then takes off what is worn where they want nothing.
local function wear(layout: Layout, skip: { [number]: boolean }, opts: EquipOptions): boolean
	if not wear_items(layout, skip, opts) then
		return false
	end
	for _, slot in ipairs(layout.slots) do
		if slot.mode ~= "empty" or skip[slot.slot] then
			continue
		end
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
	return true
end

-- Gets the secondary ammo slot's rule to hold. An item only gets there through the worn ammo slot: it is worn, then swapped across, which leaves the slot's old ammo worn for `wear` to replace. Afterwards the worn ammo slot's item, if the second slot holds it, is swapped back.
local function settle_ammo(layout: Layout): boolean
	local secondary = slot_of(layout, Wornitems.SECONDARY_AMMO)
	local worn = worn_by_slot()
	if worn == nil then
		return false
	end
	if secondary and counts(secondary, Wornitems.secondary_ammo_holder()) then
		if not slot_matches(secondary, worn[secondary.slot]) then
			if secondary.mode == "empty" then
				if Inventory.is_full() then
					Log.log("EquipmentLayout", `equip: no room to take off {label(secondary)}`)
					return false
				end
				if not Wornitems.remove(secondary.slot) or not wait_slot(secondary) then
					Log.log("EquipmentLayout", `equip: couldn't take off {label(secondary)}`)
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

-- Wears each of the layout's items from the inventory, in the order `Inventory.pattern` gives, then takes off what is worn where the layout wants nothing. With a secondary ammo slot in play the ammo comes last, since filling that slot goes through the worn ammo slot. The bank must be closed (a click in the inventory would deposit). True when the layout matches afterwards.
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
		return EquipmentLayout.matches(layout) == true
	end
	if
		not wear(layout, { [Wornitems.AMMO] = true, [Wornitems.SECONDARY_AMMO] = true }, opts)
		or not settle_ammo(layout)
		or not wear(layout, without_secondary, opts)
	then
		return false
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
