--!strict
local Host = require("@lib/host")
local widget_children = Host.widget_children
local item_container = Host.item_container
local sleep = Host.sleep
type Widget = Host.Widget
type MenuEntry = Host.MenuEntry
type Npc = Host.Npc
local Item = require("@lib/utils/item")
type Item = Item.Item
local Interact = require("@lib/main/interact")
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Npcs = require("@lib/main/entities/npcs")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Widgets = require("@lib/main/interfaces/widgets")

local GROUP = 300
local FRAME_CHILD = 1
local TITLE_INDEX = 1
local CLOSE_INDEX = 11
local CLOSE_MAX_SIZE = 60
local ITEMS_CHILD = 16
local INVENTORY_GROUP = 301
local INVENTORY_CHILD = 0
local INVENTORY_CONTAINER = 93
local INVENTORY_SIZE = 28
local POLL_MS = 50
local OPEN_TIMEOUT_MS = 4000
local TRANSFER_TIMEOUT_MS = 2400
local SCROLL_NOTCH = 79
local SCROLL_TRIES = 12
local MIN_SHOWN = 0.5
local OPTION_NAMES = table.freeze({ "Trade", "Talk-to" })

export type Slot = {
	slot: number,
	id: number,
	quantity: number,
	name: string?,
}

local Shopmain = {
	GROUP = GROUP,
	ITEMS_CHILD = ITEMS_CHILD,
	INVENTORY_GROUP = INVENTORY_GROUP,
	QUANTITIES = table.freeze({ 50, 10, 5, 1 }),
	OPTION = "Trade",
}

local function owned_by(group: number, child: number, offset: number): (number) -> (MenuEntry) -> boolean
	local id = group * 65536 + child
	return function(slot: number)
		return function(entry: MenuEntry): boolean
			return entry.id == id and entry.index == slot + offset
		end
	end
end

local stock_owns = owned_by(GROUP, ITEMS_CHILD, 1)
local inventory_owns = owned_by(INVENTORY_GROUP, INVENTORY_CHILD, 0)

function Shopmain.is_open(): boolean
	return Toplevel.is_open(GROUP)
end

function Shopmain.wait_open(timeout_ms: number?): boolean
	return Widgets.wait_for(Shopmain.is_open, timeout_ms or OPEN_TIMEOUT_MS, POLL_MS)
end

function Shopmain.title(): string?
	if not Shopmain.is_open() then
		return nil
	end
	for _, k in ipairs(widget_children(GROUP, FRAME_CHILD) or {}) do
		if k.index == TITLE_INDEX then
			return k.text
		end
	end
	return nil
end

function Shopmain.close_button(): Widget?
	local kids = widget_children(GROUP, FRAME_CHILD)
	if kids == nil then
		return nil
	end
	for _, k in ipairs(kids) do
		if k.index == CLOSE_INDEX then
			if k.hidden or k.width > CLOSE_MAX_SIZE or k.height > CLOSE_MAX_SIZE then
				return nil
			end
			return k
		end
	end
	return nil
end

function Shopmain.close(key_probability: number?, timeout_ms: number?): boolean
	if not Shopmain.is_open() then
		return true
	end
	return Toplevel.close(GROUP, Shopmain.close_button, key_probability, timeout_ms)
end

function Shopmain.open(npc: Npc): (boolean, string?)
	if Shopmain.is_open() then
		return true, nil
	end
	if not Npcs.interact(npc, OPTION_NAMES) then
		return false, `couldn't trade with {npc.name}`
	end
	if not Shopmain.wait_open() then
		return false, "the shop didn't open"
	end
	return true, nil
end

local function stock_widgets(): { Widget }?
	if not Shopmain.is_open() then
		return nil
	end
	local kids = widget_children(GROUP, ITEMS_CHILD)
	if kids == nil then
		return nil
	end
	local found: { Widget } = {}
	for _, k in ipairs(kids) do
		if k.index >= 1 and k.item_id ~= -1 then
			table.insert(found, k)
		end
	end
	return found
end

