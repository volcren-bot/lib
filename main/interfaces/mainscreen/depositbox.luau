--!strict
local Host = require("../../../host")
local widget = Host.widget
local widget_children = Host.widget_children
local sleep = Host.sleep
type Widget = Host.Widget
type MenuEntry = Host.MenuEntry
type Loc = Host.Loc
local Geometry = require("../../../utils/math/geometry")
type Box = Geometry.Box
local Item = require("../../../utils/item")
local Mouse = require("../../../utils/input/mouse")
type Item = Item.Item
local Chat = require("../chatbox/chat")
local Clickbox = require("../../clickbox")
local Inv = require("../inv")
local Log = require("../../../utils/log")
local Minimenu = require("../minimenu")
local Objects = require("../../entities/objects")
local Toplevel = require("./toplevel")
local Walker = require("../../walker")

local GROUP = 192
local INVENTORY_CONTAINER = 93
local INVENTORY_SIZE = 28
local EQUIPMENT_CONTAINER = 94
local EQUIPMENT_SIZE = 14

local SLOTS_CHILD = 24
local PANEL_CHILD = 1
local TITLE_INDEX = 1
local CLOSE_INDEX = 11

local EQUIPMENT_CHILDREN: { [number]: number } = {
	[0] = 10,
	[1] = 11,
	[2] = 12,
	[3] = 13,
	[4] = 14,
	[5] = 15,
	[7] = 16,
	[9] = 17,
	[10] = 18,
	[12] = 19,
	[13] = 20,
}

export type DepositButton = "WORN" | "INVENTORY" | "LOOT"
export type Quantity = "ONE" | "FIVE" | "TEN" | "CUSTOM" | "ALL"

local DEPOSIT_BUTTONS: { [DepositButton]: number } = { WORN = 30, INVENTORY = 31, LOOT = 32 }

local QUANTITY_BUTTONS: { [Quantity]: number } = { ONE = 35, FIVE = 36, TEN = 37, CUSTOM = 38, ALL = 39 }
local LIT_SPRITE_FIRST = 1150
local LIT_SPRITE_LAST = 1158

local OBJECT_NAME = "Bank deposit box"
local OPEN_TIMEOUT_MS = 3000
local POLL_MS = 50
local SELECT_TIMEOUT_MS = 1800
local CLOSE_TIMEOUT_MS = 600
local ENTER_AMOUNT_TIMEOUT_MS = 2500

export type Deposit = {
	item: Item,
	quantity: number?,
}
export type Entry = Item | Deposit

local function poll(check: () -> boolean, timeout_ms: number): boolean
	local waited = 0
	while true do
		local done = check()
		if done == nil then
			return false
		end
		if done then
			return true
		end
		if waited >= timeout_ms then
			return false
		end
		sleep(POLL_MS)
		waited += POLL_MS
	end
end

local function child(child_id: number, index: number): Widget?
	local kids = widget_children(GROUP, child_id)
	if kids == nil then
		return nil
	end
	for _, k in ipairs(kids) do
		if k.index == index then
			return k
		end
	end
	return nil
end

local function component(child_id: number): Widget?
	local w = widget(GROUP, child_id)
	if w == nil then
		return nil
	end
	return w
end

local function title(): string?
	local w = child(PANEL_CHILD, TITLE_INDEX)
	if w == nil then
		return nil
	end
	return w.text or ""
end

local function is_open(): boolean
	local open = Toplevel.is_open(GROUP)
	if open == nil then
		return false
	end
	if not open then
		return false
	end
	local text = title()
	if text == nil then
		return false
	end
	return string.find(string.lower(text), "deposit", 1, true) ~= nil
end

local function open_check(): boolean
	local open = is_open()
	if open == nil then
		return false
	end
	if not open then
		return false
	end
	return true
end

local function slot_boxes(): { [number]: Widget }?
	local kids = widget_children(GROUP, SLOTS_CHILD)
	if kids == nil then
		return nil
	end
	local by_slot: { [number]: Widget } = {}
	for _, w in ipairs(kids) do
		by_slot[w.index] = w
	end
	if next(by_slot) == nil then
		return nil
	end
	return by_slot
end

local function equipment_boxes(): { [number]: Widget }?
	local by_slot: { [number]: Widget } = {}
	for slot, child_id in pairs(EQUIPMENT_CHILDREN) do
		local w = component(child_id)
		if w == nil then
			return nil
		end
		by_slot[slot] = w
	end
	return by_slot
end

