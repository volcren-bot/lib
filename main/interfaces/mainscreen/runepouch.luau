--!strict
-- The rune pouch (group 190), opened by "Open" on a pouch in the inventory: the pouch's runes above, kept in client variables, and the inventory below. A rune's menu moves 1, 5, a typed amount or all of it.
local Host = require("@lib/host")
local enum_def = Host.enum_def
local sleep = Host.sleep
local time = Host.time
local varbit = Host.varbit
local widget_children = Host.widget_children
type Widget = Host.Widget
local Interact = require("@lib/main/interact")
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Item = require("@lib/utils/item")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")

local Runepouch = {}

-- A rune in the pouch and how many of it.
export type Rune = { id: number, name: string, quantity: number }
export type Amount = number | "All"

Runepouch.GROUP = 190
-- The frame (its children hold the close button), the pouch's runes and the inventory: each has a child per slot, by index.
Runepouch.FRAME = 1
Runepouch.POUCH = 4
Runepouch.INVENTORY = 7
Runepouch.OPTION = "Open"
Runepouch.CLOSE_OPTION = "Close"
-- The rune pouches, as the inventory names them; any of them holds the runes the varbits below describe.
Runepouch.POUCHES = table.freeze({ "Rune pouch", "Rune pouch (l)", "Divine rune pouch", "Divine rune pouch (l)" })
-- The varbits of each pouch slot's rune (a number the enum below maps to an item id) and amount.
Runepouch.RUNE_VARBITS = table.freeze({ 29, 1622, 1623, 14285 })
Runepouch.AMOUNT_VARBITS = table.freeze({ 1624, 1625, 1626, 14286 })
Runepouch.RUNES_ENUM = 982
Runepouch.TIMEOUT_MS = 2500
Runepouch.POLL_MS = 50

local function wait_until(check: () -> boolean): boolean
	local deadline = time() + Runepouch.TIMEOUT_MS
	while time() < deadline do
		if check() then
			return true
		end
		sleep(Runepouch.POLL_MS)
	end
	return false
end

local runes_by_index: { [number]: number }? = nil

local function rune_ids(): { [number]: number }?
	if runes_by_index ~= nil then
		return runes_by_index
	end
	local def = enum_def(Runepouch.RUNES_ENUM)
	if def == nil then
		return nil
	end
	local by_index: { [number]: number } = {}
	for _, entry in ipairs(def.entries) do
		if type(entry.value) == "number" then
			by_index[entry.key] = entry.value
		end
	end
	runes_by_index = by_index
	return by_index
end

-- Whether a pouch is in the inventory.
function Runepouch.held(): boolean
	return Inventory.contains_any(Runepouch.POUCHES)
end

-- The runes in the pouch now, from the client's variables (they keep their values whether or not a pouch is in the inventory). Nil when they can't be read.
function Runepouch.runes(): { Rune }?
	local by_index = rune_ids()
	if by_index == nil then
		return nil
	end
	local held: { Rune } = {}
	local ids: { number } = {}
	for i, rune_varbit in ipairs(Runepouch.RUNE_VARBITS) do
		local index = varbit(rune_varbit)
		local amount = varbit(Runepouch.AMOUNT_VARBITS[i])
		if index == nil or amount == nil then
			return nil
		end
		local id = by_index[index]
		if id and amount > 0 then
			table.insert(held, { id = id, quantity = amount, name = "" })
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

-- How many of a rune the pouch holds, by id or name.
function Runepouch.quantity(rune: Item.Item): number
	for _, held in ipairs(Runepouch.runes() or {}) do
		if held.id == rune or (type(rune) == "string" and string.lower(held.name) == string.lower(rune)) then
			return held.quantity
		end
	end
	return 0
end

function Runepouch.is_open(): boolean
	return Toplevel.is_open(Runepouch.GROUP)
end

-- Opens the interface from a pouch in the inventory. True when it is open.
function Runepouch.open(): boolean
	if Runepouch.is_open() then
		return true
	end
	if not Inventory.interact(Runepouch.POUCHES, Runepouch.OPTION) then
		return false
	end
	return wait_until(Runepouch.is_open)
end

local function close_button(): Widget?
	for _, child in ipairs(widget_children(Runepouch.GROUP, Runepouch.FRAME) or {}) do
		if child.action == Runepouch.CLOSE_OPTION then
			return child
		end
	end
	return nil
end

-- Closes the interface and waits for the inventory, which the interface took away and which comes back a moment later. True once it is usable again.
function Runepouch.close(): boolean
	if not Toplevel.close(Runepouch.GROUP, close_button) then
		return false
	end
	return wait_until(function()
		return Inventory.boxes() ~= nil
	end)
end

local function cell(component: number, index: number): Widget?
	for _, child in ipairs(widget_children(Runepouch.GROUP, component) or {}) do
		if child.index == index then
			return child
		end
	end
	return nil
end

-- The pouch slot (from 0, the cell's index) of a rune, by id or name.
local function pouch_index(rune: Item.Item): number?
	local by_index = rune_ids()
	if by_index == nil then
		return nil
	end
	for i, rune_varbit in ipairs(Runepouch.RUNE_VARBITS) do
		local index, amount = varbit(rune_varbit), varbit(Runepouch.AMOUNT_VARBITS[i])
		local id = if index then by_index[index] else nil
		if id and amount and amount > 0 then
			if id == rune then
				return i - 1
			end
			local names = if type(rune) == "string" then Item.names({ id }) else nil
			if names and names[1] and string.lower(names[1] :: string) == string.lower(rune :: string) then
				return i - 1
			end
		end
	end
	return nil
end

local function option_of(verb: string, amount: Amount): string?
	if amount == 1 or amount == 5 or amount == "All" then
		return `{verb}-{amount}`
	end
	return nil
end

-- With the interface open, takes a rune out to the inventory: 1, 5 or "All". True once the pouch holds less of it.
function Runepouch.withdraw(rune: Item.Item, amount: Amount): boolean
	local option = option_of("Withdraw", amount)
	local index = pouch_index(rune)
	local w = if index then cell(Runepouch.POUCH, index) else nil
	if option == nil or w == nil then
		return false
	end
	local before = Runepouch.quantity(rune)
	if not Interact.with(w, option, nil, false) then
		return false
	end
	return wait_until(function()
		return Runepouch.quantity(rune) < before
	end)
end

-- With the interface open, puts a rune from the inventory in the pouch: 1, 5 or "All". True once the pouch holds more of it.
function Runepouch.store(rune: Item.Item, amount: Amount): boolean
	local option = option_of("Store", amount)
	local index = Inventory.index_of(rune)
	local w = if index then cell(Runepouch.INVENTORY, index) else nil
	if option == nil or w == nil then
		return false
	end
	local before = Runepouch.quantity(rune)
	if not Interact.with(w, option, nil, false) then
		return false
	end
	return wait_until(function()
		return Runepouch.quantity(rune) > before
	end)
end

return Runepouch