function Shopmain.slots(): { Slot }?
	local widgets = stock_widgets()
	if widgets == nil then
		return nil
	end
	local found: { Slot } = {}
	for i, w in ipairs(widgets) do
		found[i] = { slot = w.index - 1, id = w.item_id, quantity = w.item_quantity }
	end
	return found
end

function Shopmain.items(): { Slot }?
	local found = Shopmain.slots()
	if found == nil or #found == 0 then
		return found
	end
	local ids: { number } = {}
	for i, s in ipairs(found) do
		ids[i] = s.id
	end
	local names = Item.names(ids)
	if names == nil then
		return nil
	end
	for i, s in ipairs(found) do
		s.name = names[i]
	end
	return found
end

local function matching(items: Item | { Item }): { Slot }?
	local matcher = Item.matcher(items)
	local all = if Item.needs_names(matcher) then Shopmain.items() else Shopmain.slots()
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

function Shopmain.index_of(items: Item | { Item }): number?
	local found = matching(items)
	if found == nil then
		return nil
	end
	return if found[1] then found[1].slot else nil
end

function Shopmain.sells(items: Item | { Item }): boolean
	local found = matching(items)
	return found ~= nil and #found > 0
end

function Shopmain.stock(items: Item | { Item }): number?
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

function Shopmain.in_stock(items: Item | { Item }): boolean
	local stock = Shopmain.stock(items)
	return stock ~= nil and stock > 0
end

local function stock_grid(): Widget?
	local w = Host.widget(GROUP, ITEMS_CHILD)
	if w == nil or w.hidden then
		return nil
	end
	return w
end

local function stock_widget(slot: number): Widget?
	for _, k in ipairs(widget_children(GROUP, ITEMS_CHILD) or {}) do
		if k.index == slot + 1 and k.item_id ~= -1 then
			return k
		end
	end
	return nil
end

local function shown(grid: Widget, w: Widget): boolean
	local visible = math.min(w.y + w.height, grid.y + grid.height) - math.max(w.y, grid.y)
	return visible >= w.height * MIN_SHOWN
end

function Shopmain.is_slot_shown(slot: number): boolean
	local grid, w = stock_grid(), stock_widget(slot)
	return grid ~= nil and w ~= nil and shown(grid, w)
end

function Shopmain.show_slot(slot: number): boolean
	for _ = 1, SCROLL_TRIES do
		local grid, w = stock_grid(), stock_widget(slot)
		if grid == nil or w == nil then
			return false
		end
		if shown(grid, w) then
			return true
		end
		local below = w.y > grid.y
		local rows = math.max(1, math.floor(math.abs(w.y - grid.y) / SCROLL_NOTCH))
		Mouse.scroll(math.min(rows, Random.int(1, 3)), below, grid)
		sleep(Random.int(120, 260))
	end
	return Shopmain.is_slot_shown(slot)
end

function Shopmain.box(slot: number): Widget?
	local grid, w = stock_grid(), stock_widget(slot)
	if grid == nil or w == nil or not shown(grid, w) then
		return nil
	end
	local clipped = table.clone(w)
	clipped.y = math.max(w.y, grid.y)
	clipped.height = math.min(w.y + w.height, grid.y + grid.height) - clipped.y
	return clipped
end

function Shopmain.hover_slot(slot: number): boolean
	if not Shopmain.show_slot(slot) then
		return false
	end
	local w = Shopmain.box(slot)
	if w == nil then
		return false
	end
	Mouse.move(w)
	return true
end

function Shopmain.interact_slot(slot: number, option: string): boolean
	if not Shopmain.show_slot(slot) then
		Log.log("Shopmain", `interact_slot: slot {slot} isn't shown`)
		return false
	end
	local w = Shopmain.box(slot)
	if w == nil then
		return false
	end
	return Interact.with(w, option, stock_owns(slot), false)
end

local function held(id: number): number
	local total = 0
	for _, s in ipairs(item_container(INVENTORY_CONTAINER) or {}) do
		if s.id == id then
			total += s.quantity
		end
	end
	return total
end

local function free_slots(): number
	local used = 0
	for _, s in ipairs(item_container(INVENTORY_CONTAINER) or {}) do
		if s.id ~= -1 then
			used += 1
		end
	end
	return INVENTORY_SIZE - used
end

