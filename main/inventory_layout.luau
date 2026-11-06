--!strict
-- Inventory layouts: what an `inventory` form field gives a script (the user reads them from the client in the loader), checked against and filled from the bank, with the rune pouch's runes.
-- A layout is positional (each item has its slot), but what matters to the bank is how much of each item it holds: a stack's range, or the number of copies of an item that doesn't stack. Copies of a dose or charge item count by their family's accepted doses.
local Host = require("@lib/host")
local sleep = Host.sleep
local time = Host.time
type InventoryLayout = Host.InventoryLayout
type InventoryLayoutSlot = Host.InventoryLayoutSlot
type LayoutItem = Host.LayoutItem
type ItemSlot = Host.ItemSlot
local Bankmain = require("@lib/main/interfaces/mainscreen/bankmain")
local Inv = require("@lib/main/interfaces/inv")
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Item = require("@lib/utils/item")
local LayoutItems = require("@lib/main/layout_item")
local Log = require("@lib/utils/log")
local Runepouch = require("@lib/main/interfaces/mainscreen/runepouch")

local InventoryLayout = {}

export type Layout = InventoryLayout
export type Slot = InventoryLayoutSlot
export type Rune = LayoutItem

-- What the bank sees of a layout: one entry per item (a stack, or the copies of an item that doesn't stack), with what counts as it in the order to take it.
export type Entry = {
	items: { Item.Item },
	stackable: boolean,
	min: number,
	max: number,
	copies: number,
	label: string,
}

InventoryLayout.SIZE = 28
-- How long to wait for the pouch to take a stack of runes used on it, and between looks.
InventoryLayout.POUCH_TIMEOUT_MS = 2500
InventoryLayout.POLL_MS = 50

-- A layout of what the inventory holds now, with the pouch's runes when it holds a pouch. Nil when the inventory can't be read. `stackable` is only known for a stack of more than one, which wants exactly what it holds.
function InventoryLayout.from_client(name: string?): Layout?
	local items = Inventory.items()
	if items == nil then
		return nil
	end
	local slots: { Slot } = {}
	for _, s in ipairs(items) do
		if s.id ~= -1 then
			local stackable = s.quantity > 1
			local amount = if stackable then s.quantity else 1
			table.insert(slots, {
				slot = s.slot,
				id = s.id,
				ids = { s.id },
				name = s.name or "",
				stackable = stackable,
				min = amount,
				max = amount,
				locked = false,
			})
		end
	end
	local pouch: { Rune }? = nil
	local held = if Runepouch.held() then Runepouch.runes() else nil
	if held then
		local runes: { Rune } = {}
		for _, rune in ipairs(held) do
			table.insert(runes, {
				id = rune.id,
				ids = { rune.id },
				name = rune.name,
				stackable = true,
				min = rune.quantity,
				max = rune.quantity,
				locked = false,
			})
		end
		pouch = runes
	end
	return { name = name or "From client", slots = slots, pouch = pouch }
end

-- The layout's items as the bank sees them: slots that want the same thing make one entry, its `copies` the number of slots.
function InventoryLayout.entries(layout: Layout): { Entry }
	local by_key: { [string]: Entry } = {}
	local list: { Entry } = {}
	for _, slot in ipairs(layout.slots) do
		local items = LayoutItems.items(slot)
		local parts: { string } = {}
		for i, item in ipairs(items) do
			parts[i] = tostring(item)
		end
		local key = (if slot.stackable then "stack:" else "copies:") .. table.concat(parts, ",")
		local entry = by_key[key]
		if entry == nil then
			entry = {
				items = items,
				stackable = slot.stackable,
				min = slot.min,
				max = slot.max,
				copies = 0,
				label = if slot.name ~= "" then slot.name else `item {slot.id}`,
			}
			by_key[key] = entry
			table.insert(list, entry)
		end
		entry.copies += 1
	end
	return list
end

-- How many of each of the layout's runes the pouch still needs, by id (0: all the bank has); empty when the layout has no pouch.
local function pouch_missing(layout: Layout): { [number]: number }?
	local missing: { [number]: number } = {}
	if layout.pouch == nil then
		return missing
	end
	local held = Runepouch.runes()
	if held == nil then
		return nil
	end
	local have: { [number]: number } = {}
	for _, rune in ipairs(held) do
		have[rune.id] = rune.quantity
	end
	for _, rune in ipairs(layout.pouch :: { Rune }) do
		local need = LayoutItems.top_up(rune, have[rune.id] or 0)
		if need then
			missing[rune.id] = need
		end
	end
	return missing
end

-- Whether an entry holds: a stack in its range, or at least its number of copies. Nil when the inventory can't be read.
local function entry_matches(entry: Entry): boolean?
	if entry.stackable then
		local have = Inventory.count_ex(entry.items)
		return if have == nil then nil else LayoutItems.in_range(entry, have)
	end
	local have = Inventory.count(entry.items)
	return if have == nil then nil else have >= entry.copies
end

-- Whether the inventory holds the layout: each stack in its range, each other item's copies, and the pouch its runes. Nil when the inventory can't be read.
function InventoryLayout.matches(layout: Layout): boolean?
	for _, entry in ipairs(InventoryLayout.entries(layout)) do
		local ok = entry_matches(entry)
		if ok ~= true then
			return ok
		end
	end
	local missing = pouch_missing(layout)
	if missing == nil then
		return nil
	end
	return next(missing) == nil
end

-- Puts back what an entry holds beyond the layout: a stack over its `max`, or copies past its number, the doses taken last going first.
local function deposit_extra(entry: Entry): boolean
	if entry.stackable then
		local extra = LayoutItems.excess(entry, Inventory.count_ex(entry.items) or 0)
		return extra == 0 or Bankmain.deposit(entry.items, extra)
	end
	local extra = (Inventory.count(entry.items) or 0) - entry.copies
	for i = #entry.items, 1, -1 do
		if extra <= 0 then
			break
		end
		local held = Inventory.count(entry.items[i]) or 0
		if held > 0 then
			if not Bankmain.deposit(entry.items[i], math.min(held, extra)) then
				return false
			end
			extra = (Inventory.count(entry.items) or 0) - entry.copies
		end
	end
	return true
end

-- With the bank open, deposits everything that isn't in the layout (doses that aren't accepted included), and what the inventory holds beyond the layout's amounts. True when all of it went in.
function InventoryLayout.deposit_diff(layout: Layout): boolean
	if not Bankmain.is_open() then
		Log.log("InventoryLayout", "deposit_diff: the bank isn't open")
		return false
	end
	local entries = InventoryLayout.entries(layout)
	local keep: { Item.Item } = {}
	for _, entry in ipairs(entries) do
		for _, item in ipairs(entry.items) do
			table.insert(keep, item)
		end
	end
	if #keep == 0 then
		return Bankmain.deposit_inventory()
	end
	if not Bankmain.deposit_different(keep) then
		return false
	end
	for _, entry in ipairs(entries) do
		if not deposit_extra(entry) then
			return false
		end
	end
	return true
