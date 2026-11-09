--!strict
local Host = require("@lib/host")
local enum_def = Host.enum_def
local varbit = Host.varbit
local widget_children = Host.widget_children
type Widget = Host.Widget
local Interact = require("@lib/main/interact")
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Item = require("@lib/utils/item")
type Item = Item.Item
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Widgets = require("@lib/main/interfaces/widgets")

local Runepouch = {}

export type Rune = { id: number, name: string, quantity: number }
export type Amount = number | "All"

Runepouch.GROUP = 190
Runepouch.FRAME = 1
Runepouch.POUCH = 4
Runepouch.INVENTORY = 7
Runepouch.OPTION = "Open"
Runepouch.CLOSE_OPTION = "Close"
Runepouch.POUCHES = table.freeze({ "Rune pouch", "Rune pouch (l)", "Divine rune pouch", "Divine rune pouch (l)" })
Runepouch.RUNE_VARBITS = table.freeze({ 29, 1622, 1623, 14285 })
Runepouch.AMOUNT_VARBITS = table.freeze({ 1624, 1625, 1626, 14286 })
Runepouch.RUNES_ENUM = 982
Runepouch.TIMEOUT_MS = 2500
Runepouch.POLL_MS = 50

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

function Runepouch.held(): boolean
	return Inventory.contains_any(Runepouch.POUCHES)
end

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

function Runepouch.quantity(rune: Item): number
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

function Runepouch.open(): boolean
	if Runepouch.is_open() then
		return true
	end
	if not Inventory.interact(Runepouch.POUCHES, Runepouch.OPTION) then
		return false
	end
	return Widgets.wait_within(Runepouch.is_open, Runepouch.TIMEOUT_MS, Runepouch.POLL_MS)
end

local function close_button(): Widget?
	for _, child in ipairs(widget_children(Runepouch.GROUP, Runepouch.FRAME) or {}) do
		if child.action == Runepouch.CLOSE_OPTION then
			return child
		end
	end
	return nil
end

function Runepouch.close(): boolean
	if not Toplevel.close(Runepouch.GROUP, close_button) then
		return false
	end
	return Widgets.wait_within(function()
		return Inventory.boxes() ~= nil
	end, Runepouch.TIMEOUT_MS, Runepouch.POLL_MS)
end

local function cell(component: number, index: number): Widget?
	for _, child in ipairs(widget_children(Runepouch.GROUP, component) or {}) do
		if child.index == index then
			return child
		end
	end
	return nil
end

local function pouch_index(rune: Item): number?
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

local function transfer(w: Widget?, option: string?, rune: Item, stored: boolean): boolean
	if option == nil or w == nil then
		return false
	end
	local before = Runepouch.quantity(rune)
	if not Interact.with(w, option, nil, false) then
		return false
	end
	return Widgets.wait_within(function()
		local now = Runepouch.quantity(rune)
		return if stored then now > before else now < before
	end, Runepouch.TIMEOUT_MS, Runepouch.POLL_MS)
end

function Runepouch.withdraw(rune: Item, amount: Amount): boolean
	local option = option_of("Withdraw", amount)
	local index = pouch_index(rune)
	return transfer(if index then cell(Runepouch.POUCH, index) else nil, option, rune, false)
end

function Runepouch.store(rune: Item, amount: Amount): boolean
	local option = option_of("Store", amount)
	local index = Inventory.index_of(rune)
	return transfer(if index then cell(Runepouch.INVENTORY, index) else nil, option, rune, true)
end

return Runepouch
