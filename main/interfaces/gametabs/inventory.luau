--!strict
local Host = require("../../../host")
local widget_children = Host.widget_children
local selected_widget = Host.selected_widget
local item_container = Host.item_container
local sleep = Host.sleep
type Widget = Host.Widget
type MenuEntry = Host.MenuEntry
local Item = require("../../../utils/item")
type Item = Item.Item
local Inv = require("../inv")
local SidePanels = require("./side_panels")
local Interact = require("../../interact")
local Minimenu = require("../minimenu")
local Biometrics = require("../../antiban/biometrics")
local Mouse = require("../../../utils/input/mouse")
local Keyboard = require("../../../utils/input/keyboard")
local Random = require("../../../utils/math/random")
local Geometry = require("../../../utils/math/geometry")
local Log = require("../../../utils/log")

local CONTAINER = 93
local SIZE = 28
local GROUP = 149
local ITEMS = 0
local ITEMS_ID = GROUP * 65536 + ITEMS

local POLL_MS = 50
local SELECT_TIMEOUT_MS = 1200
local DROP_TIMEOUT_MS = 1800
local SHIFT_DROP_HOVER_MS = 300

local function owns(slot: number): (MenuEntry) -> boolean
	return function(entry: MenuEntry): boolean
		return entry.id == ITEMS_ID and entry.index == slot
	end
end

local items = Inv.new(CONTAINER, SIZE, {
	open = function()
		return SidePanels.open(SidePanels.INVENTORY)
	end,
	boxes = function(): { [number]: Widget }?
		local children = widget_children(GROUP, ITEMS)
		if children == nil then
			return nil
		end
		local by_slot: { [number]: Widget } = {}
		for _, c in ipairs(children) do
			if c.index >= 0 then
				by_slot[c.index] = c
			end
		end
		return by_slot
	end,
	owns = owns,
})

local Inventory = {
	CONTAINER = CONTAINER,
	SIZE = SIZE,
	GROUP = GROUP,
	shift_enabled = true,
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
	empty = items.empty,
	is_used = items.is_used,
	is_empty = items.is_empty,
	count_used = items.count_used,
	count_empty = items.count_empty,
	wait_used = items.wait_used,
	open = items.open,
	boxes = items.boxes,
	box = items.box,
	slot_at = items.slot_at,
	near = items.near,
	random_near = items.random_near,
	hover_slot = items.hover_slot,
	click_slot = items.click_slot,
	move_slot = items.move_slot,
	interact_slot = items.interact_slot,
	hover = items.hover,
	click = items.click,
	move = items.move,
	interact = items.interact,
}

Inventory.PATTERNS = table.freeze({
	table.freeze({
		0,
		1,
		2,
		3,
		4,
		5,
		6,
		7,
		8,
		9,
		10,
		11,
		12,
		13,
		14,
		15,
		16,
		17,
		18,
		19,
		20,
		21,
		22,
		23,
		24,
		25,
		26,
		27,
	}),
	table.freeze({
		3,
		2,
		1,
		0,
		7,
		6,
		5,
		4,
		11,
		10,
		9,
		8,
		15,
		14,
		13,
		12,
		19,
		18,
		17,
		16,
		23,
		22,
		21,
		20,
		27,
		26,
		25,
		24,
	}),
	table.freeze({
		0,
		1,
		2,
		3,
		7,
		6,
		5,
		4,
		8,
		9,
		10,
		11,
		15,
		14,
		13,
		12,
		16,
		17,
		18,
		19,
		23,
		22,
		21,
		20,
		24,
		25,
		26,
		27,
	}),
	table.freeze({
		3,
		2,
		1,
		0,
		4,
		5,
		6,
		7,
		11,
		10,
		9,
		8,
		12,
		13,
		14,
		15,
		19,
		18,
		17,
		16,
		20,
		21,
		22,
		23,
		27,
		26,
		25,
		24,
	}),
	table.freeze({
		0,
		4,
		8,
		12,
		16,
		20,
		24,
		1,
		5,
		9,
		13,
		17,
		21,
		25,
		2,
		6,
		10,
		14,
		18,
		22,
		26,
		3,
		7,
		11,
		15,
		19,
		23,
		27,
	}),
	table.freeze({
		3,
		7,
		11,
		15,
		19,
		23,
		27,
		2,
		6,
		10,
		14,
		18,
		22,
		26,
		1,
		5,
		9,
		13,
		17,
		21,
		25,
		0,
		4,
		8,
		12,
		16,
		20,
		24,
	}),
	table.freeze({
		0,
		1,
		2,
		3,
		7,
		11,
		15,
		19,
		23,
		27,
		26,
		25,
		24,
		20,
		16,
		12,
		8,
		4,
		5,
		6,
		10,
		14,
		18,
		22,
		21,
		17,
		13,
		9,
	}),
	table.freeze({
		0,
		4,
		1,
		5,
		2,
		6,
		3,
		7,
		8,
		12,
		9,
		13,
		10,
		14,
		11,
		15,
		16,
		20,
		17,
		21,
		18,
		22,
		19,
		23,
		24,
		25,
		26,
		27,
	}),
	table.freeze({
		0,
		4,
		1,
		5,
		2,
		6,
		3,
		7,
		11,
		15,
		10,
		14,
		9,
		13,
		8,
		12,
		16,
		20,
		17,
		21,
		18,
		22,
		19,
		23,
		24,
		27,
		26,
		25,
	}),
})

