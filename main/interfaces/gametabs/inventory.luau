--!strict
local Host = require("@lib/host")
local widget_children = Host.widget_children
local selected_widget = Host.selected_widget
local item_container = Host.item_container
local sleep = Host.sleep
type Widget = Host.Widget
type MenuEntry = Host.MenuEntry
local Item = require("@lib/utils/item")
type Item = Item.Item
local Biometrics = require("@lib/main/antiban/biometrics")
local Geometry = require("@lib/utils/math/geometry")
type Point = Geometry.Point
local Interact = require("@lib/main/interact")
local Inv = require("@lib/main/interfaces/inv")
local Keyboard = require("@lib/utils/input/keyboard")
local Log = require("@lib/utils/log")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Mouse = require("@lib/utils/input/mouse")
local Random = require("@lib/utils/math/random")
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")
local Widgets = require("@lib/main/interfaces/widgets")

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

function Inventory.is_open(): boolean
	return SidePanels.is_open(SidePanels.INVENTORY)
end

function Inventory.free_slots(): number?
	return Inventory.count_empty()
end

function Inventory.is_full(): boolean
	local free = Inventory.free_slots()
	return free ~= nil and free == 0
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
	local ok = current.id == ITEMS_ID and Inventory.interact_slot(current.index, "Use")
	if not ok then
		local at = Mouse.position()
		if at == nil then
			return false
		end
		ok = Interact.with(at, "Cancel", nil, false)
	end
	if not ok then
		return false
	end
	if Widgets.wait_until(function()
		return selected_widget() == nil
	end, SELECT_TIMEOUT_MS) then
		return true
	end
	Log.log("Inventory", `{current.name} is still selected`)
	return false
end

function Inventory.select_slot(slot: number): boolean
	local current = selected_widget()
	if current ~= nil and current.id == ITEMS_ID and current.index == slot then
		return true
	end
	if current ~= nil and not Inventory.deselect() then
		return false
	end
	if not Inventory.interact_slot(slot, "Use") then
		return false
	end
	if Widgets.wait_until(function()
		return Inventory.is_selected(slot) == true
	end, SELECT_TIMEOUT_MS) then
		return true
	end
	Log.log("Inventory", `slot {slot} didn't get selected`)
	return false
end

