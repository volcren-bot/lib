--!strict
local Host = require("@lib/host")
local widget = Host.widget
local widget_children = Host.widget_children
type Widget = Host.Widget
type Loc = Host.Loc
type MenuEntry = Host.MenuEntry
local Item = require("@lib/utils/item")
type Item = Item.Item
local Biometrics = require("@lib/main/antiban/biometrics")
local Chat = require("@lib/main/interfaces/chatbox/chat")
local Interact = require("@lib/main/interact")
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Keyboard = require("@lib/utils/input/keyboard")
local Log = require("@lib/utils/log")
local Objects = require("@lib/main/entities/objects")
local Player = require("@lib/main/player")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Widgets = require("@lib/main/interfaces/widgets")

local Anvil = {}

Anvil.GROUP = 312
Anvil.FRAME = 1
Anvil.TITLE_INDEX = 1
Anvil.CLOSE_INDEX = 11
Anvil.QUANTITY_CHILDREN = table.freeze({ 3, 4, 5, 6, 7, 8 })
Anvil.FIRST_SLOT = 9
Anvil.LAST_SLOT = 38
Anvil.OBJECT = "anvil"
Anvil.OPTION = "Smith"
Anvil.QUANTITY_OPTION = "Quantity:"
Anvil.QUERY = "Enter amount"
Anvil.UNAVAILABLE_COLOR = 0x000000
Anvil.ENOUGH_BARS_COLOR = 0x00ff00

Anvil.KEY_CHANCE = 0.5

Anvil.OPEN_TIMEOUT_MS = 4000
Anvil.QUANTITY_TIMEOUT_MS = 1500
Anvil.CLOSE_TIMEOUT_MS = 2400
Anvil.MADE_TIMEOUT_MS = 3600
Anvil.POLL_MS = 50

export type Quantity = "All" | number

export type Slot = {
	child: number,
	id: number,
	name: string?,
	label: string,
	makes: number,
	bars: number,
	enough_bars: boolean,
	available: boolean,
	highlighted: boolean,
	option: string,
	area: Widget,
}

export type Button = {
	child: number,
	label: string,
	selected: boolean,
	area: Widget,
}

local function owns(child: number): (MenuEntry) -> boolean
	local id = Anvil.GROUP * 65536 + child
	return function(entry: MenuEntry): boolean
		return entry.id == id
	end
end

function Anvil.is_open(): boolean
	return Toplevel.is_open(Anvil.GROUP)
end

function Anvil.wait_open(timeout_ms: number?): boolean
	return Widgets.wait_for(Anvil.is_open, timeout_ms or Anvil.OPEN_TIMEOUT_MS, Anvil.POLL_MS)
end

function Anvil.title(): string?
	if not Anvil.is_open() then
		return nil
	end
	for _, k in ipairs(widget_children(Anvil.GROUP, Anvil.FRAME) or {}) do
		if k.index == Anvil.TITLE_INDEX then
			return k.text
		end
	end
	return nil
end

local function read_slot(child: number): Slot?
	local w = widget(Anvil.GROUP, child)
	if w == nil or w.hidden then
		return nil
	end
	local item: Widget? = nil
	local name: Widget? = nil
	local bars: Widget? = nil
	local highlighted = false
	for _, k in ipairs(widget_children(Anvil.GROUP, child) or {}) do
		if k.kind == Widgets.RECTANGLE and not k.hidden then
			highlighted = true
		elseif k.kind == Widgets.SPRITE and k.item_id ~= -1 then
			item = k
		elseif k.kind == Widgets.TEXT and k.text ~= nil then
			if string.match(k.text, "^%d+ bars?$") then
				bars = k
			else
				name = k
			end
		end
	end
	if item == nil or name == nil or bars == nil then
		return nil
	end
	return {
		child = child,
		id = item.item_id,
		name = nil,
		label = Chat.clean(name.text :: string),
		makes = item.item_quantity,
		bars = tonumber(string.match(bars.text :: string, "^%d+")) :: number,
		enough_bars = bars.text_color == Anvil.ENOUGH_BARS_COLOR,
		available = name.text_color ~= Anvil.UNAVAILABLE_COLOR,
		highlighted = highlighted,
		option = w.action or Anvil.OPTION,
		area = w,
	}
end

function Anvil.slots(): { Slot }?
	if not Anvil.is_open() then
		return nil
	end
	local found: { Slot } = {}
	for child = Anvil.FIRST_SLOT, Anvil.LAST_SLOT do
		local slot = read_slot(child)
		if slot then
			table.insert(found, slot)
		end
	end
	if #found == 0 then
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

function Anvil.find(items: Item | { Item }): Slot?
	local matcher = Item.matcher(items)
	for _, s in ipairs(Anvil.slots() or {}) do
		if Item.matches(matcher, s.id, s.name) then
			return s
		end
	end
	return nil
end

function Anvil.can_smith(items: Item | { Item }): boolean
	local slot = Anvil.find(items)
	return slot ~= nil and slot.available and slot.enough_bars
end

function Anvil.buttons(): { Button }?
	if not Anvil.is_open() then
		return nil
	end
	local found: { Button } = {}
	for _, child in ipairs(Anvil.QUANTITY_CHILDREN) do
		local w = widget(Anvil.GROUP, child)
		if w and not w.hidden then
			for _, k in ipairs(widget_children(Anvil.GROUP, child) or {}) do
				if k.kind == Widgets.TEXT and k.text ~= nil and k.text ~= "" then
					table.insert(found, {
						child = child,
						label = Chat.clean(k.text),
						selected = string.find(k.text, "<col=ffffff>", 1, true) ~= nil,
						area = w,
					})
				end
			end
		end
	end
	return found