local function wait_until(check: () -> boolean, timeout_ms: number): boolean
	local waited = 0
	while true do
		if check() then
			return true
		end
		if waited >= timeout_ms then
			return false
		end
		sleep(POLL_MS)
		waited += POLL_MS
	end
end

function Inventory.is_open(): boolean
	return SidePanels.is_open(SidePanels.INVENTORY)
end

function Inventory.free_slots(): number?
	return Inventory.count_empty()
end

function Inventory.is_full(): boolean
	local free = Inventory.free_slots()
	if free == nil then
		return false
	end
	return free == 0
end

function Inventory.selected(): number?
	local current = selected_widget()
	if current == nil or current.id ~= ITEMS_ID then
		return nil
	end
	return current.index
end

function Inventory.is_selected(slot: number): boolean
	local current = selected_widget()
	return current ~= nil and current.id == ITEMS_ID and current.index == slot
end

function Inventory.deselect(): boolean
	local current = selected_widget()
	if current == nil then
		return true
	end
	local ok
	if current.id == ITEMS_ID then
		ok = Inventory.interact_slot(current.index, "Use")
	else
		local at = Mouse.position()
		if at == nil then
			return false
		end
		ok = Interact.with(at, "Cancel", nil, false)
	end
	if not ok then
		return false
	end
	if wait_until(function()
		return selected_widget() == nil
	end, SELECT_TIMEOUT_MS) then
		return true
	end
	Log.log("Inventory", `{current.name} is still selected`)
	return false
end

function Inventory.select_slot(slot: number): boolean
	local current = Inventory.selected()
	if current == slot then
		return true
	end
	if selected_widget() ~= nil then
		local ok = Inventory.deselect()
		if not ok then
			return false
		end
	end
	local ok = Inventory.interact_slot(slot, "Use")
	if not ok then
		return ok
	end
	if wait_until(function()
		return Inventory.is_selected(slot) == true
	end, SELECT_TIMEOUT_MS) then
		return true
	end
	Log.log("Inventory", `slot {slot} didn't get selected`)
	return false
end

