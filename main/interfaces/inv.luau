--!strict
local Host = require("@lib/host")
local item_container = Host.item_container
local game_state = Host.game_state
local sleep = Host.sleep
type ItemSlot = Host.ItemSlot
type Widget = Host.Widget
type MenuEntry = Host.MenuEntry
local Item = require("@lib/utils/item")
type Item = Item.Item
local Geometry = require("@lib/utils/math/geometry")
local Random = require("@lib/utils/math/random")
type Point = Geometry.Point
local Mouse = require("@lib/utils/input/mouse")
type Button = Mouse.Button
local Interact = require("@lib/main/interact")
local Log = require("@lib/utils/log")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Widgets = require("@lib/main/interfaces/widgets")

export type Slot = {
	slot: number,
	id: number,
	quantity: number,
	name: string?,
}

export type View = {
	open: () -> boolean,
	boxes: () -> { [number]: Widget }?,
	owns: (slot: number) -> (MenuEntry) -> boolean,
	empty: (() -> { [number]: boolean }?)?,
}

export type Inv = {
	slots: () -> { ItemSlot }?,
	items: () -> { Slot }?,
	item: (slot: number) -> Slot?,
	indices_of: (items: Item | { Item }) -> { number }?,
	index_of: (items: Item | { Item }) -> number?,
	find: (item: Item | { Item }) -> number?,
	contains: (item: Item) -> boolean,
	contains_any: (items: { Item }) -> boolean,
	contains_all: (items: { Item }) -> boolean,
	find_different: (items: Item | { Item }) -> { number }?,
	contains_different: (items: Item | { Item }) -> boolean,
	count: (items: Item | { Item }) -> number?,
	count_ex: (items: Item | { Item }) -> number?,
	wait_count: (items: Item | { Item }, count: number, timeout_ms: number?, interval_ms: number?) -> boolean,
	quantity: (items: Item | { Item }) -> number?,
	slot_quantity: (slot: number) -> number?,
	used: () -> { number }?,
	empty: () -> { number }?,
	is_used: (slot: number) -> boolean,
	is_empty: (slot: number) -> boolean,
	count_used: () -> number?,
	count_empty: () -> number?,
	wait_used: (count: number, timeout_ms: number?, interval_ms: number?) -> boolean,
	open: () -> boolean,
	boxes: (slots: { number }?) -> { [number]: Widget }?,
	box: (slot: number) -> Widget?,
	slot_at: (at: Point?) -> number?,
	near: (slot: number, slots: { number }, max_dist: number?, remove_slot: boolean?) -> { number }?,
	random_near: (
		slot: number,
		slots: { number },
		max_dist: number?,
		remove_slot: boolean?,
		distribution: ("gauss" | "random")?
	) -> number?,
	hover_slot: (slot: number) -> boolean,
	click_slot: (slot: number, button: Button?) -> boolean,
	move_slot: (slot: number, destination: number) -> boolean,
	interact_slot: (slot: number, option: string?) -> boolean,
	hover: (items: Item | { Item }) -> boolean,
	click: (items: Item | { Item }, button: Button?) -> boolean,
	move: (items: Item | { Item }, destination: number) -> boolean,
	interact: (items: Item | { Item }, option: string?) -> boolean,
}

local Inv = {}

local POLL_MS = 50
local MOVE_TIMEOUT_MS = 1800

Inv.LOSES_ITEM = table.freeze({ Drop = true, Destroy = true, Release = true }) :: { [string]: boolean }