end

function Anvil.quantity(): string?
	for _, b in ipairs(Anvil.buttons() or {}) do
		if b.selected then
			return b.label
		end
	end
	return nil
end

local function button(label: string): Button?
	for _, b in ipairs(Anvil.buttons() or {}) do
		if b.label == label then
			return b
		end
	end
	return nil
end

local function press(b: Button): boolean
	return (Interact.with(b.area, Anvil.QUANTITY_OPTION, owns(b.child), false))
end

function Anvil.set_quantity(quantity: Quantity): boolean
	if type(quantity) == "number" and (quantity < 1 or quantity ~= math.floor(quantity)) then
		Log.log("Anvil", `set_quantity: {quantity} isn't a whole number above 0`)
		return false
	end
	local wanted = tostring(quantity)
	if Anvil.quantity() == wanted then
		return true
	end
	local shown = button(wanted)
	if shown ~= nil then
		if not press(shown) then
			return false
		end
	elseif type(quantity) == "number" then
		local x = button("X")
		if x == nil then
			return Anvil.set_quantity("All")
		end
		if not press(x) or not Chat.answer_query(Anvil.QUERY, wanted) then
			return false
		end
	else
		Log.log("Anvil", `set_quantity: the {wanted} button isn't shown`)
		return false
	end
	if
		Widgets.wait_for(function()
			return Anvil.quantity() == wanted
		end, Anvil.QUANTITY_TIMEOUT_MS, Anvil.POLL_MS)
	then
		return true
	end
	Log.log("Anvil", `the quantity didn't change to {wanted}`)
	return false
end

function Anvil.smith(items: Item | { Item }, quantity: Quantity?, key_probability: number?): boolean
	local slot = Anvil.find(items)
	if slot == nil then
		Log.log("Anvil", "smith: the anvil doesn't offer that item")
		return false
	end
	if not slot.available or not slot.enough_bars then
		Log.log("Anvil", `smith: {slot.name or slot.label} can't be smithed`)
		return false
	end
	if not Anvil.set_quantity(quantity or "All") then
		return false
	end
	local before = Inventory.count_ex(slot.id)
	if before == nil then
		return false
	end
	local probability = if key_probability ~= nil and key_probability >= 0
		then key_probability
		else Biometrics.random_double(Anvil.KEY_CHANCE)
	if slot.highlighted and Random.chance(probability) then
		Keyboard.key_press(Keyboard.keys.SPACE)
	elseif not Interact.with(slot.area, slot.option, owns(slot.child), false) then
		return false
	end
	if not Widgets.wait_for(function()
		return not Anvil.is_open()
	end, Anvil.CLOSE_TIMEOUT_MS, Anvil.POLL_MS) then
		Log.log("Anvil", "the anvil didn't close")
		return false
	end
	return Widgets.wait_for(function(): boolean
		local now = Inventory.count_ex(slot.id)
		return now ~= nil and now > before
	end, Anvil.MADE_TIMEOUT_MS, Anvil.POLL_MS)
end

function Anvil.close_button(): Widget?
	for _, k in ipairs(widget_children(Anvil.GROUP, Anvil.FRAME) or {}) do
		if k.index == Anvil.CLOSE_INDEX and not k.hidden then
			return k
		end
	end
	return nil
end

function Anvil.close(): boolean
	if not Anvil.is_open() then
		return true
	end
	return Toplevel.close(Anvil.GROUP, Anvil.close_button, 0)
end

function Anvil.nearest(): Loc?
	local me = Player.position()
	if me == nil then
		return nil
	end
	local near: { Loc } = {}
	for _, loc in ipairs(Objects.find() or {}) do
		if loc.name ~= nil and string.find(string.lower(loc.name), Anvil.OBJECT, 1, true) then
			table.insert(near, loc)
		end
	end
	if #near == 0 then
		return nil
	end
	local ids: { number } = {}
	for i, loc in ipairs(near) do
		ids[i] = loc.id
	end
	local views = Host.loc_shown(ids)
	if views == nil then
		return nil
	end
	local best: Loc? = nil
	local best_distance = math.huge
	for i, loc in ipairs(near) do
		local view = views[i]
		local d = Objects.distance(loc, me)
		if view and table.find(view.actions, Anvil.OPTION) and d < best_distance then
			best, best_distance = loc, d
		end
	end
	return best
end

function Anvil.hover(anvil: Loc?): boolean
	local target = anvil or Anvil.nearest()
	if target == nil then
		Log.log("Anvil", "no anvil around")
		return false
	end
	return Objects.hover(target)
end

function Anvil.open(anvil: Loc?, walk: boolean?): (boolean, string?)
	if Anvil.is_open() then
		return true, nil
	end
	if not Toplevel.escape_clear() then
		return false, "another interface is open"
	end
	local target = anvil or Anvil.nearest()
	if target == nil then
		Log.log("Anvil", "no anvil around")
		return false, "no anvil around"
	end
	local picked = if walk ~= false
		then Objects.approach(target, Anvil.OPTION)
		else Objects.interact(target, Anvil.OPTION)
	if not picked then
		return false, `couldn't use {Anvil.OPTION} on the anvil`
	end
	if not Anvil.wait_open() then
		return false, "the anvil didn't open"
	end
	return true, nil
end

return Anvil