local function inventory_owns(slot: number): (MenuEntry) -> boolean
	return function(entry: MenuEntry): boolean
		return entry.id == GROUP * 65536 + SLOTS_CHILD and entry.index == slot
	end
end

local function equipment_owns(slot: number): (MenuEntry) -> boolean
	local child_id = EQUIPMENT_CHILDREN[slot]
	return function(entry: MenuEntry): boolean
		return child_id ~= nil and entry.id == GROUP * 65536 + child_id
	end
end

local items = Inv.new(INVENTORY_CONTAINER, INVENTORY_SIZE, {
	open = open_check,
	boxes = slot_boxes,
	owns = inventory_owns,
})

local equipment = Inv.new(EQUIPMENT_CONTAINER, EQUIPMENT_SIZE, {
	open = open_check,
	boxes = equipment_boxes,
	owns = equipment_owns,
})

local DepositBox = {}

DepositBox.GROUP = GROUP
DepositBox.OBJECT_NAME = OBJECT_NAME
DepositBox.DEPOSIT_BUTTONS = DEPOSIT_BUTTONS
DepositBox.QUANTITY_BUTTONS = QUANTITY_BUTTONS
DepositBox.QUANTITY_ALL = 0
DepositBox.QUANTITY_ALL_BUT_ONE = -1
DepositBox.items = items
DepositBox.equipment = equipment

function DepositBox.quantity_of(amount: number): Quantity
	if amount == 1 then
		return "ONE"
	elseif amount == 5 then
		return "FIVE"
	elseif amount == 10 then
		return "TEN"
	elseif amount <= 0 then
		return "ALL"
	end
	return "CUSTOM"
end

DepositBox.title = title

DepositBox.is_open = is_open

function DepositBox.wait_open(timeout_ms: number?): boolean
	return poll(is_open, timeout_ms or OPEN_TIMEOUT_MS)
end

function DepositBox.bounds(): Box?
	local w = component(PANEL_CHILD)
	if w == nil then
		return nil
	end
	return Geometry.Box.from_area(w)
end

function DepositBox.slots_area(): Box?
	local w = component(SLOTS_CHILD)
	if w == nil then
		return nil
	end
	return Geometry.Box.from_area(w)
end

function DepositBox.find_item_boundaries(): { Box }?
	local used = items.used()
	if used == nil then
		return nil
	end
	local all = items.boxes()
	if all == nil then
		return nil
	end
	local boxes: { Box } = {}
	for _, slot in ipairs(used) do
		local w = all[slot]
		if w then
			table.insert(boxes, Geometry.Box.from_area(w))
		end
	end
	return boxes
end

function DepositBox.quantity_selected(quantity: Quantity): boolean
	local kids = widget_children(GROUP, QUANTITY_BUTTONS[quantity])
	if kids == nil then
		return false
	end
	for _, k in ipairs(kids) do
		if k.sprite >= LIT_SPRITE_FIRST and k.sprite <= LIT_SPRITE_LAST then
			return true
		end
	end
	return false
end

function DepositBox.select_quantity(quantity: Quantity): boolean
	local selected = DepositBox.quantity_selected(quantity)
	if selected == nil then
		return false
	end
	if selected then
		return true
	end
	local w = component(QUANTITY_BUTTONS[quantity])
	if w == nil then
		return false
	end
	Mouse.click(w)
	return poll(function()
		return DepositBox.quantity_selected(quantity)
	end, SELECT_TIMEOUT_MS)
end

-- Queues the click and returns at once; true if selected or queued, `force` clicks even when selected.
function DepositBox.select_quantity_async(quantity: Quantity, force: boolean?): boolean
	if not force and DepositBox.quantity_selected(quantity) then
		return true
	end
	local w = component(QUANTITY_BUTTONS[quantity])
	if w == nil then
		return false
	end
	return Mouse.click_async(w)
end

function DepositBox.click_button(button: DepositButton): boolean
	local open = open_check()
	if not open then
		return open
	end
	local w = component(DEPOSIT_BUTTONS[button])
	if w == nil then
		return false
	end
	Mouse.click(w)
	return true
end

function DepositBox.deposit_inventory(): boolean
	return DepositBox.click_button("INVENTORY")
end

function DepositBox.deposit_loot_bag(): boolean
	return DepositBox.click_button("LOOT")
end

function DepositBox.deposit_equipment(): boolean
	return DepositBox.click_button("WORN")
end

function DepositBox.close(key_probability: number?, timeout_ms: number?): boolean
	return Toplevel.close(GROUP, function()
		return child(PANEL_CHILD, CLOSE_INDEX)
	end, key_probability, timeout_ms)
