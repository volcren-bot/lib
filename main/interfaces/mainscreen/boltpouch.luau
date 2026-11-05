--!strict
-- The bolt pouch (group 433), opened by "Open" on the pouch in the inventory: four stored stacks of bolts, kept in client variables, and the worn ammo. The fourth stack is the extra ammo that the worn items tab offers as a second ammo slot.
-- The interface sits over the side panel, in a slot `Toplevel` doesn't track, so it has its own `is_open` and `close`.
local Host = require("@lib/host")
local enum_def = Host.enum_def
local item_container = Host.item_container
local sleep = Host.sleep
local sub_interfaces = Host.sub_interfaces
local time = Host.time
local varbit = Host.varbit
local widget = Host.widget
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Item = require("@lib/utils/item")
type Item = Item.Item
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Random = require("@lib/utils/math/random")

local Boltpouch = {}

export type Bolt = {
	slot: number,
	id: number,
	quantity: number,
}

Boltpouch.ITEM = 9433
Boltpouch.GROUP = 433
Boltpouch.CLOSE = 21
Boltpouch.OPTION = "Open"
-- The interface's rows: the worn ammo, then the four stored stacks (the last is the extra ammo).
Boltpouch.CURRENT = 0
Boltpouch.EXTRA = 4
Boltpouch.ROWS = table.freeze({ [0] = 20, [1] = 6, [2] = 9, [3] = 12, [4] = 16 })
-- The varbits of each stored stack's bolt (a number the enum below maps to an item id) and amount.
Boltpouch.BOLT_VARBITS = table.freeze({ 2473, 2474, 2475, 2476 })
Boltpouch.AMOUNT_VARBITS = table.freeze({ 2469, 2470, 2471, 2472 })
Boltpouch.BOLTS_ENUM = 336
Boltpouch.WORN_CONTAINER = 94
Boltpouch.WORN_AMMO_SLOT = 13
Boltpouch.TIMEOUT_MS = 2500
-- A row's drag only starts after 5 client cycles held: let go sooner and it is a click, which takes the stack out.
Boltpouch.DRAG_HOLD_MS = table.freeze({ 130, 220 })
Boltpouch.DRAG_DROP_MS = table.freeze({ 60, 130 })
Boltpouch.POLL_MS = 50

local function wait_until(check: () -> boolean): boolean
	local deadline = time() + Boltpouch.TIMEOUT_MS
	while time() < deadline do
		if check() then
			return true
		end
		sleep(Boltpouch.POLL_MS)
	end
	return false
end

local bolts_by_index: { [number]: number }? = nil

local function bolts(): { [number]: number }?
	if bolts_by_index ~= nil then
		return bolts_by_index
	end
	local def = enum_def(Boltpouch.BOLTS_ENUM)
	if def == nil then
		return nil
	end
	local by_index: { [number]: number } = {}
	for _, entry in ipairs(def.entries) do
		if type(entry.value) == "number" then
			by_index[entry.key] = entry.value
		end
	end
	bolts_by_index = by_index
	return by_index
end

-- Whether the pouch is in the inventory.
function Boltpouch.held(): boolean
	return Inventory.contains(Boltpouch.ITEM)
end

-- Whether the pouch can store the item. Nil when the game files can't be read.
function Boltpouch.accepts(id: number): boolean?
	local by_index = bolts()
	if by_index == nil then
		return nil
	end
	for _, bolt in pairs(by_index) do
		if bolt == id then
			return true
		end
	end
	return false
end

