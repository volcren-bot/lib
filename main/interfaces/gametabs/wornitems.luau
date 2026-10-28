--!strict
local Host = require("../../../host")
local item_container = Host.item_container
local widget = Host.widget
type ItemSlot = Host.ItemSlot
type Widget = Host.Widget
type MenuEntry = Host.MenuEntry
local Item = require("../../../utils/item")
type Item = Item.Item
local Interact = require("../../interact")
local Inv = require("../inv")
local SidePanels = require("./side_panels")

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

function Wornitems.remove(slot: number | string): boolean
	local s = Wornitems.slot(slot)
	if s == nil then
		return false
	end
	return Wornitems.interact_slot(s, "Remove")
end

function Wornitems.button(name: string): Widget?
	local b = Wornitems.BUTTONS[name]
	if b == nil then
		return nil
	end
	local w = widget(GROUP, b.child)
	if w == nil then
		return nil
	end
	return w
end

function Wornitems.press(name: string): boolean
	local b = Wornitems.BUTTONS[name]
	if b == nil then
		return false
	end
	local opened = Wornitems.open()
	if not opened then
		return false
	end
	local w = Wornitems.button(name)
	if w == nil then
		return false
	end
	local id = GROUP * 65536 + b.child
	local ok = Interact.with(w, b.option, function(entry: MenuEntry): boolean
		return entry.id == id
	end, false)
	if not ok then
		return false
	end
	return true
end

return Wornitems