end

-- Takes what an entry is missing out of the bank: a stack up to its `max` (all of it for any amount), or the missing copies in the order of its items, each as far as the bank has it.
local function take(entry: Entry): boolean
	if entry.stackable then
		local amount = LayoutItems.top_up(entry, Inventory.count_ex(entry.items) or 0)
		return amount == nil or Bankmain.withdraw(entry.items, amount, false)
	end
	local need = entry.copies - (Inventory.count(entry.items) or 0)
	for _, item in ipairs(entry.items) do
		if need <= 0 then
			break
		end
		local stock = Bankmain.count_ex(item) or 0
		if stock > 0 then
			if not Bankmain.withdraw(item, math.min(need, stock), false) then
				return false
			end
			need = entry.copies - (Inventory.count(entry.items) or 0)
		end
	end
	return need <= 0
end

-- The layout's slot that holds a rune pouch, nil when it has none.
local function pouch_slot(layout: Layout): Slot?
	for _, slot in ipairs(layout.slots) do
		if table.find(Runepouch.POUCHES, slot.name) then
			return slot
		end
	end
	return nil
end

-- Puts the layout's runes in the pouch: takes the pouch (when the inventory holds none) and the missing runes out of the bank, closes it, uses each stack on the pouch (which takes the whole stack) and opens the bank again.
local function fill_pouch(layout: Layout): boolean
	local missing = pouch_missing(layout)
	if missing == nil then
		return false
	end
	if next(missing) == nil then
		return true
	end
	if not Runepouch.held() then
		local pouch = pouch_slot(layout)
		if pouch == nil or not Bankmain.withdraw(pouch.id, 1, false) then
			Log.log(
				"InventoryLayout",
				"withdraw: the layout has runes for a pouch, but no pouch is in the inventory or the bank"
			)
			return false
		end
	end
	for id, need in pairs(missing) do
		if not Bankmain.withdraw(id, need, false) then
			Log.log("InventoryLayout", `withdraw: couldn't take {need} of rune {id}`)
			return false
		end
	end
	-- neither the bank nor the pouch's own menu fills it: a rune stack is used on the pouch, with the bank closed
	if not Bankmain.close() then
		return false
	end
	for id in pairs(missing) do
		if not Inventory.combine(id, Runepouch.POUCHES) then
			Log.log("InventoryLayout", `withdraw: couldn't use rune {id} on the pouch`)
			Bankmain.open()
			return false
		end
		local deadline = time() + InventoryLayout.POUCH_TIMEOUT_MS
		local taken = false
		while time() < deadline do
			local left = pouch_missing(layout)
			if left and left[id] == nil then
				taken = true
				break
			end
			sleep(InventoryLayout.POLL_MS)
		end
		if not taken then
			Log.log("InventoryLayout", `withdraw: the pouch didn't take rune {id}`)
			Bankmain.open()
			return false
		end
	end
	return Bankmain.open()