local function wait_held_change(id: number, before: number, timeout_ms: number): number
	local now = before
	Widgets.wait_within(function(): boolean
		now = held(id)
		return now ~= before
	end, timeout_ms, POLL_MS)
	return now
end

function Shopmain.buy_slot(slot: number, quantity: number): boolean
	return Shopmain.interact_slot(slot, `Buy {quantity}`)
end

function Shopmain.buy(item: Item, amount: number?, overshoot: boolean?): number
	local wanted = amount or 1
	local bought = 0
	while bought < wanted do
		local slot = Shopmain.index_of(item)
		if slot == nil then
			break
		end
		local w = stock_widget(slot)
		if w == nil or w.item_quantity <= 0 then
			break
		end
		local id = w.item_id
		local held_before = held(id)
		if free_slots() == 0 and (held_before == 0 or (Host.item_stackable({ id }) or {})[1] ~= true) then
			break
		end
		local remaining = math.min(wanted - bought, w.item_quantity)
		local step = 1
		for _, quantity in ipairs(Shopmain.QUANTITIES) do
			if quantity <= remaining or overshoot == true then
				step = quantity
				break
			end
		end
		if not Shopmain.buy_slot(slot, step) then
			break
		end
		local after = wait_held_change(id, held_before, TRANSFER_TIMEOUT_MS)
		if after <= held_before then
			break
		end
		bought += after - held_before
	end
	return bought
end

function Shopmain.inventory_slots(): { Slot }?
	local all = item_container(INVENTORY_CONTAINER)
	if all == nil then
		return nil
	end
	local found: { Slot } = {}
	for _, s in ipairs(all) do
		if s.id ~= -1 then
			table.insert(found, { slot = s.slot, id = s.id, quantity = s.quantity })
		end
	end
	return found
end

function Shopmain.inventory_box(slot: number): Widget?
	if not Shopmain.is_open() then
		return nil
	end
	for _, k in ipairs(widget_children(INVENTORY_GROUP, INVENTORY_CHILD) or {}) do
		if k.index == slot and not k.hidden then
			return k
		end
	end
	return nil
end

function Shopmain.interact_inventory_slot(slot: number, option: string): boolean
	local w = Shopmain.inventory_box(slot)
	if w == nil then
		Log.log("Shopmain", `interact_inventory_slot: slot {slot} isn't shown`)
		return false
	end
	return Interact.with(w, option, inventory_owns(slot), false)
end

function Shopmain.sell_slot(slot: number, quantity: number): boolean
	return Shopmain.interact_inventory_slot(slot, `Sell {quantity}`)
end

local function inventory_named(): { Slot }?
	local found = Shopmain.inventory_slots()
	if found == nil or #found == 0 then
		return found
	end
	local ids: { number } = {}
	for i, s in ipairs(found) do
		ids[i] = s.id
	end
	local names = Item.names(ids)
	if names == nil then
		return nil
	end
	for i, s in ipairs(found) do
		s.name = names[i]
	end
	return found
end

function Shopmain.sell(item: Item, amount: number?): number
	local matcher = Item.matcher(item)
	local wanted = amount or 1
	local sold = 0
	while sold < wanted do
		local target: Slot? = nil
		for _, s in ipairs(inventory_named() or {}) do
			if Item.matches(matcher, s.id, s.name) then
				target = s
				break
			end
		end
		if target == nil then
			break
		end
		local id = target.id
		local held_before = held(id)
		local remaining = math.min(wanted - sold, held_before)
		local step = 1
		for _, quantity in ipairs(Shopmain.QUANTITIES) do
			if quantity <= remaining then
				step = quantity
				break
			end
		end
		if not Shopmain.sell_slot(target.slot, step) then
			break
		end
		local after = wait_held_change(id, held_before, TRANSFER_TIMEOUT_MS)
		if after >= held_before then
			break
		end
		sold += held_before - after
	end
	return sold
end

function Shopmain.value_slot(slot: number): boolean
	return Shopmain.interact_slot(slot, "Value")
end

function Shopmain.value_inventory_slot(slot: number): boolean
	return Shopmain.interact_inventory_slot(slot, "Value")
end

return Shopmain
