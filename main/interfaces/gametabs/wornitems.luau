--!strict
local Host = require("@lib/host")
local item_container = Host.item_container
local item_params = Host.item_params
local varp = Host.varp
local widget = Host.widget
type ItemSlot = Host.ItemSlot
type Widget = Host.Widget
type MenuEntry = Host.MenuEntry
local Item = require("@lib/utils/item")
type Item = Item.Item
local Boltpouch = require("@lib/main/interfaces/mainscreen/boltpouch")
local Interact = require("@lib/main/interact")
local Inv = require("@lib/main/interfaces/inv")
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")
local Widgets = require("@lib/main/interfaces/widgets")

local CONTAINER = 94
local SIZE = 14
local GROUP = 387

local SLOT_CHILDREN: { [number]: number } = {
	[0] = 15,
	[1] = 16,
	[2] = 17,
	[3] = 18,
	[4] = 19,
	[5] = 20,
	[7] = 21,
	[9] = 22,
	[10] = 23,
	[12] = 24,
	[13] = 25,
}

local function owns(slot: number): (MenuEntry) -> boolean
	local child = SLOT_CHILDREN[slot]
	return function(entry: MenuEntry): boolean
		return child ~= nil and entry.id == GROUP * 65536 + child
	end
end

local items = Inv.new(CONTAINER, SIZE, {
	open = function()
		return SidePanels.open(SidePanels.WORNITEMS)
	end,
	boxes = function(): { [number]: Widget }?
		local by_slot: { [number]: Widget } = {}
		for slot, child in pairs(SLOT_CHILDREN) do
			local w = widget(GROUP, child)
			if w then
				by_slot[slot] = w
			end
		end
		if next(by_slot) == nil then
			return nil
		end
		return by_slot
	end,
	owns = owns,
})

local Wornitems = {
	CONTAINER = CONTAINER,
	SIZE = SIZE,
	GROUP = GROUP,
	slots = items.slots,
	items = items.items,
	item = items.item,
	indices_of = items.indices_of,
	index_of = items.index_of,
	find = items.find,
	contains = items.contains,
	contains_any = items.contains_any,
	contains_all = items.contains_all,
	find_different = items.find_different,
	contains_different = items.contains_different,
	count = items.count,
	count_ex = items.count_ex,
	wait_count = items.wait_count,
	quantity = items.quantity,
	slot_quantity = items.slot_quantity,
	used = items.used,
	is_used = items.is_used,
	is_empty = items.is_empty,
	count_used = items.count_used,
	wait_used = items.wait_used,
	open = items.open,
	boxes = items.boxes,
	box = items.box,
	slot_at = items.slot_at,
	hover_slot = items.hover_slot,
	click_slot = items.click_slot,
	interact_slot = items.interact_slot,
	hover = items.hover,
	click = items.click,
	interact = items.interact,
}

Wornitems.HEAD = 0
Wornitems.CAPE = 1
Wornitems.AMULET = 2
Wornitems.WEAPON = 3
Wornitems.BODY = 4
Wornitems.SHIELD = 5
Wornitems.LEGS = 7
Wornitems.HANDS = 9
Wornitems.FEET = 10
Wornitems.RING = 12
Wornitems.AMMO = 13
Wornitems.SECONDARY_AMMO = 14

local NAMES: { [number]: string } = {
	[0] = "head",
	[1] = "cape",
	[2] = "amulet",
	[3] = "weapon",
	[4] = "body",
	[5] = "shield",
	[7] = "legs",
	[9] = "hands",
	[10] = "feet",
	[12] = "ring",
	[13] = "ammo",
	[14] = "secondary ammo",
}

export type Button = { child: number, option: string }

Wornitems.BUTTONS = table.freeze({
	stats = table.freeze({ child = 1, option = "View equipment stats" }),
	prices = table.freeze({ child = 3, option = "View guide prices" }),
	death = table.freeze({ child = 5, option = "View items kept on death" }),
	follower = table.freeze({ child = 7, option = "Call follower" }),
}) :: { [string]: Button }

function Wornitems.slot_name(slot: number): string?
	return NAMES[slot]
end

function Wornitems.slot(name: number | string): number?
	if type(name) == "number" then
		return if NAMES[name] then name else nil
	end
	local wanted = string.lower(name)
	for slot, n in pairs(NAMES) do
		if n == wanted then
			return slot
		end
	end
	return nil
end

function Wornitems.worn(): { [string]: ItemSlot }?
	local items = item_container(Wornitems.CONTAINER)
	local worn: { [string]: ItemSlot } = {}
	for _, item in ipairs(items or {}) do
		local name: string? = NAMES[item.slot]
		if name and item.id ~= -1 then
			worn[name] = item
		end
	end
	return worn
end

function Wornitems.is_wearing(item: Item): boolean
	return Wornitems.contains(item)
end

function Wornitems.is_open(): boolean
	return SidePanels.is_open(SidePanels.WORNITEMS)
end

export type SecondaryHolder = "quiver" | "pouch"

Wornitems.INVENTORY_CONTAINER = 93
Wornitems.QUIVER_PARAM = 1910
Wornitems.QUIVER_AMMO_VARP = 4142
Wornitems.QUIVER_AMOUNT_VARP = 4141
Wornitems.SECONDARY_CHILD = table.freeze({ quiver = 28, pouch = 30 })
Wornitems.SWAP_OPTION = table.freeze({ quiver = "Swap", pouch = "Wear" })
Wornitems.QUIVER_FILL_OPTION = "Fill"
Wornitems.QUIVER_REMOVE_OPTION = "Quiver-Remove"
Wornitems.SWAP_TIMEOUT_MS = 2500
Wornitems.POLL_MS = 50