end

-- With the bank open, makes the inventory hold the layout: deposits what doesn't belong (gear waiting to be worn included, so an equipment layout goes on first), fills the pouch, then takes each item the layout has more of than the inventory. True when the layout matches at the end.
function InventoryLayout.withdraw(layout: Layout): boolean
	if not Bankmain.is_open() then
		Log.log("InventoryLayout", "withdraw: the bank isn't open")
		return false
	end
	if InventoryLayout.matches(layout) then
		return true
	end
	if (Inventory.count_used() or 0) > 0 and not InventoryLayout.deposit_diff(layout) then
		return false
	end
	if not fill_pouch(layout) then
		return false
	end
	for _, entry in ipairs(InventoryLayout.entries(layout)) do
		if not take(entry) then
			Log.log("InventoryLayout", `withdraw: couldn't take {entry.label}`)
			return false
		end
	end
	return InventoryLayout.matches(layout) == true
end

-- Drags the items into the layout's slots, one slot at a time from the first. True when every item of the layout sits where it says, or there is nothing to move.
function InventoryLayout.reorder(layout: Layout): boolean
	local by_slot: { [number]: Slot } = {}
	for _, slot in ipairs(layout.slots) do
		by_slot[slot.slot] = slot
	end
	for destination = 0, InventoryLayout.SIZE - 1 do
		local wanted = by_slot[destination]
		if wanted == nil then
			continue
		end
		local held = Inventory.items()
		if held == nil then
			return false
		end
		local at_slot: { [number]: Inv.Slot } = {}
		for _, s in ipairs(held) do
			at_slot[s.slot] = s
		end
		-- an item already where the layout wants one like it stays there
		local function settled(at: number): boolean
			local here, now = by_slot[at], at_slot[at]
			return here ~= nil and now ~= nil and LayoutItems.counts_as(here, now.id, now.name)
		end
		if settled(destination) then
			continue
		end
		local from: number? = nil
		for _, at in ipairs(Inventory.indices_of(LayoutItems.items(wanted)) or {}) do
			-- the rest may sit anywhere, before this slot too when the layout leaves that one empty
			if at ~= destination and not settled(at) then
				from = at
				break
			end
		end
		if from == nil then
			Log.log("InventoryLayout", `reorder: nothing to put in slot {destination} ({wanted.name})`)
			return false
		end
		if not Inventory.move_slot(from, destination) then
			return false
		end
	end
	return true
end

return InventoryLayout