function Inv.new(container: number, size: number?, view: View?): Inv
	local function slots(): { ItemSlot }?
		local items = item_container(container)
		local empty = items and view and view.empty and view.empty()
		if items and empty and next(empty) then
			local fixed: { ItemSlot } = {}
			for i, s in ipairs(items) do
				fixed[i] = if empty[s.slot] then { slot = s.slot, id = s.id, quantity = 0 } else s
			end
			items = fixed
		end
		if size == nil then
			return items
		end
		local all: { ItemSlot } = {}
		for slot = 0, size - 1 do
			all[slot + 1] = (items and items[slot + 1]) or { slot = slot, id = -1, quantity = 0 }
		end
		return all
	end

	local function filled(with_names: boolean): { Slot }?
		local all = slots()
		if all == nil then
			return nil
		end
		local items: { Slot } = {}
		for _, s in ipairs(all) do
			if s.id ~= -1 then
				table.insert(items, { slot = s.slot, id = s.id, quantity = s.quantity })
			end
		end
		if with_names and #items > 0 then
			local ids: { number } = {}
			for i, s in ipairs(items) do
				ids[i] = s.id
			end
			local names = Item.names(ids)
			if names == nil then
				return nil
			end
			for i, s in ipairs(items) do
				s.name = names[i]
			end
		end
		return items
	end

	local function matching(items: Item | { Item }): { Slot }?
		local matcher = Item.matcher(items)
		local all = filled(Item.needs_names(matcher))
		if all == nil then
			return nil
		end
		local found: { Slot } = {}
		for _, s in ipairs(all) do
			if Item.matches(matcher, s.id, s.name) then
				table.insert(found, s)
			end
		end
		return found
	end

	local function item(slot: number): Slot?
		local all = filled(true)
		if all == nil then
			return nil
		end
		for _, s in ipairs(all) do
			if s.slot == slot then
				return s
			end
		end
		return nil
	end

	local function indices_of(items: Item | { Item }): { number }?
		local found = matching(items)
		if found == nil then
			return nil
		end
		local indices: { number } = {}
		for i, s in ipairs(found) do
			indices[i] = s.slot
		end
		return indices
	end

	local function index_of(items: Item | { Item }): number?
		local found = matching(items)
		if found == nil then
			return nil
		end
		return if found[1] then found[1].slot else nil
	end

	local function count(items: Item | { Item }): number?
		local found = matching(items)
		if found == nil then
			return nil
		end
		return #found
	end

	local function count_ex(items: Item | { Item }): number?
		local found = matching(items)
		if found == nil then
			return nil
		end
		local total = 0
		for _, s in ipairs(found) do
			total += s.quantity
		end
		return total
	end

	local function quantity(items: Item | { Item }): number?
		local found = matching(items)
		if found == nil then
			return nil
		end
		return if found[1] then found[1].quantity else 0
	end

	local function slot_quantity(slot: number): number?
		local s = item(slot)
		return if s then s.quantity else 0
	end

	local function contains_any(items: { Item }): boolean
		local n = count(items)
		return n ~= nil and n > 0
	end

	local function contains_all(items: { Item }): boolean
		local all = filled(Item.needs_names(Item.matcher(items)))
		if all == nil then
			return false
		end
		for _, item in ipairs(items) do
			local matcher = Item.matcher(item)
			local present = false
			for _, s in ipairs(all) do
				if Item.matches(matcher, s.id, s.name) then
					present = true
					break
				end
			end
			if not present then
				return false
			end
		end
		return true
	end

	local function find_different(items: Item | { Item }): { number }?
		local matcher = Item.matcher(items)
		local all = filled(Item.needs_names(matcher))
		if all == nil then
			return nil
		end
		local different: { number } = {}
		for _, s in ipairs(all) do
			if not Item.matches(matcher, s.id, s.name) then
				table.insert(different, s.slot)
			end
		end
		return different
	end

	local function contains_different(items: Item | { Item }): boolean
		local different = find_different(items)
		return different ~= nil and #different > 0
	end

	local function wait_number(read: () -> number?, wanted: number, timeout_ms: number?, interval_ms: number?): boolean
		return Widgets.wait_until(function()
			local n = read()
			return n ~= nil and n == wanted
		end, timeout_ms or 600, interval_ms or Random.trunc(Random.mode(100, 50, 1500)))
	end

	local function wait_count(
		items: Item | { Item },
		wanted: number,
		timeout_ms: number?,
		interval_ms: number?
	): boolean
		return wait_number(function()
			return count(items)
		end, wanted, timeout_ms, interval_ms)
	end

	local function used(): { number }?
		local all = filled(false)
		if all == nil then
			return nil
		end
		local indices: { number } = {}
		for i, s in ipairs(all) do
			indices[i] = s.slot
		end
		return indices
	end

	local function empty(): { number }?
		if size == nil then
			return nil
		end
		local all = slots()
		if all == nil then
			return nil
		end
		local indices: { number } = {}
		for _, s in ipairs(all) do
			if s.id == -1 then
				table.insert(indices, s.slot)
			end
		end
		return indices
	end

	local function is_used(slot: number): boolean
		return item(slot) ~= nil
	end

	local function count_used(): number?
		local indices = used()
		if indices == nil then
			return nil
		end
		return #indices
	end

	local function count_empty(): number?
		local indices = empty()
		if indices == nil then
			return nil
		end
		return #indices
	end

	local function wait_used(wanted: number, timeout_ms: number?, interval_ms: number?): boolean
		return wait_number(count_used, wanted, timeout_ms, interval_ms)
	end

	local function open(): boolean
		if view == nil then
			return false
		end
		return view.open()
	end

	local function boxes(wanted: { number }?): { [number]: Widget }?
		if view == nil then
			return nil
		end
		local all = view.boxes()
		if all == nil or wanted == nil then
			return all
		end
		local picked: { [number]: Widget } = {}
		for _, slot in ipairs(wanted) do
			picked[slot] = all[slot]
		end
		return picked
	end

	local function box(slot: number): Widget?
		local all = boxes()
		if all == nil then
			return nil
		end
		return all[slot]
	end

	local function slot_at(at: Point?): number?
		local p = at or Mouse.position()
		if p == nil then
			return nil
		end
		local all = boxes()
		if all == nil then
			return nil
		end
		for slot, w in pairs(all) do
			if Widgets.contains(w, p.x, p.y) then
				return slot
			end
		end
		return nil
	end

	local function nearest(
		slot: number,
		list: { number },
		max_dist: number,
		remove_slot: boolean
	): ({ number }?, { number }?)
		local all = boxes()
		if all == nil then
			return nil, nil
		end
		local from = all[slot]
		if from == nil then
			return nil, nil
		end
		local state = game_state()
		local scale = state.ui_scale or 1
		local center = Geometry.Box.center(Geometry.Box.from_area(from))
		type Near = { slot: number, dist: number }
		local found: { Near } = {}
		for _, s in ipairs(list) do
			local w = all[s]
			if w and not (remove_slot and s == slot) then
				local dist = Geometry.Point.distance(center, Geometry.Box.center(Geometry.Box.from_area(w))) / scale
				if dist <= max_dist then
					table.insert(found, { slot = s, dist = dist })
				end
			end
		end
		table.sort(found, function(a: Near, b: Near)
			return a.dist < b.dist
		end)
		local near: { number }, distances: { number } = {}, {}
		for i, f in ipairs(found) do
			near[i], distances[i] = f.slot, f.dist
		end
		return near, distances
	end

	local function near(slot: number, list: { number }, max_dist: number?, remove_slot: boolean?): { number }?
		return (nearest(slot, list, max_dist or 60, remove_slot ~= false))
	end

	local function random_near(
		slot: number,
		list: { number },
		max_dist: number?,
		remove_slot: boolean?,
		distribution: ("gauss" | "random")?
	): number?
		if #list == 0 then
			return nil
		elseif #list == 1 then
			return list[1]
		end
		local found, distances = nearest(slot, list, max_dist or 800, remove_slot ~= false)
		if found == nil or distances == nil or #found == 0 then
			return nil
		end
		if distribution == "random" then
			return found[math.random(1, #found)]
		end
		local limit = math.round(distances[1]) // 60
		local band = #found
		for i = 2, #found do
			if math.round(distances[i]) // 60 > limit then
				band = i - 1
				break
			end
		end
		return found[math.random(1, band)]
	end

	local function shown(slot: number): Widget?
		if not open() then
			return nil
		end
		return box(slot)
	end

	local function hover_slot(slot: number): boolean
		local w = shown(slot)
		if w == nil then
			return false
		end
		Mouse.move(w)
		return true
	end

	local function default_option(w: Widget, owns: (MenuEntry) -> boolean): string?
		Mouse.move(w)
		local waited = 0
		while true do
			for _, entry in ipairs(Minimenu.entries() or {}) do
				if owns(entry) then
					return entry.option
				end
			end
			if waited >= Interact.HOVER_TIMEOUT then
				return nil
			end
			sleep(POLL_MS)
			waited += POLL_MS
		end
	end

	local function click_slot(slot: number, button: Button?): boolean
		local w = shown(slot)
		if w == nil then
			return false
		end
		if (button == nil or button == "left") and view then
			local option = default_option(w, view.owns(slot))
			if option and Inv.LOSES_ITEM[option] then
				Log.log("Inv", `click_slot: slot {slot} would "{option}": not clicked`)
				return false
			end
			Mouse.click(nil, button)
			return true
		end
		Mouse.click(w, button)
		return true
	end

	local function interact_slot(slot: number, option: string?): boolean
		local s = item(slot)
		if s == nil then
			Log.log("Inv", `interact_slot: slot {slot} holds nothing`)
			return false
		end
		local w = shown(slot)
		if w == nil then
			Log.log("Inv", `interact_slot: slot {slot} isn't shown (the panel didn't open)`)
			return false
		end
		local owns = (view :: View).owns(slot)
		local wanted = option or default_option(w, owns)
		if wanted == nil then
			Log.log("Inv", `interact_slot: slot {slot} has no option to click`)
			return false
		end
		local ok = Interact.with(w, wanted, owns, false)
		if not ok then
			Log.log("Inv", `interact_slot: "{wanted}" on slot {slot} didn't go through`)
			return false
		end
		return true
	end

	local function move_slot(slot: number, destination: number): boolean
		if slot == destination then
			return true
		end
		local s = item(slot)
		if s == nil then
			return false
		end
		if not open() then
			return false
		end
		local all = boxes()
		if all == nil then
			return false
		end
		local from, to = all[slot], all[destination]
		if from == nil or to == nil then
			return false
		end
		Mouse.move(from)
		Mouse.hold()
		Random.sleep(50, 100, "left")
		Mouse.move(to)
		Mouse.release()
		Random.sleep(50, 100, "left")
		local moved = Widgets.wait_until(function()
			local now = item(destination)
			return now ~= nil and now.id == s.id
		end, MOVE_TIMEOUT_MS)
		if not moved then
			Log.log("Inv", `the item in slot {slot} didn't move to slot {destination}`)
			return false
		end
		return true
	end

	local function hover(items: Item | { Item }): boolean
		local slot = index_of(items)
		if slot == nil then
			return false
		end
		return hover_slot(slot)
	end

	local function click(items: Item | { Item }, button: Button?): boolean
		local slot = index_of(items)
		if slot == nil then
			return false
		end
		return click_slot(slot, button)
	end

	local function interact(items: Item | { Item }, option: string?): boolean
		local slot = index_of(items)
		if slot == nil then
			return false
		end
		return interact_slot(slot, option)
	end

	local function move(items: Item | { Item }, destination: number): boolean
		local found = indices_of(items)
		if found == nil or #found == 0 then
			return false
		end
		if table.find(found, destination) then
			return true
		end
		local closest = nearest(destination, found, math.huge, true)
		if closest == nil then
			return false
		end
		return move_slot(closest[1] or found[1], destination)
	end

	return {
		slots = slots,
		items = function()
			return filled(true)
		end,
		item = item,
		indices_of = indices_of,
		index_of = index_of,
		find = index_of,
		contains = function(item: Item)
			return contains_any({ item })
		end,
		contains_any = contains_any,
		contains_all = contains_all,
		find_different = find_different,
		contains_different = contains_different,
		count = count,
		count_ex = count_ex,
		wait_count = wait_count,
		quantity = quantity,
		slot_quantity = slot_quantity,
		used = used,
		empty = empty,
		is_used = is_used,
		is_empty = function(slot: number)
			return not is_used(slot)
		end,
		count_used = count_used,
		count_empty = count_empty,
		wait_used = wait_used,
		open = open,
		boxes = boxes,
		box = box,
		slot_at = slot_at,
		near = near,
		random_near = random_near,
		hover_slot = hover_slot,
		click_slot = click_slot,
		move_slot = move_slot,
		interact_slot = interact_slot,
		hover = hover,
		click = click,
		move = move,
		interact = interact,
	}
end

return Inv
