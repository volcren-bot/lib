--!strict
local Host = require("../../../host")
local widget_children = Host.widget_children
type Widget = Host.Widget
local Item = require("../../../utils/item")
type Item = Item.Item
local BankpinKeypad = require("./bankpin_keypad")
local Chat = require("../chatbox/chat")
local Clickbox = require("../../clickbox")
local Interact = require("../../interact")
local Inv = require("../inv")
local Log = require("../../../utils/log")
local Minimenu = require("../minimenu")
local Mouse = require("../../../utils/input/mouse")
local Random = require("../../../utils/math/random")
local Npcs = require("../../entities/npcs")
local Objects = require("../../entities/objects")
local Toplevel = require("./toplevel")
local Walker = require("../../walker")
type Loc = Host.Loc
type Npc = Host.Npc
type Tile = Host.Tile

local CONTAINER = 95
local GROUP_ID = 12
-- The frame the close button is in, and the button's index in it (like the deposit box's frame).
local FRAME_CHILD = 2
local CLOSE_INDEX = 11
local CLOSE_MAX_SIZE = 60
-- The item grid: a widget with one child per slot (the child's index is the slot) and a scroll bar. The children of the tabs that aren't open are hidden.
local GRID_CHILD = 12
-- how far one mouse wheel notch scrolls the grid, in widget units (measured: 237 for 3 notches)
local SCROLL_NOTCH = 79
-- a slot only counts as shown when this much of it is inside the grid
local MIN_SHOWN = 0.5

local function grid(): Widget?
	local w = Host.widget(GROUP_ID, GRID_CHILD)
	if w == nil or w.hidden then
		return nil
	end
	return w
end

-- The slots that are shown in the grid right now (open tab, scrolled to), each clipped to the grid so a click lands inside it.
local function shown_slots(): { [number]: Widget }?
	local g = grid()
	if g == nil then
		return nil
	end
	local kids = widget_children(GROUP_ID, GRID_CHILD)
	if kids == nil then
		return nil
	end
	local top, bottom = g.y, g.y + g.height
	local found: { [number]: Widget } = {}
	for _, k in ipairs(kids) do
		if not k.hidden then
			local visible = math.min(k.y + k.height, bottom) - math.max(k.y, top)
			if visible >= k.height * MIN_SHOWN then
				local clipped = table.clone(k)
				clipped.y = math.max(k.y, top)
				clipped.height = visible
				found[k.index] = clipped
			end
		end
	end
	return found
end

-- The inventory as the open bank shows it (its own widget, not the inventory tab's): its items are deposited by clicking them.
local INVENTORY_CONTAINER = 93
local INVENTORY_SIZE = 28
local INVENTORY_GROUP = 15
local INVENTORY_CHILD = 3

local inventory = Inv.new(INVENTORY_CONTAINER, INVENTORY_SIZE, {
	open = function()
		return Toplevel.is_open(GROUP_ID)
	end,
	boxes = function(): { [number]: Widget }?
		local kids = widget_children(INVENTORY_GROUP, INVENTORY_CHILD)
		if kids == nil then
			return nil
		end
		local by_slot: { [number]: Widget } = {}
		for _, k in ipairs(kids) do
			if k.index >= 0 and not k.hidden then
				by_slot[k.index] = k
			end
		end
		return by_slot
	end,
	owns = function(slot: number)
		return function(entry: Host.MenuEntry): boolean
			return entry.id == INVENTORY_GROUP * 65536 + INVENTORY_CHILD and entry.index == slot
		end
	end,
})

local items = Inv.new(CONTAINER, nil, {
	open = function()
		return Toplevel.is_open(GROUP_ID)
	end,
	boxes = shown_slots,
	owns = function(slot: number)
		return function(entry: Host.MenuEntry): boolean
			return entry.id == GROUP_ID * 65536 + GRID_CHILD and entry.index == slot
		end
	end,
})

local OPEN_TIMEOUT_MS = 2400
local POLL_MS = 50
-- What opens a bank: booths and chests are objects, bankers are NPCs (all use "Bank", most objects also take "Use").
local OBJECT_NAMES = table.freeze({ "Bank booth", "Bank chest" })
local OBJECT_OPTIONS = table.freeze({ "Bank", "Use" })
local NPC_NAMES = table.freeze({ "Banker" })
local NPC_OPTIONS = table.freeze({ "Bank" })

-- The bank's buttons: ids of the widgets in the bank's group. The side ones can be missing (hidden) depending on the account and the bank.
export type Button =
	"ARRANGEMENT"
	| "NOTES"
	| "PLACEHOLDERS"
	| "SEARCH"
	| "DEPOSIT_CONTAINERS"
	| "DEPOSIT_INVENTORY"
	| "DEPOSIT_WORN"
	| "POTION_STORAGE"
	| "TUTORIAL"
export type Quantity = "ONE" | "FIVE" | "TEN" | "CUSTOM" | "ALL"
export type Arrangement = "SWAP" | "INSERT"

local BUTTONS: { [Button]: number } = {
	ARRANGEMENT = 23,
	NOTES = 25,
	PLACEHOLDERS = 40,
	SEARCH = 42,
	DEPOSIT_CONTAINERS = 45,
	DEPOSIT_INVENTORY = 47,
	DEPOSIT_WORN = 49,
	POTION_STORAGE = 53,
	TUTORIAL = 4,
}
local QUANTITY_BUTTONS: { [Quantity]: number } = { ONE = 29, FIVE = 31, TEN = 33, CUSTOM = 35, ALL = 37 }
-- the settings the buttons toggle (read from the client, not from how the buttons look)
local ARRANGEMENT_VARBIT = 3959 -- 1 insert, 0 swap
local NOTES_VARBIT = 3958 -- 1 withdraws as notes
local PLACEHOLDERS_VARBIT = 3755 -- 1 leaves placeholders
local QUANTITY_VARBIT = 6590
local CUSTOM_QUANTITY_VARBIT = 3960
local QUANTITIES: { [number]: Quantity } = { [0] = "ONE", [1] = "FIVE", [2] = "TEN", [3] = "CUSTOM", [4] = "ALL" }
local TITLE_CHILD = 3
local POTION_STORAGE_TITLE = "potion storage"
local SEARCH_QUERY = "Show items whose names contain"
local CUSTOM_QUANTITY_QUERY = "Enter amount"
local SETTING_TIMEOUT_MS = 2000
local SEARCH_TIMEOUT_MS = 2000
local ENTER_AMOUNT_TIMEOUT_MS = 2500
local MAX_TABS = 9
local SCROLL_TIMEOUT_MS = 8000
-- a way longer than this many notches is scrolled to a random place first
local SCROLL_FAR = 3
local SCROLL_BURST_MIN = 2
local SCROLL_BURST_MAX = 6
local SCROLL_PAUSE_MIN_MS = 60
local SCROLL_PAUSE_MAX_MS = 220
local SCROLL_SETTLE_MS = 250
local WITHDRAW_TIMEOUT_MS = 2500
local DEPOSIT_TIMEOUT_MS = 2500
-- tab 1's item count; the next 8 settings are the other tabs'
local TAB_SIZE_VARBIT = 4171

-- A bank to open: an object or an NPC, with the options that open it.
export type Source = { loc: Loc?, npc: Npc? }

local Bankmain = {
	-- the inventory as the bank shows it, with everything of Inv (see deposit)
	inventory = inventory,
	CONTAINER = CONTAINER,
	GROUP = GROUP_ID,
	-- the tab bar (child n is tab n) and the setting that holds the open tab (0 is the main tab)
	TABS_CHILD = 10,
	TAB_VARBIT = 4150,
	-- how many banks (the closest by straight distance) `nearest` plans a walk to
	PLAN_CANDIDATES = 6,
	slots = items.slots,
	items = items.items,
	indices_of = items.indices_of,
	index_of = items.index_of,
	find = items.find,
	contains = items.contains,
	contains_any = items.contains_any,
	contains_all = items.contains_all,
	box = items.box,
	boxes = items.boxes,
	slot_at = items.slot_at,
	hover_slot = items.hover_slot,
	click_slot = items.click_slot,
	interact_slot = items.interact_slot,
	slot_quantity = items.slot_quantity,
	quantity_of_item = items.quantity,
	count = items.count,
	count_ex = items.count_ex,
	wait_count = items.wait_count,
}

function Bankmain.is_open(): boolean
	if BankpinKeypad.is_open() then
		-- the injector enters the account's saved PIN; an account without one leaves the keypad to the player
		local entered = BankpinKeypad.enter()
		if entered ~= "entered" and entered ~= "no_pin" then
			Log.log("Bankmain", `the bank PIN wasn't entered: {entered}`)
			return false
		end
	end
	return Toplevel.is_open(Bankmain.GROUP)
end

-- The bank's close button, nil if it isn't where the frame keeps it (or doesn't look like a button).
function Bankmain.close_button(): Widget?
	local kids = widget_children(Bankmain.GROUP, FRAME_CHILD)
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

-- The open bank tab: 0 for the main tab (all items), 1 to 9 for the others. nil when it can't be read.
function Bankmain.tab(): number?
	return Host.varbit(Bankmain.TAB_VARBIT)
end

-- The button of a bank tab in the tab bar, nil when the bank is closed.
function Bankmain.tab_button(tab: number): Widget?
	for _, k in ipairs(widget_children(Bankmain.GROUP, Bankmain.TABS_CHILD) or {}) do
		if k.index == tab and not k.hidden then
			return k
		end
	end
	return nil
end

-- Opens a bank tab and waits for it to be open; open tab 0 to find any item by its bank slot. true when open.
function Bankmain.open_tab(tab: number, timeout_ms: number?): boolean
	if Bankmain.tab() == tab then
		return true
	end
	local button = Bankmain.tab_button(tab)
	if button == nil then
		return false
	end
	Mouse.click(button)
	local deadline = Host.time() + (timeout_ms or 2000)
	while Host.time() < deadline do
		if Bankmain.tab() == tab then
			return true
		end
		Host.sleep(100)
	end
	return Bankmain.tab() == tab
end

-- Whether the bank is open, polled every 50 ms for up to `timeout_ms` (3 seconds by default).
function Bankmain.wait_open(timeout_ms: number?): boolean
	local deadline = Host.time() + (timeout_ms or OPEN_TIMEOUT_MS)
	while true do
		if Bankmain.is_open() then
			return true
		end
		if Host.time() >= deadline then
			return false
		end
		Host.sleep(POLL_MS)
	end
end

-- How many tiles walking from the player to within reach of a bank takes (planned through doors, stairs and ladders), nil when no way is found.
-- A plan that stops short adds the straight distance left. Objects carry their plane; NPCs are on the player's.
local function walk_cost(at: Tile, plane: number?): number?
	local plan = Walker.plan(at, plane, { near = Clickbox.APPROACH_NEAR })
	if plan == nil then
		return nil
	end
	local cost = #plan.tiles
	if not plan.reached then
		local last = plan.tiles[#plan.tiles]
		if last then
			cost += Walker.distance(last, at)
		end
	end
	return cost
end

-- The bank that takes the fewest steps to walk to, from every booth, chest and banker loaded: the closest PLAN_CANDIDATES by straight distance are
-- planned (that is the expensive part), and the cheapest plan wins. Falls back to the closest by straight distance when none of them can be planned.
-- nil when none is loaded or the position is unknown.
function Bankmain.nearest(): Source?
	local me = Walker.position()
	if me == nil then
		return nil
	end
	type Candidate = { source: Source, straight: number, plane: number? }
	local candidates: { Candidate } = {}
	for _, name in ipairs(OBJECT_NAMES) do
		for _, loc in ipairs(Objects.find(name) or {}) do
			table.insert(
				candidates,
				{ source = { loc = loc, npc = nil }, straight = Objects.distance(loc, me), plane = loc.plane }
			)
		end
	end
	for _, name in ipairs(NPC_NAMES) do
		for _, npc in ipairs(Npcs.find(name) or {}) do
			table.insert(
				candidates,
				{ source = { loc = nil, npc = npc }, straight = Npcs.distance(npc, me), plane = nil }
			)
		end
	end
	table.sort(candidates, function(a: Candidate, b: Candidate)
		return a.straight < b.straight
	end)
	local best: Source? = nil
	local best_cost = math.huge
	for i = 1, math.min(#candidates, Bankmain.PLAN_CANDIDATES) do
		local c = candidates[i]
		local at: Tile = (c.source.loc or c.source.npc) :: Tile
		local cost = walk_cost(at, c.plane)
		if cost and cost < best_cost then
			best, best_cost = c.source, cost
		end
	end
	if best == nil and candidates[1] then
		return candidates[1].source
	end
	return best
end

local function resolve(source: Source?): Source?
	if source and (source.loc or source.npc) then
		return source
	end
	return Bankmain.nearest()
end

local function stand_near(source: Source): boolean
	local at: Tile = (source.loc or source.npc) :: Tile
	return Walker.walk({ x = math.floor(at.x), y = math.floor(at.y) }, { near = Clickbox.APPROACH_NEAR })
end

-- Hovers the closest bank (or `source`), walking closer first unless `walk` is false.
function Bankmain.hover(source: Source?, walk: boolean?): boolean
	local target = resolve(source)
	if target == nil then
		return false
	end
	if walk ~= false and not stand_near(target) then
		return false
	end
	if target.loc then
		return Objects.hover(target.loc)
	end
	return Npcs.hover(target.npc :: Npc)
end

-- Opens the closest bank (or `source`) and waits for it, walking closer first unless `walk` is false. Another interface in the way is closed first.
-- true when the bank is open (a PIN keypad in the way is handled by is_open).
function Bankmain.open(source: Source?, walk: boolean?): boolean
	if BankpinKeypad.is_open() then
		return Bankmain.wait_open()
	end
	if Toplevel.is_open(Bankmain.GROUP) then
		return Bankmain.is_open()
	end
	if not Toplevel.escape_clear() then
		return false
	end
	local target = resolve(source)
	if target == nil then
		Log.log("Bankmain", "no bank booth, chest or banker around")
		return false
	end
	local picked: boolean
	if target.loc then
		if walk ~= false then
			picked = Objects.approach(target.loc, OBJECT_OPTIONS)
		else
			picked = Objects.interact(target.loc, OBJECT_OPTIONS)
		end
	else
		local npc = target.npc :: Npc
		if walk ~= false then
			picked = Npcs.approach(npc, NPC_OPTIONS)
		else
			picked = Npcs.interact(npc, NPC_OPTIONS)
		end
	end
	if not picked then
		-- the menu was open on something else, or the click missed: take the bank option if what's hovered is a bank
		local uptext = Minimenu.uptext()
		if uptext == nil or not string.find(string.lower(uptext), "bank", 1, true) then
			return false
		end
		if not Minimenu.select("Bank") then
			return false
		end
	end
	return Bankmain.wait_open()
end

-- Polls until the setting `varbit` reads `value` (up to `timeout_ms`).
local function wait_varbit(varbit: number, value: number, timeout_ms: number): boolean
	local deadline = Host.time() + timeout_ms
	while true do
		if Host.varbit(varbit) == value then
			return true
		end
		if Host.time() >= deadline then
			return false
		end
		Host.sleep(POLL_MS)
	end
end

-- The button, nil when the bank is closed or the button isn't shown (the side buttons depend on the account and the bank).
function Bankmain.button(button: Button): Widget?
	local w = Host.widget(Bankmain.GROUP, BUTTONS[button])
	if w == nil or w.hidden then
		return nil
	end
	return w
end

-- Clicks the button. false if the bank isn't open or the button isn't shown.
function Bankmain.click_button(button: Button): boolean
	if not Toplevel.is_open(Bankmain.GROUP) then
		return false
	end
	local w = Bankmain.button(button)
	if w == nil then
		return false
	end
	Mouse.click(w)
	return true
end

-- Clicks `button` until `varbit` reads `value`; true when it does.
local function set_setting(button: Button, varbit: number, value: number, timeout_ms: number?): boolean
	local now = Host.varbit(varbit)
	if now == nil then
		return false
	end
	if now == value then
		return true
	end
	if not Bankmain.click_button(button) then
		return false
	end
	return wait_varbit(varbit, value, timeout_ms or SETTING_TIMEOUT_MS)
end

-- "SWAP" or "INSERT": what dragging an item onto another one does. nil when it can't be read.
function Bankmain.arrangement(): Arrangement?
	local v = Host.varbit(ARRANGEMENT_VARBIT)
	if v == nil then
		return nil
	end
	return if v == 1 then "INSERT" else "SWAP"
end

function Bankmain.set_arrangement(mode: Arrangement, timeout_ms: number?): boolean
	return set_setting("ARRANGEMENT", ARRANGEMENT_VARBIT, if mode == "INSERT" then 1 else 0, timeout_ms)
end

-- Whether items are withdrawn as notes.
function Bankmain.notes(): boolean?
	local v = Host.varbit(NOTES_VARBIT)
	if v == nil then
		return nil
	end
	return v == 1
end

function Bankmain.set_notes(on: boolean, timeout_ms: number?): boolean
	return set_setting("NOTES", NOTES_VARBIT, if on then 1 else 0, timeout_ms)
end

-- Whether withdrawing the last of an item leaves a placeholder ("Always set placeholders").
function Bankmain.placeholders(): boolean?
	local v = Host.varbit(PLACEHOLDERS_VARBIT)
	if v == nil then
		return nil
	end
	return v == 1
end

function Bankmain.set_placeholders(on: boolean, timeout_ms: number?): boolean
	return set_setting("PLACEHOLDERS", PLACEHOLDERS_VARBIT, if on then 1 else 0, timeout_ms)
end

-- The selected default quantity: "ONE", "FIVE", "TEN", "CUSTOM" (X) or "ALL".
function Bankmain.quantity(): Quantity?
	local v = Host.varbit(QUANTITY_VARBIT)
	if v == nil then
		return nil
	end
	return QUANTITIES[v]
end

-- The amount the X quantity button uses.
function Bankmain.custom_quantity(): number?
	return Host.varbit(CUSTOM_QUANTITY_VARBIT)
end

-- Which quantity button gives `amount`: 1, 5 and 10 have their own, 0 or less is all, the amount the X button already holds is X, and any other needs X set to it.
function Bankmain.quantity_of(amount: number): Quantity
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

-- Selects a quantity button and waits for it to be the selected one.
function Bankmain.select_quantity(quantity: Quantity, timeout_ms: number?): boolean
	local value = 0
	for v, q in pairs(QUANTITIES) do
		if q == quantity then
			value = v
		end
	end
	if Host.varbit(QUANTITY_VARBIT) == value then
		return true
	end
	if not Toplevel.is_open(Bankmain.GROUP) then
		return false
	end
	local w = Host.widget(Bankmain.GROUP, QUANTITY_BUTTONS[quantity])
	if w == nil or w.hidden then
		return false
	end
	Mouse.click(w)
	return wait_varbit(QUANTITY_VARBIT, value, timeout_ms or SETTING_TIMEOUT_MS)
end

-- Sets the amount of the X quantity button (right click, "Set custom quantity", type the amount). It also selects X, as the game does.
function Bankmain.set_custom_quantity(amount: number): boolean
	if amount < 1 then
		return false
	end
	if Bankmain.custom_quantity() == amount then
		return Bankmain.select_quantity("CUSTOM")
	end
	if not Toplevel.is_open(Bankmain.GROUP) then
		return false
	end
	local w = Host.widget(Bankmain.GROUP, QUANTITY_BUTTONS.CUSTOM)
	if w == nil or w.hidden then
		return false
	end
	if not Interact.with(w, "Set custom quantity", nil) then
		return false
	end
	if not Chat.answer_query(CUSTOM_QUANTITY_QUERY, tostring(math.floor(amount)), ENTER_AMOUNT_TIMEOUT_MS) then
		return false
	end
	return wait_varbit(CUSTOM_QUANTITY_VARBIT, math.floor(amount), SETTING_TIMEOUT_MS)
end

-- Selects the quantity that gives `amount` withdrawn or deposited per click: 1, 5, 10, all (0 or less) or a custom one (sets X first).
function Bankmain.set_quantity(amount: number): boolean
	local quantity = Bankmain.quantity_of(amount)
	if quantity == "CUSTOM" then
		return Bankmain.set_custom_quantity(amount)
	end
	return Bankmain.select_quantity(quantity)
end

function Bankmain.deposit_inventory(): boolean
	return Bankmain.click_button("DEPOSIT_INVENTORY")
end

function Bankmain.deposit_worn(): boolean
	return Bankmain.click_button("DEPOSIT_WORN")
end

-- The "Empty containers" button (loot bag, herb sack, ...); not shown unless the account has something to empty.
function Bankmain.deposit_containers(): boolean
	return Bankmain.click_button("DEPOSIT_CONTAINERS")
end

-- Whether the search prompt is showing in the chatbox.
function Bankmain.is_search_open(): boolean
	return Chat.find_query(SEARCH_QUERY)
end

-- Clicks the search button and waits for the search prompt. true when it is open.
function Bankmain.open_search(timeout_ms: number?): boolean
	if Bankmain.is_search_open() then
		return true
	end
	if not Bankmain.click_button("SEARCH") then
		return false
	end
	return Chat.wait_query(SEARCH_QUERY, timeout_ms or SEARCH_TIMEOUT_MS)
end

-- Searches the bank for `text` (opens the prompt, types it and presses Enter).
function Bankmain.search(text: string): boolean
	if not Bankmain.open_search() then
		return false
	end
	return Chat.answer_query(SEARCH_QUERY, text, SEARCH_TIMEOUT_MS)
end

-- Whether the account has the potion storage button here.
function Bankmain.has_potion_storage(): boolean
	return Bankmain.button("POTION_STORAGE") ~= nil
end

-- Whether the potion storage is the view showing in the bank window (it replaces the item grid, in the same window).
function Bankmain.potion_storage_is_open(): boolean
	local w = Host.widget(Bankmain.GROUP, TITLE_CHILD)
	if w == nil or w.text == nil then
		return false
	end
	return string.find(string.lower(w.text), POTION_STORAGE_TITLE, 1, true) ~= nil
end

-- Opens (or, from the potion storage, goes back from) the potion storage with its button; waits for the view to change.
function Bankmain.toggle_potion_storage(timeout_ms: number?): boolean
	local before = Bankmain.potion_storage_is_open()
	if not Bankmain.click_button("POTION_STORAGE") then
		return false
	end
	local deadline = Host.time() + (timeout_ms or SETTING_TIMEOUT_MS)
	while Host.time() < deadline do
		if Bankmain.potion_storage_is_open() ~= before then
			return true
		end
		Host.sleep(POLL_MS)
	end
	return false
end

function Bankmain.open_potion_storage(timeout_ms: number?): boolean
	return Bankmain.potion_storage_is_open() or Bankmain.toggle_potion_storage(timeout_ms)
end

function Bankmain.close_potion_storage(timeout_ms: number?): boolean
	return not Bankmain.potion_storage_is_open() or Bankmain.toggle_potion_storage(timeout_ms)
end

-- How many items each tab holds: tabs 1 to 9, in order (the main tab, 0, holds the rest). nil when the settings can't be read.
function Bankmain.tab_sizes(): { number }?
	local sizes: { number } = {}
	for tab = 1, MAX_TABS do
		local size = Host.varbit(TAB_SIZE_VARBIT + tab - 1)
		if size == nil then
			return nil
		end
		sizes[tab] = size
	end
	return sizes
end

-- How many tabs besides the main one hold items.
function Bankmain.count_tabs(): number?
	local sizes = Bankmain.tab_sizes()
	if sizes == nil then
		return nil
	end
	local count = 0
	for _, size in ipairs(sizes) do
		if size > 0 then
			count += 1
		end
	end
	return count
end

-- The tab a bank slot is in, 1 to 9, or 0 when it isn't in a tab. The container keeps each tab's items together, tab 1 first, then the others,
-- then the items that aren't in a tab, so a tab is a range of slots as long as its size.
function Bankmain.tab_of_slot(slot: number): number?
	local sizes = Bankmain.tab_sizes()
	if sizes == nil then
		return nil
	end
	local first = 0
	for tab, size in ipairs(sizes) do
		first += size
		if slot < first then
			return tab
		end
	end
	return 0
end

-- The tab an item is in and its slot, read from the bank's contents (no searching, no opening tabs). nil when the item isn't in the bank.
function Bankmain.find_tab(item: Item | { Item }): (number?, number?)
	local slot = items.index_of(item)
	if slot == nil then
		return nil, nil
	end
	return Bankmain.tab_of_slot(slot), slot
end

-- The slot's widget in the grid, shown or not: nil when it isn't a slot of the open tab (the other tabs' slots are hidden).
local function slot_widget(slot: number): Widget?
	for _, k in ipairs(widget_children(GROUP_ID, GRID_CHILD) or {}) do
		if k.index == slot then
			return if k.hidden then nil else k
		end
	end
	return nil
end

-- Whether the slot is in the open tab and shown in the grid (not scrolled out of it).
function Bankmain.is_slot_shown(slot: number): boolean
	local shown = shown_slots()
	return shown ~= nil and shown[slot] ~= nil
end

-- How far to scroll to bring the slot into the grid, in mouse wheel notches: positive down, negative up, 0 when it is already shown.
-- nil when the slot isn't in the open tab.
function Bankmain.scroll_distance(slot: number): number?
	local g, w = grid(), slot_widget(slot)
	if g == nil or w == nil then
		return nil
	end
	local top, bottom = g.y, g.y + g.height
	if w.y >= top and w.y + w.height <= bottom then
		return 0
	end
	local delta = if w.y < top then w.y - top else w.y + w.height - bottom
	return if delta > 0 then math.ceil(delta / SCROLL_NOTCH) else math.floor(delta / SCROLL_NOTCH)
end

-- Scrolls the grid until the slot is fully shown. A long way is scrolled in a few steps, aiming at a random place in the grid, and then fixed up by
-- what is left; a short way is just what is needed. The slot must be in the open tab (see show_slot). true when it is shown.
function Bankmain.scroll_to(slot: number, timeout_ms: number?): boolean
	local deadline = Host.time() + (timeout_ms or SCROLL_TIMEOUT_MS)
	local first = true
	while Host.time() < deadline do
		local g, w = grid(), slot_widget(slot)
		if g == nil or w == nil then
			return false
		end
		local need = Bankmain.scroll_distance(slot)
		if need == nil then
			return false
		end
		if need == 0 then
			return true
		end
		local notches = need
		-- the first move of a long way lands the slot somewhere inside the grid rather than at its edge
		if first and math.abs(need) > SCROLL_FAR then
			local aim = g.y + Random.float(0.15, 0.85) * (g.height - w.height)
			notches = math.round((w.y - aim) / SCROLL_NOTCH)
			if notches == 0 then
				notches = need
			end
		end
		first = false
		-- the wheel is turned in bursts, like a person does
		local direction = notches > 0
		local left = math.abs(notches)
		while left > 0 do
			local burst = math.min(left, Random.int(SCROLL_BURST_MIN, SCROLL_BURST_MAX))
			Mouse.scroll(burst, direction, if left == math.abs(notches) then g else nil)
			left -= burst
			if left > 0 then
				Random.sleep(SCROLL_PAUSE_MIN_MS, SCROLL_PAUSE_MAX_MS)
			end
		end
		Host.sleep(SCROLL_SETTLE_MS)
	end
	return Bankmain.is_slot_shown(slot)
end

-- Opens the tab the slot is in (the tab with its items, so the least scrolling) and scrolls to it. true when the slot is shown.
function Bankmain.show_slot(slot: number): boolean
	local tab = Bankmain.tab_of_slot(slot)
	if tab == nil then
		return false
	end
	if not Bankmain.open_tab(tab) then
		return false
	end
	return Bankmain.scroll_to(slot)
end

-- The amount for Bankmain.withdraw that takes all of an item but one.
Bankmain.ALL_BUT_ONE = -1

-- The slot of an item that has something to take: placeholders (quantity 0) are skipped. nil if the bank has none.
local function stocked_slot(item: Item | { Item }): number?
	local slots = items.indices_of(item)
	if slots == nil then
		return nil
	end
	for _, slot in ipairs(slots) do
		if (items.slot_quantity(slot) or 0) > 0 then
			return slot
		end
	end
	return nil
end

-- The menu option that takes `amount` out: Withdraw-1, -5, -10, -All, -All-but-1, the amount X holds, or Withdraw-X (then the amount is typed).
local function withdraw_option(amount: number): (string, boolean)
	if amount == Bankmain.ALL_BUT_ONE then
		return "Withdraw-All-but-1", false
	elseif amount <= 0 then
		return "Withdraw-All", false
	elseif amount == 1 or amount == 5 or amount == 10 then
		return `Withdraw-{amount}`, false
	elseif amount == Bankmain.custom_quantity() then
		return `Withdraw-{amount}`, false
	end
	return "Withdraw-X", true
end

-- Takes an item out of the bank into the inventory. `amount` is how many (1 if nil; 0 or less is all, ALL_BUT_ONE all but one), `noted` withdraws
-- as notes or items (nil leaves the setting alone), and unless `use_quantity_buttons` is false it selects the matching quantity button and clicks the
-- item, otherwise it picks the option from the item's menu. It opens the item's tab and scrolls to it. true once the bank holds less of it.
function Bankmain.withdraw(
	item: Item | { Item },
	amount: number?,
	noted: boolean?,
	use_quantity_buttons: boolean?
): boolean
	if not Bankmain.is_open() then
		return false
	end
	local slot = stocked_slot(item)
	if slot == nil then
		Log.log("Bankmain", "withdraw: the bank has none of it")
		return false
	end
	local wanted = amount or 1
	local stock = items.slot_quantity(slot) or 0
	-- asking for the whole stack or more is taking all of it
	if wanted > 0 and wanted >= stock then
		wanted = 0
	end
	if noted ~= nil and not Bankmain.set_notes(noted) then
		return false
	end
	local before = items.count_ex(item) or 0
	if use_quantity_buttons ~= false and wanted ~= Bankmain.ALL_BUT_ONE then
		if not Bankmain.set_quantity(wanted) then
			return false
		end
		-- the quantity buttons are in the bank's frame, the item may not be shown yet after changing tabs
		local current = stocked_slot(item)
		if current ~= nil then
			slot = current
		end
		if not Bankmain.show_slot(slot) then
			return false
		end
		if not items.click_slot(slot) then
			return false
		end
	else
		if not Bankmain.show_slot(slot) then
			return false
		end
		local option, typed = withdraw_option(wanted)
		if not items.interact_slot(slot, option) then
			return false
		end
		if
			typed
			and not Chat.answer_query(CUSTOM_QUANTITY_QUERY, tostring(math.floor(wanted)), ENTER_AMOUNT_TIMEOUT_MS)
		then
			return false
		end
	end
	local deadline = Host.time() + WITHDRAW_TIMEOUT_MS
	while Host.time() < deadline do
		if (items.count_ex(item) or before) < before then
			return true
		end
		Host.sleep(POLL_MS)
	end
	return false
end

-- What to deposit: an item (all of it), or an item with how many.
export type Deposit = { item: Item | { Item }, quantity: number? }
export type Entry = Item | Deposit

-- The menu option that puts `amount` in: Deposit-1, -5, -10, -All, the amount X holds, or Deposit-X (then the amount is typed).
local function deposit_option(amount: number): (string, boolean)
	if amount <= 0 then
		return "Deposit-All", false
	elseif amount == 1 or amount == 5 or amount == 10 or amount == Bankmain.custom_quantity() then
		return `Deposit-{amount}`, false
	end
	return "Deposit-X", true
end

local function deposit_slot(slot: number, amount: number, use_quantity_buttons: boolean): boolean
	if use_quantity_buttons then
		if not Bankmain.set_quantity(amount) then
			return false
		end
		return inventory.click_slot(slot)
	end
	local option, typed = deposit_option(amount)
	if not inventory.interact_slot(slot, option) then
		return false
	end
	if typed then
		return Chat.answer_query(CUSTOM_QUANTITY_QUERY, tostring(math.floor(amount)), ENTER_AMOUNT_TIMEOUT_MS)
	end
	return true
end

-- Puts an item from the inventory into the bank by clicking it. `amount` is how many (all of it if nil, 0 or less; the whole stack or more is all of
-- it too). By default it selects the quantity button for the amount and clicks the item, with `use_quantity_buttons` false it takes the option from
-- the item's menu. With several of an item in the inventory a random one is clicked. true once the inventory holds less of it.
function Bankmain.deposit(item: Item | { Item }, amount: number?, use_quantity_buttons: boolean?): boolean
	if not Bankmain.is_open() then
		return false
	end
	local slots = inventory.indices_of(item)
	if slots == nil or #slots == 0 then
		Log.log("Bankmain", "deposit: the inventory has none of it")
		return false
	end
	local have = inventory.count_ex(item) or 0
	local wanted = amount or 0
	if wanted > 0 and wanted >= have then
		wanted = 0
	end
	if not deposit_slot(slots[Random.int(1, #slots)], wanted, use_quantity_buttons ~= false) then
		return false
	end
	local deadline = Host.time() + DEPOSIT_TIMEOUT_MS
	while Host.time() < deadline do
		if (inventory.count_ex(item) or have) < have then
			return true
		end
		Host.sleep(POLL_MS)
	end
	return false
end

-- Deposits each entry (an item for all of it, or { item, quantity }); true when all of them went in.
function Bankmain.deposit_array(entries: { Entry }, use_quantity_buttons: boolean?): boolean
	local all_ok = true
	for _, entry in ipairs(entries) do
		local e: Deposit = if type(entry) == "table" and (entry :: any).item ~= nil
			then entry :: Deposit
			else { item = entry :: Item }
		if not Bankmain.deposit(e.item, e.quantity, use_quantity_buttons) then
			all_ok = false
		end
	end
	return all_ok
end

-- Deposits everything in the inventory except the items in `keep` (all of each kind, one kind after another).
function Bankmain.deposit_different(keep: Item | { Item }, use_quantity_buttons: boolean?): boolean
	local slots = inventory.find_different(keep)
	if slots == nil then
		return false
	end
	local done: { [number]: boolean } = {}
	for _, slot in ipairs(slots) do
		local s = inventory.item(slot)
		if s ~= nil and not done[s.id] then
			done[s.id] = true
			if not Bankmain.deposit(s.id, 0, use_quantity_buttons) then
				return false
			end
		end
	end
	return true
end

function Bankmain.close(key_probability: number?, timeout_ms: number?): boolean
	return Toplevel.close(Bankmain.GROUP, Bankmain.close_button, key_probability, timeout_ms)
end

return Bankmain