local quiver_items: { [number]: boolean } = {}

local function learn_quivers(ids: { number })
	local unknown: { number } = {}
	for _, id in ipairs(ids) do
		if quiver_items[id] == nil then
			table.insert(unknown, id)
		end
	end
	if #unknown == 0 then
		return
	end
	local params = item_params(unknown)
	if params == nil then
		return
	end
	for i, id in ipairs(unknown) do
		local item = params[i]
		local value = if item then item[Wornitems.QUIVER_PARAM] else nil
		quiver_items[id] = type(value) == "number" and value > 0
	end
end

function Wornitems.is_quiver(id: number): boolean
	learn_quivers({ id })
	return quiver_items[id] == true
end

function Wornitems.secondary_ammo_holder(): SecondaryHolder?
	local ids: { number } = {}
	local has_pouch = false
	for _, item in ipairs(item_container(Wornitems.CONTAINER) or {}) do
		if item.slot == Wornitems.CAPE and item.id ~= -1 then
			table.insert(ids, item.id)
		end
	end
	for _, item in ipairs(item_container(Wornitems.INVENTORY_CONTAINER) or {}) do
		if item.id ~= -1 then
			table.insert(ids, item.id)
			has_pouch = has_pouch or item.id == Boltpouch.ITEM
		end
	end
	learn_quivers(ids)
	for _, id in ipairs(ids) do
		if quiver_items[id] then
			return "quiver"
		end
	end
	return if has_pouch then "pouch" else nil
end

function Wornitems.secondary_ammo_accepts(holder: SecondaryHolder, id: number): boolean
	return holder == "quiver" or Boltpouch.accepts(id) ~= false
end

function Wornitems.secondary_ammo(): ItemSlot?
	local holder = Wornitems.secondary_ammo_holder()
	if holder == "quiver" then
		local id, amount = varp(Wornitems.QUIVER_AMMO_VARP), varp(Wornitems.QUIVER_AMOUNT_VARP)
		if id == nil or amount == nil or id == -1 or amount <= 0 then
			return nil
		end
		return { slot = Wornitems.SECONDARY_AMMO, id = id, quantity = amount }
	elseif holder == "pouch" then
		local bolt = Boltpouch.slot(Boltpouch.EXTRA)
		if bolt == nil then
			return nil
		end
		return { slot = Wornitems.SECONDARY_AMMO, id = bolt.id, quantity = bolt.quantity }
	end
	return nil
end

local function press_child(w: Widget, child: number, option: string): boolean
	local id = GROUP * 65536 + child
	return (Interact.with(w, option, function(entry: MenuEntry): boolean
		return entry.id == id
	end, false))
end

local function press_secondary(holder: SecondaryHolder, option: string): boolean
	if not Wornitems.open() then
		return false
	end
	local child = Wornitems.SECONDARY_CHILD[holder]
	local w = widget(GROUP, child)
	if w == nil then
		return false
	end
	return press_child(w, child, option)
end

local function worn_ammo_id(): number?
	for _, item in ipairs(item_container(Wornitems.CONTAINER) or {}) do
		if item.slot == Wornitems.AMMO and item.id ~= -1 then
			return item.id
		end
	end
	return nil
end

function Wornitems.swap_ammo(): boolean
	local holder = Wornitems.secondary_ammo_holder()
	if holder == nil then
		return false
	end
	local main = worn_ammo_id()
	local second = Wornitems.secondary_ammo()
	if main == nil and second == nil then
		return true
	end
	local pressed: boolean
	if second ~= nil then
		pressed = press_secondary(holder, Wornitems.SWAP_OPTION[holder])
	elseif holder == "quiver" then
		pressed = press_secondary(holder, Wornitems.QUIVER_FILL_OPTION)
	else
		pressed = Boltpouch.open() and Boltpouch.move(Boltpouch.CURRENT, Boltpouch.EXTRA)
		pressed = Boltpouch.close() and pressed
	end
	if not pressed then
		return false
	end
	return Widgets.wait_within(function(): boolean
		local now = Wornitems.secondary_ammo()
		return (if now then now.id else nil) == main
	end, Wornitems.SWAP_TIMEOUT_MS, Wornitems.POLL_MS)
end

local function remove_secondary_ammo(): boolean
	local holder = Wornitems.secondary_ammo_holder()
	if holder == nil or Wornitems.secondary_ammo() == nil then
		return false
	end
	if holder == "quiver" then
		return press_secondary(holder, Wornitems.QUIVER_REMOVE_OPTION)
	end
	local removed = Boltpouch.open() and Boltpouch.remove(Boltpouch.EXTRA)
	return Boltpouch.close() and removed
end

function Wornitems.remove(slot: number | string): boolean
	local s = Wornitems.slot(slot)
	if s == nil then
		return false
	end
	if s == Wornitems.SECONDARY_AMMO then
		return remove_secondary_ammo()
	end
	return Wornitems.interact_slot(s, "Remove")
end

function Wornitems.button(name: string): Widget?
	local b = Wornitems.BUTTONS[name]
	if b == nil then
		return nil
	end
	return (widget(GROUP, b.child))
end

function Wornitems.press(name: string): boolean
	local b = Wornitems.BUTTONS[name]
	if b == nil then
		return false
	end
	if not Wornitems.open() then
		return false
	end
	local w = Wornitems.button(name)
	if w == nil then
		return false
	end
	return press_child(w, b.child, b.option)
end

return Wornitems
