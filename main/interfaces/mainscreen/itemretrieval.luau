--!strict
-- The item retrieval interface (group 602, `gravestone_retrieval` in the cache): what a death left behind with a keeper (Priestess Zul-Gwenwynig after Zulrah), in item container 525. "Take-All" on the button takes everything that fits, "Take-All" on a slot takes that stack. "Discard-All" deletes the items for good, so nothing here clicks it.
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

local ItemRetrieval = {}

ItemRetrieval.GROUP = 602
ItemRetrieval.CONTAINER = 525
-- The frame (its children hold the title and the close button), the grid of slots, the Take-All button and the text with the stack count and value.
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
-- The menu follows the mouse a frame or so late, and would still show what was under it before.
ItemRetrieval.SETTLE_MS = 150

function ItemRetrieval.is_open(): boolean
	return Toplevel.is_open(ItemRetrieval.GROUP)
end

-- Whether the interface is open, polled for up to `timeout_ms` (3 seconds by default).
function ItemRetrieval.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or ItemRetrieval.OPEN_TIMEOUT_MS)
	while not ItemRetrieval.is_open() do
		if time() >= deadline then
			return false
		end
		sleep(ItemRetrieval.POLL_MS)
	end
	return true
end

-- The title ("Zul-Gwenwynig's Item Retrieval Service"), nil when the interface isn't open.
function ItemRetrieval.title(): string?
	if not ItemRetrieval.is_open() then
		return nil
	end
	local children = widget_children(ItemRetrieval.GROUP, ItemRetrieval.FRAME)
	local title = children and children[ItemRetrieval.TITLE_INDEX + 1]
	return title and title.text
end

-- The stacks kept, in the interface's order (slot 0 first); nil when the interface isn't open.
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

-- How many stacks are kept; nil when the interface isn't open.
function ItemRetrieval.count(): number?
	local kept = ItemRetrieval.items()
	return if kept then #kept else nil
end

-- What the interface says the kept items are worth (its "Guide value"), nil when it isn't open or shows none.
function ItemRetrieval.value(): number?
	local summary = widget(ItemRetrieval.GROUP, ItemRetrieval.SUMMARY)
	if summary == nil or summary.text == nil or not ItemRetrieval.is_open() then
		return nil
	end
	local digits = string.match(summary.text, "Guide value: <col=%x+>([%d,]+)</col>")
	return if digits then tonumber((string.gsub(digits, ",", ""))) else nil
end

-- The grid cell showing container slot `slot`, nil when it isn't shown.
function ItemRetrieval.cell(slot: number): Widget?
	if not ItemRetrieval.is_open() then
		return nil
	end
	local children = widget_children(ItemRetrieval.GROUP, ItemRetrieval.GRID)
	local cell = children and children[slot + 1]
	if cell == nil or cell.hidden then
		return nil
	end
	return cell
end

-- The container slot of the first kept stack of `item` (ids or names), nil when none is kept.
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

-- The first option the menu where the mouse is now offers (waiting a moment for the game to show one), or nil.
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

-- Whether the menu where the mouse is now offers `option` first, waiting a moment for the game to show it.
local function offers(option: string): boolean
	local deadline = time() + ItemRetrieval.HOVER_TIMEOUT_MS
	while true do
		if first_option() == option then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(ItemRetrieval.POLL_MS)
	end
end

-- Whether a button option pays the keeper's fee (the button offers it until the fee is paid, Take-All after).
local function pays(option: string): boolean
	local lower = string.lower(option)
	return string.find(lower, "unlock", 1, true) ~= nil or string.find(lower, "pay", 1, true) ~= nil
end

-- Hovers `target`, checks the menu offers Take-All first and clicks, then waits for the kept stacks to drop below `before`.
local function take(target: Widget, before: number, what: string): boolean
	Mouse.move(target)
	sleep(ItemRetrieval.SETTLE_MS)
	if not offers(ItemRetrieval.TAKE_OPTION) then
		Log.log("ItemRetrieval", `the menu didn't offer {ItemRetrieval.TAKE_OPTION} on {what}`)
		return false
	end
	Mouse.click()
	local deadline = time() + ItemRetrieval.TAKE_TIMEOUT_MS
	while time() < deadline do
		local now = ItemRetrieval.count()
		if now == nil or now < before then
			return true
		end
		sleep(ItemRetrieval.POLL_MS)
	end
	Log.log("ItemRetrieval", `{ItemRetrieval.TAKE_OPTION} on {what} took nothing`)
	return false
end

-- Clicks the Take-All button: everything that fits goes to the inventory. True once fewer stacks are kept (all of them when there's room), true at once when none is kept.
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
	-- locked: the button first pays the fee (the game takes it from the bank), then offers Take-All
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

-- Takes the first kept stack of `item` (ids or names) from its slot. False when none is kept or nothing was taken.
function ItemRetrieval.take(item: Item.Item | { Item.Item }): boolean
	local before = ItemRetrieval.count()
	local slot = ItemRetrieval.slot(item)
	local cell = if slot then ItemRetrieval.cell(slot) else nil
	if before == nil or cell == nil then
		return false
	end
	return take(cell, before, `slot {slot}`)
end

-- The close button, nil when the interface isn't open.
function ItemRetrieval.close_button(): Widget?
	if not ItemRetrieval.is_open() then
		return nil
	end
	local children = widget_children(ItemRetrieval.GROUP, ItemRetrieval.FRAME)
	local button = children and children[ItemRetrieval.CLOSE_INDEX + 1]
	if button == nil or button.hidden then
		return nil
	end
	return button
end

-- Closes the interface, leaving what is still kept: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.
function ItemRetrieval.close(key_probability: number?): boolean
	return Toplevel.close(
		ItemRetrieval.GROUP,
		ItemRetrieval.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

return ItemRetrieval