end

local function option_for(amount: number): string
	if amount <= 0 then
		return "Deposit-All"
	end
	return `Deposit-{amount}`
end

local function deposit_slot(slot: number, amount: number, use_quantity_buttons: boolean): boolean
	local quantity: Quantity = DepositBox.quantity_of(amount)
	if use_quantity_buttons then
		local selected = DepositBox.select_quantity(quantity)
		if not selected then
			Log.log("DepositBox", `couldn't select the {quantity} deposit quantity`)
			return selected
		end
		if quantity ~= "CUSTOM" then
			return items.click_slot(slot)
		end
		local hovered = items.hover_slot(slot)
		if not hovered then
			return hovered
		end
		local entries = Minimenu.entries()
		if entries == nil then
			return false
		end
		local top = entries[1]
		if top and string.lower(top.option) == string.lower(option_for(amount)) then
			return items.click_slot(slot)
		end
	elseif quantity ~= "CUSTOM" then
		return items.interact_slot(slot, option_for(amount))
	end

	local picked = items.interact_slot(slot, "Deposit-X")
	if not picked then
		return picked
	end
	local answered = Chat.answer_query("Enter amount", tostring(amount), ENTER_AMOUNT_TIMEOUT_MS)
	if answered == nil then
		return false
	end
	return answered
end

function DepositBox.deposit(item: Item, quantity: number?, use_quantity_buttons: boolean?): boolean
	local slots = items.indices_of(item)
	if slots == nil then
		return false
	end
	if #slots == 0 then
		return false
	end
	local slot = slots[math.random(1, #slots)]
	return deposit_slot(slot, quantity or DepositBox.QUANTITY_ALL, use_quantity_buttons ~= false)
end

local function as_deposit(entry: Entry): Deposit
	if type(entry) == "table" then
		return entry
	end
	return { item = entry }
end

function DepositBox.deposit_array(entries: { Entry }, use_quantity_buttons: boolean?): boolean
	local all_ok = true
	for _, entry in ipairs(entries) do
		local deposit = as_deposit(entry)
		local ok = DepositBox.deposit(deposit.item, deposit.quantity, use_quantity_buttons)
		if not ok then
			all_ok = false
		end
	end
	return all_ok
end

function DepositBox.deposit_different(keep: Item | { Item }, use_quantity_buttons: boolean?): boolean
	local slots = items.find_different(keep)
	if slots == nil then
		return false
	end
	local done: { [number]: boolean } = {}
	for _, slot in ipairs(slots) do
		local s = items.item(slot)
		if s ~= nil and not done[s.id] then
			done[s.id] = true
			local ok = deposit_slot(slot, DepositBox.QUANTITY_ALL, use_quantity_buttons ~= false)
			if not ok then
				return ok
			end
		end
	end
	return true
end

local function nearest_loc(loc: Loc?): Loc?
	if loc then
		return loc
	end
	local me = Walker.position()
	if me == nil then
		return nil
	end
	local found = Objects.nearest(OBJECT_NAME, me)
	if found == nil then
		return nil
	end
	return found
end

function DepositBox.hover(loc: Loc?, walk: boolean?): boolean
	local target = nearest_loc(loc)
	if target == nil then
		return false
	end
	if walk ~= false then
		local goal = { x = math.floor(target.x), y = math.floor(target.y) }
		local walked = Walker.walk(goal, { near = Clickbox.APPROACH_NEAR })
		if not walked then
			return walked
		end
	end
	return Objects.hover(target)
end

function DepositBox.open(loc: Loc?, walk: boolean?): boolean
	local open = is_open()
	if open == nil then
		return false
	end
	if open then
		return true
	end
	local cleared = Toplevel.escape_clear(CLOSE_TIMEOUT_MS)
	if not cleared then
		return cleared
	end

	local target = nearest_loc(loc)
	if target == nil then
		return false
	end
	local picked
	if walk ~= false then
		picked = Objects.approach(target, "Deposit")
	else
		picked = Objects.interact(target, "Deposit")
	end
	if not picked then
		local uptext = Minimenu.uptext()
		if uptext == nil then
			return false
		end
		if not string.find(string.lower(uptext), "deposit box", 1, true) then
			return picked
		end
		local selected = Minimenu.select("Deposit", "deposit box")
		if not selected then
			return selected
		end
	end
	return DepositBox.wait_open(OPEN_TIMEOUT_MS)
end

return DepositBox