-- What a row holds, from the client's variables, so the interface needn't be open. Nil when it is empty or can't be read.
function Boltpouch.slot(slot: number): Bolt?
	if slot == Boltpouch.CURRENT then
		for _, item in ipairs(item_container(Boltpouch.WORN_CONTAINER) or {}) do
			if item.slot == Boltpouch.WORN_AMMO_SLOT and item.id ~= -1 then
				return { slot = slot, id = item.id, quantity = item.quantity }
			end
		end
		return nil
	end
	local by_index = bolts()
	local bolt_varbit, amount_varbit = Boltpouch.BOLT_VARBITS[slot], Boltpouch.AMOUNT_VARBITS[slot]
	if by_index == nil or bolt_varbit == nil or amount_varbit == nil then
		return nil
	end
	local index, amount = varbit(bolt_varbit), varbit(amount_varbit)
	if index == nil or amount == nil or amount <= 0 then
		return nil
	end
	local id = by_index[index]
	if id == nil then
		return nil
	end
	return { slot = slot, id = id, quantity = amount }
end

-- The stored stacks that hold something, not the worn ammo.
function Boltpouch.stored(): { Bolt }
	local held: { Bolt } = {}
	for slot = 1, Boltpouch.EXTRA do
		local bolt = Boltpouch.slot(slot)
		if bolt then
			table.insert(held, bolt)
		end
	end
	return held
end

function Boltpouch.is_open(): boolean
	for _, open in ipairs(sub_interfaces() or {}) do
		if open.group == Boltpouch.GROUP then
			return true
		end
	end
	return false
end

-- Opens the interface from the pouch in the inventory. True when it is open.
function Boltpouch.open(): boolean
	if Boltpouch.is_open() then
		return true
	end
	if not Inventory.interact(Boltpouch.ITEM, Boltpouch.OPTION) then
		return false
	end
	return wait_until(Boltpouch.is_open)
end

function Boltpouch.close(): boolean
	if not Boltpouch.is_open() then
		return true
	end
	local button = widget(Boltpouch.GROUP, Boltpouch.CLOSE)
	if button == nil then
		return false
	end
	Mouse.click(button)
	return wait_until(function()
		return not Boltpouch.is_open()
	end)
end

-- Uses an item on the pouch, with the inventory showing. The client picks the stored stack: an empty extra ammo row fills before the others. True once the pouch took some.
function Boltpouch.store(item: Item): boolean
	local before = Inventory.quantity(item)
	if before == nil or before <= 0 or not Inventory.combine(item, Boltpouch.ITEM) then
		return false
	end
	return wait_until(function()
		local now = Inventory.quantity(item)
		return now ~= nil and now < before
	end)
end

-- With the interface open, clicks a row to take its stack out: stored bolts or the worn ammo go to the inventory. True once the row is empty.
function Boltpouch.remove(slot: number): boolean
	local row = Boltpouch.ROWS[slot]
	local w = if row then widget(Boltpouch.GROUP, row) else nil
	if w == nil or Boltpouch.slot(slot) == nil then
		return false
	end
	-- the row's only option carries the item's name, so it can't be matched by option
	Mouse.click(w)
	return wait_until(function()
		return Boltpouch.slot(slot) == nil
	end)
end

-- With the interface open, drags one row's stack onto another; the client swaps two stacks of different bolts. True once the stack is there; a stack the client won't put there just fails.
function Boltpouch.move(from: number, to: number): boolean
	local from_row, to_row = Boltpouch.ROWS[from], Boltpouch.ROWS[to]
	local source = Boltpouch.slot(from)
	local a = if from_row then widget(Boltpouch.GROUP, from_row) else nil
	local b = if to_row then widget(Boltpouch.GROUP, to_row) else nil
	if source == nil or a == nil or b == nil then
		return false
	end
	Mouse.move(a)
	Mouse.hold()
	Random.sleep(Boltpouch.DRAG_HOLD_MS[1], Boltpouch.DRAG_HOLD_MS[2], "left")
	Mouse.move(b)
	Random.sleep(Boltpouch.DRAG_DROP_MS[1], Boltpouch.DRAG_DROP_MS[2], "left")
	Mouse.release()
	local moved = wait_until(function()
		local now = Boltpouch.slot(to)
		return now ~= nil and now.id == source.id
	end)
	if not moved then
		Log.log("Boltpouch", `row {from} didn't move to row {to}`)
	end
	return moved
end

return Boltpouch