function Inventory.select(items: Item | { Item }): boolean
	local slots = Inventory.indices_of(items)
	if slots == nil then
		return false
	end
	if #slots == 0 then
		return false
	end
	local current = Inventory.selected()
	if current and table.find(slots, current) then
		return true
	end
	return Inventory.select_slot(slots[math.random(1, #slots)])
end

function Inventory.combine_slots(slot_a: number, slot_b: number): boolean
	local selected = Inventory.select_slot(slot_a)
	if not selected then
		return selected
	end
	Random.sleep(0, 600, "left")
	local ok = Inventory.interact_slot(slot_b, "Use")
	if not ok then
		return ok
	end
	if wait_until(function()
		return Inventory.selected() == nil
	end, SELECT_TIMEOUT_MS) then
		return true
	end
	Log.log("Inventory", `slot {slot_a} is still selected`)
	return false
end

function Inventory.combine(items_a: Item | { Item }, items_b: Item | { Item }): boolean
	local opened = Inventory.open()
	if not opened then
		return false
	end
	local slots_a = Inventory.indices_of(items_a)
	if slots_a == nil then
		return false
	end
	local slots_b = Inventory.indices_of(items_b)
	if slots_b == nil then
		return false
	end
	if #slots_a == 0 or #slots_b == 0 then
		return false
	end
	local boxes = Inventory.boxes()
	if boxes == nil then
		return false
	end
	local best_a, best_b, best = slots_a[1], slots_b[1], math.huge
	for _, a in ipairs(slots_a) do
		for _, b in ipairs(slots_b) do
			local box_a, box_b = boxes[a], boxes[b]
			if a ~= b and box_a and box_b then
				local dist = Geometry.Point.distance(
					Geometry.Box.center(Geometry.Box.from_area(box_a)),
					Geometry.Box.center(Geometry.Box.from_area(box_b))
				)
				if dist < best then
					best_a, best_b, best = a, b, dist
				end
			end
		end
	end
	if best_a == best_b then
		return false
	end
	return Inventory.combine_slots(best_a, best_b)
end

function Inventory.random_pattern(): { number }
	local count = #Inventory.PATTERNS
	local pattern = Inventory.PATTERNS[Biometrics.random_mode_integer((count - 1) // 2, 0, count - 1) + 1]
	local order = table.clone(pattern)
	if not Biometrics.random_boolean(0.7) then
		for i = 1, #order // 2 do
			order[i], order[#order - i + 1] = order[#order - i + 1], order[i]
		end
	end
	return order
end

local function in_order(slots: { number }, pattern: { number }): { number }
	local wanted: { [number]: boolean } = {}
	for _, slot in ipairs(slots) do
		wanted[slot] = true
	end
	local ordered: { number } = {}
	for _, slot in ipairs(pattern) do
		if wanted[slot] then
			table.insert(ordered, slot)
		end
	end
	return ordered
end

local function holding(slots: { number }): { [number]: number }?
	local all = item_container(CONTAINER)
	if all == nil then
		return nil
	end
	local ids: { [number]: number } = {}
	for _, s in ipairs(all) do
		if s.id ~= -1 then
			ids[s.slot] = s.id
		end
	end
	local held: { [number]: number } = {}
	for _, slot in ipairs(slots) do
		if ids[slot] then
			held[slot] = ids[slot]
		end
	end
	return held
end

local function still_held(targets: { [number]: number }, order: { number }): { number }?
	local now = holding(order)
	if now == nil then
		return nil
	end
	local left: { number } = {}
	for _, slot in ipairs(order) do
		if targets[slot] and now[slot] == targets[slot] then
			table.insert(left, slot)
		end
	end
	return left
end

local function wait_dropped(targets: { [number]: number }, order: { number }): { number }?
	local left = still_held(targets, order)
	local waited = 0
	while left and #left > 0 and waited < DROP_TIMEOUT_MS do
		sleep(POLL_MS * 2)
		waited += POLL_MS * 2
		left = still_held(targets, order)
	end
	return left
end

local function start_drop(slots: { number }): { [number]: number }?
	local opened = Inventory.open()
	if not opened then
		return nil
	end
	if selected_widget() ~= nil then
		local ok = Inventory.deselect()
		if not ok then
			return nil
		end
	end
	return holding(slots)
end

function Inventory.drop_slots(slots: { number }, attempts: number?): boolean
	if #slots == 0 then
		return true
	end
	local targets = start_drop(slots)
	if targets == nil then
		return false
	end
	local left: { number }? = still_held(targets, slots)
	for _ = 1, attempts or 5 do
		if left == nil or #left == 0 then
			break
		end
		for _, slot in ipairs(left) do
			Inventory.interact_slot(slot, "Drop")
			Random.sleep(0, 250, "left")
		end
		left = wait_dropped(targets, slots)
	end
	if left == nil then
		return false
	end
	if #left > 0 then
		Log.log("Inventory", `slots {table.concat(left, ", ")} weren't dropped`)
		return false
	end
	return true
end

function Inventory.drop(items: Item | { Item }, pattern: { number }?): boolean
	local slots = Inventory.indices_of(items)
	if slots == nil then
		return false
	end
	if #slots == 0 then
		return false
	end
	return Inventory.drop_slots(in_order(slots, pattern or Inventory.random_pattern()))
end

local function shift_drops(slot: number): boolean
	local matches = owns(slot)
	return wait_until(function()
		local entries = Minimenu.entries()
		local top = entries and entries[1]
		return top ~= nil and matches(top) and top.option == "Drop"
	end, SHIFT_DROP_HOVER_MS)
end

function Inventory.shift_drop_slots(slots: { number }, attempts: number?): boolean
	if #slots == 0 then
		return true
	end
	if not Inventory.shift_enabled then
		return Inventory.drop_slots(slots, attempts)
	end
	local targets = start_drop(slots)
	if targets == nil then
		return false
	end
	local left: { number }? = still_held(targets, slots)
	local fallback = false
	for _ = 1, attempts or 5 do
		if left == nil or #left == 0 or fallback then
			break
		end
		local boxes = Inventory.boxes()
		if boxes == nil then
			return false
		end
		Keyboard.key_down(Keyboard.keys.LSHIFT)
		Random.sleep(95, 170, "left")
		local ok, pass_err = pcall(function()
			for _, slot in ipairs(left :: { number }) do
				local w = boxes[slot]
				if w then
					Mouse.move(w)
					if not shift_drops(slot) then
						fallback = true
						return
					end
					Biometrics.click("left", 3, 0.03)
					Random.sleep(0, 250, "left")
				end
			end
		end)
		Keyboard.key_up(Keyboard.keys.LSHIFT)
		if not ok then
			error(pass_err, 0)
		end
		left = wait_dropped(targets, slots)
	end
	if left == nil then
		return false
	end
	if fallback then
		Log.log(
			"Inventory",
			"Shift click to drop items is off, dropping through the menu (turn it on for faster drops)"
		)
		Inventory.shift_enabled = false
		return Inventory.drop_slots(left, attempts)
	end
	if #left > 0 then
		return false
	end
	return true
end

function Inventory.shift_drop(items: Item | { Item }, pattern: { number }?): boolean
	local slots = Inventory.indices_of(items)
	if slots == nil then
		return false
	end
	if #slots == 0 then
		return false
	end
	return Inventory.shift_drop_slots(in_order(slots, pattern or Inventory.random_pattern()))
end

return Inventory
