--!strict
-- Inventory layouts: what an `inventory` form field gives a script (the user reads them from the client in the loader), checked against and filled from the bank, with the rune pouch's runes.
-- A layout is positional (each item has its slot), but what matters to the bank is how much of each item it holds: a stack's quantity, or the number of copies of an item that doesn't stack.
local Host = require("@lib/host")
local enum_def = Host.enum_def
local sleep = Host.sleep
local time = Host.time
local varbit = Host.varbit
type InventoryLayout = Host.InventoryLayout
type InventoryLayoutSlot = Host.InventoryLayoutSlot
type LayoutItem = Host.LayoutItem
type ItemSlot = Host.ItemSlot
local Bankmain = require("@lib/main/interfaces/mainscreen/bankmain")
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Item = require("@lib/utils/item")
local Log = require("@lib/utils/log")

local InventoryLayout = {}

export type Layout = InventoryLayout
export type Slot = InventoryLayoutSlot
export type Rune = LayoutItem

InventoryLayout.SIZE = 28
-- The rune pouches, as the inventory names them; any of them holds the runes the varbits below describe.
InventoryLayout.POUCHES = table.freeze({ "Rune pouch", "Rune pouch (l)", "Divine rune pouch", "Divine rune pouch (l)" })
-- The varbits of each pouch slot's rune (a number the enum below maps to an item id) and amount.
InventoryLayout.POUCH_RUNE_VARBITS = table.freeze({ 29, 1622, 1623, 14285 })
InventoryLayout.POUCH_AMOUNT_VARBITS = table.freeze({ 1624, 1625, 1626, 14286 })
InventoryLayout.POUCH_RUNES_ENUM = 982
-- How long to wait for the pouch to take a stack of runes used on it, and between looks.
InventoryLayout.POUCH_TIMEOUT_MS = 2500
InventoryLayout.POLL_MS = 50

-- A layout of what the inventory holds now, with the pouch's runes when it holds a pouch. Nil when the inventory can't be read. `stackable` is only known for a stack of more than one.
function InventoryLayout.from_client(name: string?): Layout?
	local items = Inventory.items()
	if items == nil then
		return nil
	end
	local slots: { Slot } = {}
	for _, s in ipairs(items) do
		if s.id ~= -1 then
			table.insert(slots, {
				slot = s.slot,
				id = s.id,
				quantity = s.quantity,
				name = s.name or "",
				stackable = s.quantity > 1,
			})
		end
	end
	local pouch = if Inventory.contains_any(InventoryLayout.POUCHES) then InventoryLayout.pouch_runes() else nil
	return { name = name or "From client", slots = slots, pouch = pouch }
end

-- How much of each item the layout holds, by id: a stack's quantity, else the number of copies.
function InventoryLayout.wanted(layout: Layout): { [number]: number }
	local wanted: { [number]: number } = {}
	for _, slot in ipairs(layout.slots) do
		wanted[slot.id] = (wanted[slot.id] or 0) + (if slot.stackable then slot.quantity else 1)
	end
	return wanted
end

-- The runes in the rune pouch now, from the client's variables (whether or not a pouch is in the inventory). Nil when they can't be read.
local pouch_by_index: { [number]: number }? = nil

function InventoryLayout.pouch_runes(): { Rune }?
	local by_index = pouch_by_index
	if by_index == nil then
		local runes = enum_def(InventoryLayout.POUCH_RUNES_ENUM)
		if runes == nil then
			return nil
		end
		by_index = {}
		for _, entry in ipairs(runes.entries) do
			if type(entry.value) == "number" then
				by_index[entry.key] = entry.value
			end
		end
		pouch_by_index = by_index
	end
	local held: { Rune } = {}
	local ids: { number } = {}
	for i, rune_varbit in ipairs(InventoryLayout.POUCH_RUNE_VARBITS) do
		local index = varbit(rune_varbit)
		local amount = varbit(InventoryLayout.POUCH_AMOUNT_VARBITS[i])
		if index == nil or amount == nil then
			return nil
		end
		local id = by_index[index]
		if id and amount > 0 then
			table.insert(held, { id = id, quantity = amount, name = "", stackable = true })
			table.insert(ids, id)
		end
	end
	local names = if #ids > 0 then Item.names(ids) else nil
	if names then
		for i, rune in ipairs(held) do
			rune.name = names[i] or ""
		end
	end
	return held
