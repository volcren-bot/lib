--!strict
local Host = require("@lib/host")
local menu = Host.menu
local widget = Host.widget
local widget_children = Host.widget_children
local item_container = Host.item_container
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
type ItemSlot = Host.ItemSlot
local Item = require("@lib/utils/item")
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Widgets = require("@lib/main/interfaces/widgets")

local ItemRetrieval = {}

ItemRetrieval.GROUP = 602
ItemRetrieval.CONTAINER = 525
ItemRetrieval.FRAME = 1
ItemRetrieval.TITLE_INDEX = 1
ItemRetrieval.CLOSE_INDEX = 11
ItemRetrieval.GRID = 3
ItemRetrieval.TAKE_ALL = 6
ItemRetrieval.SUMMARY = 14
ItemRetrieval.TAKE_OPTION = "Take-All"

ItemRetrieval.OPEN_TIMEOUT_MS = 3000
ItemRetrieval.HOVER_TIMEOUT_MS = 800
ItemRetrieval.TAKE_TIMEOUT_MS = 4000
ItemRetrieval.UNLOCK_TIMEOUT_MS = 4000
ItemRetrieval.POLL_MS = 50
ItemRetrieval.SETTLE_MS = 150

local function nth_child(child: number, index: number): Widget?
	local children = widget_children(ItemRetrieval.GROUP, child)
	return children and children[index + 1]
end

function ItemRetrieval.is_open(): boolean
	return Toplevel.is_open(ItemRetrieval.GROUP)
end

function ItemRetrieval.wait_open(timeout_ms: number?): boolean
	return Widgets.wait_for(ItemRetrieval.is_open, timeout_ms or ItemRetrieval.OPEN_TIMEOUT_MS, ItemRetrieval.POLL_MS)
end

function ItemRetrieval.title(): string?
	if not ItemRetrieval.is_open() then
		return nil
	end
	local title = nth_child(ItemRetrieval.FRAME, ItemRetrieval.TITLE_INDEX)
	return title and title.text
end

function ItemRetrieval.items(): { ItemSlot }?
	if not ItemRetrieval.is_open() then
		return nil
	end
	local kept: { ItemSlot } = {}
	for _, slot in ipairs(item_container(ItemRetrieval.CONTAINER) or {}) do
		if slot.id > 0 then
			table.insert(kept, slot)
		end
	end
	table.sort(kept, function(a: ItemSlot, b: ItemSlot): boolean
		return a.slot < b.slot
	end)
	return kept
end

function ItemRetrieval.count(): number?
	local kept = ItemRetrieval.items()
	return if kept then #kept else nil
end

function ItemRetrieval.value(): number?
	local summary = widget(ItemRetrieval.GROUP, ItemRetrieval.SUMMARY)
	if summary == nil or summary.text == nil or not ItemRetrieval.is_open() then
		return nil
	end
	local digits = string.match(summary.text, "Guide value: <col=%x+>([%d,]+)</col>")
	return if digits then tonumber((string.gsub(digits, ",", ""))) else nil
end

function ItemRetrieval.cell(slot: number): Widget?
	if not ItemRetrieval.is_open() then
		return nil
	end
	local cell = nth_child(ItemRetrieval.GRID, slot)
	if cell == nil or cell.hidden then
		return nil
	end
	return cell
end

function ItemRetrieval.slot(item: Item.Item | { Item.Item }): number?
	local matcher = Item.matcher(item)
	local kept = ItemRetrieval.items() or {}
	local ids: { number } = {}
	for _, k in kept do
		table.insert(ids, k.id)
	end
	local names = if Item.needs_names(matcher) then Item.names(ids) else nil
	for i, k in kept do
		if Item.matches(matcher, k.id, names and names[i]) then
			return k.slot
		end
	end
	return nil
end

local function first_option(): string?
	local deadline = time() + ItemRetrieval.HOVER_TIMEOUT_MS
	while true do
		for _, entry in ipairs(menu() or {}) do
			if entry.option ~= "Cancel" and entry.option ~= "Walk here" then
				return entry.option
			end
		end
		if time() >= deadline then
			return nil
		end
		sleep(ItemRetrieval.POLL_MS)
	end
end

local function offers(option: string): boolean
	return Widgets.wait_for(function(): boolean
		return first_option() == option
	end, ItemRetrieval.HOVER_TIMEOUT_MS, ItemRetrieval.POLL_MS)
end

local function pays(option: string): boolean
	local lower = string.lower(option)
	return string.find(lower, "unlock", 1, true) ~= nil or string.find(lower, "pay", 1, true) ~= nil
end

local function take(target: Widget, before: number, what: string): boolean
	Mouse.move(target)
	sleep(ItemRetrieval.SETTLE_MS)
	if not offers(ItemRetrieval.TAKE_OPTION) then
		Log.log("ItemRetrieval", `the menu didn't offer {ItemRetrieval.TAKE_OPTION} on {what}`)
		return false
	end
	Mouse.click()
	if
		Widgets.wait_within(function(): boolean
			local now = ItemRetrieval.count()
			return now == nil or now < before
		end, ItemRetrieval.TAKE_TIMEOUT_MS, ItemRetrieval.POLL_MS)
	then
		return true
	end
	Log.log("ItemRetrieval", `{ItemRetrieval.TAKE_OPTION} on {what} took nothing`)
	return false
end

function ItemRetrieval.take_all(): boolean
	local before = ItemRetrieval.count()
	if before == nil then
		return false
	end
	if before == 0 then
		return true
	end
	local button = widget(ItemRetrieval.GROUP, ItemRetrieval.TAKE_ALL)
	if button == nil or button.hidden then
		return false
	end
	Mouse.move(button)
	sleep(ItemRetrieval.SETTLE_MS)
	local option = first_option()
	if option ~= nil and option ~= ItemRetrieval.TAKE_OPTION then
		if not pays(option) then
			Log.log("ItemRetrieval", `the button offers "{option}", not {ItemRetrieval.TAKE_OPTION} or a fee`)
			return false
		end
		Log.log("ItemRetrieval", `paying the fee: "{option}"`)
		Mouse.click()
		local deadline = time() + ItemRetrieval.UNLOCK_TIMEOUT_MS
		while not offers(ItemRetrieval.TAKE_OPTION) do
			if time() >= deadline then
				Log.log("ItemRetrieval", `"{option}" didn't unlock {ItemRetrieval.TAKE_OPTION}`)
				return false
			end
		end
	end
	return take(button, before, "the button")
end

function ItemRetrieval.take(item: Item.Item | { Item.Item }): boolean
	local before = ItemRetrieval.count()
	local slot = ItemRetrieval.slot(item)
	local cell = if slot then ItemRetrieval.cell(slot) else nil
	if before == nil or cell == nil then
		return false
	end
	return take(cell, before, `slot {slot}`)
end

function ItemRetrieval.close_button(): Widget?
	if not ItemRetrieval.is_open() then
		return nil
	end
	local button = nth_child(ItemRetrieval.FRAME, ItemRetrieval.CLOSE_INDEX)
	if button == nil or button.hidden then
		return nil
	end
	return button
end

function ItemRetrieval.close(key_probability: number?): boolean
	return Toplevel.close(
		ItemRetrieval.GROUP,
		ItemRetrieval.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

return ItemRetrieval