function Inventory.select(items: Item | { Item }): boolean
	local slots = Inventory.indices_of(items)
	if slots == nil or #slots == 0 then
		return false
	end
	local current = Inventory.selected()
	if current and table.find(slots, current) then
		return true
	end
	return Inventory.select_slot(slots[math.random(1, #slots)])
end

function Inventory.combine_slots(slot_a: number, slot_b: number): boolean
	if not Inventory.select_slot(slot_a) then
		return false
	end
	Random.sleep(0, 600, "left")
	if not Inventory.interact_slot(slot_b, "Use") then
		return false
	end
	if Widgets.wait_until(function()
		return Inventory.selected() == nil
	end, SELECT_TIMEOUT_MS) then
		return true
	end
	Log.log("Inventory", `slot {slot_a} is still selected`)
	return false
end

function Inventory.combine(items_a: Item | { Item }, items_b: Item | { Item }): boolean
	if not Inventory.open() then
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

Inventory.PATTERN_HABIT = {
	turn = { 1, 2.5 },
	sloppy = { 0.12, 0.37 },
	finish = { 1.5, 3 },
	stick = { 0.85, 0.95 },
	corner_left = 0.7,
	corner_top = 0.7,
	along = 0.8,
	across = 1.3,
}

local COLUMNS, ROWS = 4, 7

type Habit = {
	rows: boolean,
	turn: number,
	sloppy: number,
	finish: number,
	stick: number,
	corner: number,
}

local function account_roll(hash: string, salt: number): number
	return Host.murmur2a(hash, salt) / 4294967295
end

local function habit(): Habit
	local hash = table.concat(Biometrics.hash(), ",")
	local ranges = Inventory.PATTERN_HABIT
	local function pick(range: { number }, salt: number): number
		return range[1] + (range[2] - range[1]) * account_roll(hash, salt)
	end
	local left = account_roll(hash, 1) < ranges.corner_left
	local top = account_roll(hash, 2) < ranges.corner_top
	return {
		rows = Biometrics.get_probability(Biometrics.PATTERN) < 0.5,
		turn = pick(ranges.turn, 3),
		sloppy = pick(ranges.sloppy, 4),
		finish = pick(ranges.finish, 5),
		stick = pick(ranges.stick, 6),
		corner = (if top then 0 else ROWS - 1) * COLUMNS + (if left then 0 else COLUMNS - 1),
	}
end

local function nearest_slot(slots: { number }, from: Point): number?
	local boxes = Inventory.boxes()
	if boxes == nil then
		return nil
	end
	local best, best_distance = nil, math.huge
	for _, slot in ipairs(slots) do
		local box = boxes[slot]
		if box then
			local dx = box.x + box.width / 2 - from.x
			local dy = box.y + box.height / 2 - from.y
			local distance = dx * dx + dy * dy
			if distance < best_distance then
				best, best_distance = slot, distance
			end
		end
	end
	return best
end

function Inventory.pattern(slots: { number }?, from: Point?): ({ number }, { boolean })
	local h = habit()
	local ranges = Inventory.PATTERN_HABIT
	local column_cost = if h.rows then ranges.along else ranges.across
	local row_cost = if h.rows then ranges.across else ranges.along

	local remaining: { [number]: boolean } = {}
	local left = 0
	local wanted = slots
	if wanted == nil then
		wanted = {}
		for slot = 0, SIZE - 1 do
			table.insert(wanted, slot)
		end
	end
	for _, slot in ipairs(wanted) do
		if not remaining[slot] then
			remaining[slot] = true
			left += 1
		end
	end

	local function line_of(slot: number): number
		return if h.rows then slot // COLUMNS else slot % COLUMNS
	end
	local function place_on_line(slot: number): number
		return if h.rows then slot % COLUMNS else slot // COLUMNS
	end
	local function heading_from(slot: number): Point
		if h.rows then
			return { x = if slot % COLUMNS <= (COLUMNS - 1) / 2 then 1 else -1, y = 0 }
		end
		return { x = 0, y = if slot // COLUMNS <= (ROWS - 1) / 2 then 1 else -1 }
	end
	local function heading_on_line(slot: number): Point?
		local farthest, gap = nil, 0
		for other in pairs(remaining) do
			if line_of(other) == line_of(slot) then
				local d = place_on_line(other) - place_on_line(slot)
				if math.abs(d) > gap then
					farthest, gap = d, math.abs(d)
				end
			end
		end
		if farthest == nil then
			return nil
		end
		local sign = if farthest > 0 then 1 else -1
		return if h.rows then { x = sign, y = 0 } else { x = 0, y = sign }
	end

	local mouse = from or Mouse.position()
	local current = (if mouse then nearest_slot(wanted, mouse) else nil) or h.corner
	local heading = heading_from(current)
	local snake = Biometrics.random_boolean(0.5)
	local order: { number } = {}
	local modes: { boolean } = {}
	if remaining[current] then
		remaining[current] = nil
		left -= 1
		table.insert(order, current)
		table.insert(modes, snake)
	end

	while left > 0 do
		if #order > 0 and Random.chance(1 - h.stick) then
			snake = not snake
		end
		local line_unfinished = false
		for slot in pairs(remaining) do
			if line_of(slot) == line_of(current) then
				line_unfinished = true
				break
			end
		end
		local choices: { number } = {}
		local directions: { Point } = {}
		local weights: { number } = {}
		for slot in pairs(remaining) do
			local dx = slot % COLUMNS - current % COLUMNS
			local dy = slot // COLUMNS - current // COLUMNS
			local length = math.sqrt(dx * dx + dy * dy)
			local direction = { x = dx / length, y = dy / length }
			local distance = math.sqrt((dx * column_cost) ^ 2 + (dy * row_cost) ^ 2)
			local away = (1 - (direction.x * heading.x + direction.y * heading.y)) / 2
			local leaving = if snake and line_unfinished and line_of(slot) ~= line_of(current) then h.finish else 0
			table.insert(choices, slot)
			table.insert(directions, direction)
			table.insert(weights, math.exp(-(distance + h.turn * away + leaving) / h.sloppy))
		end
		local i = Random.weighted_index(weights) or 1
		local picked = choices[i]
		remaining[picked] = nil
		left -= 1
		table.insert(order, picked)
		table.insert(modes, snake)
		local changed_line = line_of(picked) ~= line_of(current)
		current = picked
		heading = (if snake and changed_line then heading_on_line(current) else nil) or directions[i]
	end
	return order, modes
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
	if not Inventory.open() then
		return nil
	end
	if selected_widget() ~= nil and not Inventory.deselect() then
		return nil
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
	if slots == nil or #slots == 0 then
		return false
	end
	return Inventory.drop_slots(if pattern then in_order(slots, pattern) else (Inventory.pattern(slots)))
end

local function shift_drops(slot: number): boolean
	local matches = owns(slot)
	return Widgets.wait_until(function()
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
	if slots == nil or #slots == 0 then
		return false
	end
	return Inventory.shift_drop_slots(if pattern then in_order(slots, pattern) else (Inventory.pattern(slots)))
end

return Inventory