end

-- How many of each of the layout's runes the pouch still needs, by id; empty when the layout has no pouch.
local function pouch_missing(layout: Layout): { [number]: number }?
	local missing: { [number]: number } = {}
	if layout.pouch == nil then
		return missing
	end
	local held = InventoryLayout.pouch_runes()
	if held == nil then
		return nil
	end
	local have: { [number]: number } = {}
	for _, rune in ipairs(held) do
		have[rune.id] = rune.quantity
	end
	for _, rune in ipairs(layout.pouch :: { Rune }) do
		local need = rune.quantity - (have[rune.id] or 0)
		if need > 0 then
			missing[rune.id] = need
		end
	end
	return missing
end

-- Whether the inventory holds at least the layout's amount of each of its items, and the pouch its runes. Nil when the inventory can't be read.
function InventoryLayout.matches(layout: Layout): boolean?
	for id, amount in pairs(InventoryLayout.wanted(layout)) do
		local have = Inventory.count_ex(id)
		if have == nil then
			return nil
		end
		if have < amount then
			return false
		end
	end
	local missing = pouch_missing(layout)
	if missing == nil then
		return nil
	end
	return next(missing) == nil
end

-- With the bank open, deposits everything that isn't in the layout, and what the inventory holds beyond the layout's amounts. True when all of it went in.
function InventoryLayout.deposit_diff(layout: Layout): boolean
	if not Bankmain.is_open() then
		Log.log("InventoryLayout", "deposit_diff: the bank isn't open")
		return false
	end
	local wanted = InventoryLayout.wanted(layout)
	local keep: { Item.Item } = {}
	for id in pairs(wanted) do
		table.insert(keep, id)
	end
	if #keep == 0 then
		return Bankmain.deposit_inventory()
	end
	if not Bankmain.deposit_different(keep) then
		return false
	end
	for id, amount in pairs(wanted) do
		local have = Inventory.count_ex(id) or 0
		if have > amount and not Bankmain.deposit(id, have - amount) then
			return false
		end
	end
	return true
end

-- Puts the layout's runes in the pouch: takes the missing ones out of the bank, closes it, uses each stack on the pouch (which takes the whole stack) and opens the bank again.
local function fill_pouch(layout: Layout): boolean
	local missing = pouch_missing(layout)
	if missing == nil then
		return false
	end
	if next(missing) == nil then
		return true
	end
	if not Inventory.contains_any(InventoryLayout.POUCHES) then
		Log.log("InventoryLayout", "withdraw: the layout has runes for a pouch, but the inventory holds no pouch")
		return false
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
		if not Inventory.combine(id, InventoryLayout.POUCHES) then
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

-- With the bank open, makes the inventory hold the layout: deposits what doesn't belong, fills the pouch, then takes each item the layout has more of than the inventory. True when the layout matches at the end.
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
	for id, amount in pairs(InventoryLayout.wanted(layout)) do
		local need = amount - (Inventory.count_ex(id) or 0)
		if need > 0 and not Bankmain.withdraw(id, need, false) then
			Log.log("InventoryLayout", `withdraw: couldn't take {need} of item {id}`)
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
		local now = Inventory.item(destination)
		if now and now.id == wanted.id then
			continue
		end
		local from: number? = nil
		for _, at in ipairs(Inventory.indices_of(wanted.id) or {}) do
			-- an item already where the layout wants it stays there
			local here = by_slot[at]
			if at > destination and not (here and here.id == wanted.id) then
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
