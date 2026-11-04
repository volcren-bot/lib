--!strict
-- The minigame teleports, a spell on a 20 minute cooldown (varp 888), in its two ways. The "Minigame Teleport" spell opens a scrolling list (group 951, `minigames` in the cache), where a cell's "Select" starts the cast.
-- The Grouping view of the side channels tab (group 76, `grouping`) picks an activity from a dropdown, and its button then reads "Teleport to" the activity. Not every activity has a data row, and the two lists name some differently, so names are compared by their letters.
-- Rat Pits asks which pit, in a dialogue, either way. Starting a cast costs nothing: the cooldown only starts when it finishes, and a walk click stops it.
local Host = require("@lib/host")
local menu = Host.menu
local widget = Host.widget
local widget_children = Host.widget_children
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
local Biometrics = require("@lib/main/antiban/biometrics")
local ChatOptions = require("@lib/main/interfaces/chatbox/chat_options")
local Log = require("@lib/utils/log")
local Magic = require("@lib/main/interfaces/gametabs/magic")
local Mouse = require("@lib/utils/input/mouse")
local Random = require("@lib/utils/math/random")
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")

local Minigames = {}

Minigames.GROUP = 951
-- The scrolling part of the list, the frame that holds the close button as its child 11, the components searched for cells, and the label among a cell's children.
Minigames.VIEW = 4
Minigames.FRAME = 2
Minigames.CLOSE_INDEX = 11
Minigames.LAST_COMPONENT = 40
Minigames.LABEL_INDEX = 4
Minigames.SPELL = "Minigame Teleport"
Minigames.SELECT = "Select"
-- The activity that asks which pit.
Minigames.RAT_PITS = "Rat Pits"

Minigames.OPEN_TIMEOUT_MS = 3000
Minigames.HOVER_TIMEOUT_MS = 800
Minigames.DIALOGUE_TIMEOUT_MS = 3000
Minigames.POLL_MS = 50
-- The menu follows the mouse a frame or so late, and would still show the cell before.
Minigames.SETTLE_MS = 150
-- A pause (min, max in ms) after a list or the view shows, before it is used.
Minigames.OPEN_SETTLE_MS = { 250, 500 }
-- How far a notch of the wheel scrolls, the most notches at a time, and how many scrolls to try.
Minigames.NOTCH_PIXELS = 79
Minigames.MAX_NOTCHES = 3
Minigames.MAX_SCROLLS = 40

export type Teleport = {
	name: string,
	-- where it goes, as the list says
	location: string,
	-- the cell: where to hover and click
	area: Widget,
}

-- Letters only, in lowercase, with or without "Minigame Teleport" after them, so that the data's "Giant's Foundry Minigame Teleport" fits the list's "Giants' Foundry".
local function letters(text: string): string
	local only = string.gsub(string.lower(text), "%A", "")
	return (string.gsub(only, "minigameteleport$", ""))
end

-- Whether the menu where the mouse is now would pick `option` on a left click, waiting a moment for the game to show it. `id` and `index` are what its entry must have, when given.
local function offers(option: string, id: number?, index: number?): boolean
	local deadline = time() + Minigames.HOVER_TIMEOUT_MS
	while true do
		for _, entry in ipairs(menu() or {}) do
			if entry.option ~= "Cancel" then
				if
					entry.option == option
					and (id == nil or entry.id == id)
					and (index == nil or entry.index == index)
				then
					return true
				end
				break
			end
		end
		if time() >= deadline then
			return false
		end
		sleep(Minigames.POLL_MS)
	end
end

local function shown(w: Widget, view: Widget): boolean
	return w.y >= view.y and w.y + w.height <= view.y + view.height
end

-- Scrolls `view` until what `find` returns is fully shown, and returns it. Nil when it isn't there or the list wouldn't move.
local function scroll_to<T>(view: () -> Widget?, find: () -> T?, area: (T) -> Widget): T?
	local last: number? = nil
	for _ = 1, Minigames.MAX_SCROLLS do
		local v = view()
		local found = find()
		if v == nil or found == nil then
			return nil
		end
		local w = area(found)
		if shown(w, v) then
			return found
		end
		if last == w.y then
			return nil
		end
		last = w.y
		local down = w.y > v.y
		local away = if down then w.y + w.height - (v.y + v.height) else v.y - w.y
		local notches = math.clamp(math.ceil(away / Minigames.NOTCH_PIXELS), 1, Minigames.MAX_NOTCHES)
		Mouse.scroll(notches, down, v)
		Random.sleep(150, 300)
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- The spell's list
----------------------------------------------------------------------------------------------------

function Minigames.is_open(): boolean
	return Toplevel.is_open(Minigames.GROUP)
end

-- Whether the list is open, polled for up to `timeout_ms` (`OPEN_TIMEOUT_MS` by default).
function Minigames.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Minigames.OPEN_TIMEOUT_MS)
	while true do
		if Minigames.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Minigames.POLL_MS)
	end
end

-- Casts the spell, which opens the list, and waits for it. True when it is open, also if it already was. When it didn't work the second result says why.
function Minigames.open(): (boolean, string?)
	if Minigames.is_open() then
		return true, nil
	end
	if not Toplevel.escape_clear() then
		return false, "another interface is open"
	end
	if not (Magic.is_open() or Magic.open()) then
		return false, "the spellbook didn't open"
	end
	if not Magic.interact(Minigames.SPELL, "Cast") then
		return false, `couldn't cast {Minigames.SPELL}`
	end
	if not Minigames.wait_open() then
		return false, "the list didn't open"
	end
	Random.sleep(Minigames.OPEN_SETTLE_MS[1], Minigames.OPEN_SETTLE_MS[2])
	return true, nil
end

-- Every teleport in the list, top to bottom, read without hovering, including those scrolled out of view. Nil when the list isn't open.
function Minigames.teleports(): { Teleport }?
	if not Minigames.is_open() then
		return nil
	end
	local found: { Teleport } = {}
	for child = 0, Minigames.LAST_COMPONENT do
		local w = widget(Minigames.GROUP, child)
		if w ~= nil and not w.hidden and w.action == Minigames.SELECT then
			for _, k in ipairs(widget_children(Minigames.GROUP, child) or {}) do
				if k.index == Minigames.LABEL_INDEX and k.text ~= nil then
					local name, location = string.match(k.text, "^(.-)<br><col=%x+>(.*)$")
					table.insert(found, { name = name or k.text, location = location or "", area = w })
				end
			end
		end
	end
	table.sort(found, function(a: Teleport, b: Teleport)
		return if a.area.y ~= b.area.y then a.area.y < b.area.y else a.area.x < b.area.x
	end)
	return found
end

-- The teleport called `name`, by its letters. Nil when the list isn't open or has none.
function Minigames.find(name: string): Teleport?
	local wanted = letters(name)
	for _, t in ipairs(Minigames.teleports() or {}) do
		if letters(t.name) == wanted then
			return t
		end
	end
	return nil
end

-- Clicks a teleport in the list, scrolling to it first, which starts the cast (or for Rat Pits asks which pit). The click only happens once the menu under the mouse offers that cell. False when it isn't in the list or the click didn't happen.
function Minigames.select(name: string): boolean
	local t = scroll_to(function(): Widget?
		return widget(Minigames.GROUP, Minigames.VIEW)
	end, function(): Teleport?
		return Minigames.find(name)
	end, function(found: Teleport): Widget
		return found.area
	end)
	if t == nil then
		Log.log("Minigames", `{name} isn't in the list`)
		return false
	end
	Mouse.move(t.area)
	sleep(Minigames.SETTLE_MS)
	if not offers(Minigames.SELECT, t.area.id) then
		Log.log("Minigames", `the menu didn't offer {t.name}`)
		return false
	end
	Mouse.click()
	return true
end

-- The close button, nil when the list isn't open.
function Minigames.close_button(): Widget?
	if not Minigames.is_open() then
		return nil
	end
	for _, k in ipairs(widget_children(Minigames.GROUP, Minigames.FRAME) or {}) do
		if k.index == Minigames.CLOSE_INDEX and not k.hidden then
			return k
		end
	end
	return nil
end

-- Closes the list: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.
function Minigames.close(key_probability: number?): boolean
	if not Minigames.is_open() then
		return true
	end
	return Toplevel.close(
		Minigames.GROUP,
		Minigames.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

----------------------------------------------------------------------------------------------------
-- The Grouping view
----------------------------------------------------------------------------------------------------

local Grouping = {}
Minigames.Grouping = Grouping

Grouping.GROUP = 76
-- The side channels panel and its tab that shows this view.
Grouping.PANEL = 707
Grouping.TAB = 5
-- The dropdown, the text showing the activity, the open list and its scrolling part, and the button with its clickable child.
Grouping.DROPDOWN = 6
Grouping.SELECTED = 11
Grouping.LIST = 18
Grouping.ROWS = 22
Grouping.BUTTON = 32
-- What the text says with no activity, and the start of the button's option.
Grouping.NO_ACTIVITY = "Select an activity..."
Grouping.TELEPORT = "Teleport to"

export type Activity = {
	name: string,
	-- its place in the list
	index: number,
	-- the row: where to hover and click
	area: Widget,
}

-- Whether the view is showing.
function Grouping.is_open(): boolean
	if SidePanels.current() ~= SidePanels.SIDE_CHANNELS then
		return false
	end
	local w = widget(Grouping.GROUP, 0)
	return w ~= nil and not w.hidden and w.width > 0
end

-- Opens the side channels tab and its Grouping view. True when it is showing, also if it already was.
function Grouping.open(): boolean
	if Grouping.is_open() then
		return true
	end
	if SidePanels.open(SidePanels.SIDE_CHANNELS) ~= true then
		return false
	end
	sleep(Minigames.SETTLE_MS)
	if Grouping.is_open() then
		return true
	end
	local tab = widget(Grouping.PANEL, Grouping.TAB)
	if tab == nil or tab.hidden then
		return false
	end
	Mouse.click(tab)
	local deadline = time() + Minigames.OPEN_TIMEOUT_MS
	while time() < deadline do
		if Grouping.is_open() then
			Random.sleep(Minigames.OPEN_SETTLE_MS[1], Minigames.OPEN_SETTLE_MS[2])
			return true
		end
		sleep(Minigames.POLL_MS)
	end
	return false
end

-- The activity chosen now, nil when none is or the view isn't showing.
function Grouping.selected(): string?
	if not Grouping.is_open() then
		return nil
	end
	local w = widget(Grouping.GROUP, Grouping.SELECTED)
	if w == nil or w.text == nil or w.text == Grouping.NO_ACTIVITY then
		return nil
	end
	return w.text
end

-- Whether the dropdown's list is showing.
function Grouping.list_open(): boolean
	local w = widget(Grouping.GROUP, Grouping.LIST)
	return w ~= nil and not w.hidden and Grouping.is_open()
end

-- Every activity of the dropdown, top to bottom, including those scrolled out of view. Empty until its list has been shown once. Nil when the view isn't showing.
function Grouping.activities(): { Activity }?
	if not Grouping.is_open() then
		return nil
	end
	local found: { Activity } = {}
	for _, k in ipairs(widget_children(Grouping.GROUP, Grouping.ROWS) or {}) do
		if k.action == Minigames.SELECT and k.text ~= nil then
			table.insert(found, { name = k.text :: string, index = k.index, area = k })
		end
	end
	return found
end

-- Chooses an activity in the dropdown, opening its list and scrolling to it. True at once when it is chosen already. False when it isn't in the list or the choice didn't take.
function Grouping.choose(name: string): boolean
	if not Grouping.open() then
		return false
	end
	local wanted = letters(name)
	local chosen = Grouping.selected()
	if chosen ~= nil and letters(chosen) == wanted then
		return true
	end
	if not Grouping.list_open() then
		local dropdown = widget(Grouping.GROUP, Grouping.DROPDOWN)
		if dropdown == nil then
			return false
		end
		Mouse.click(dropdown)
		local deadline = time() + Minigames.OPEN_TIMEOUT_MS
		while not Grouping.list_open() do
			if time() >= deadline then
				return false
			end
			sleep(Minigames.POLL_MS)
		end
		Random.sleep(Minigames.OPEN_SETTLE_MS[1], Minigames.OPEN_SETTLE_MS[2])
	end
	local activity = scroll_to(function(): Widget?
		return widget(Grouping.GROUP, Grouping.ROWS)
	end, function(): Activity?
		for _, a in ipairs(Grouping.activities() or {}) do
			if letters(a.name) == wanted then
				return a
			end
		end
		return nil
	end, function(found: Activity): Widget
		return found.area
	end)
	if activity == nil then
		Log.log("Minigames", `{name} isn't among the activities`)
		local dropdown = widget(Grouping.GROUP, Grouping.DROPDOWN)
		if dropdown ~= nil then
			Mouse.click(dropdown)
		end
		return false
	end
	Mouse.move(activity.area)
	sleep(Minigames.SETTLE_MS)
	if not offers(Minigames.SELECT, nil, activity.index) then
		Log.log("Minigames", `the menu didn't offer {activity.name}`)
		return false
	end
	Mouse.click()
	local deadline = time() + Minigames.OPEN_TIMEOUT_MS
	while time() < deadline do
		local now = Grouping.selected()
		if now ~= nil and letters(now) == wanted then
			return true
		end
		sleep(Minigames.POLL_MS)
	end
	Log.log("Minigames", `choosing {activity.name} didn't take`)
	return false
end

-- The clickable part of the button, nil when the view isn't showing.
function Grouping.button(): Widget?
	if not Grouping.is_open() then
		return nil
	end
	for _, k in ipairs(widget_children(Grouping.GROUP, Grouping.BUTTON) or {}) do
		if not k.hidden then
			return k
		end
	end
	return nil
end

-- Chooses the activity and clicks the button, which starts the cast (or for Rat Pits asks which pit). The click only happens once the menu under the mouse offers that activity's teleport.
function Grouping.teleport(name: string): boolean
	if not Grouping.choose(name) then
		return false
	end
	local button = Grouping.button()
	local chosen = Grouping.selected()
	if button == nil or chosen == nil then
		return false
	end
	Mouse.move(button)
	sleep(Minigames.SETTLE_MS)
	if not offers(`{Grouping.TELEPORT} {chosen}`) then
		Log.log("Minigames", `the menu didn't offer the teleport to {chosen}`)
		return false
	end
	Mouse.click()
	return true
end

----------------------------------------------------------------------------------------------------
-- Either way
----------------------------------------------------------------------------------------------------

-- Answers the dialogue that asks which rat pit (`pit`: "Ardougne", "Varrock", "Keldagrim" or "Port Sarim"), by key or click, by click if the key doesn't take. False when it doesn't come or doesn't offer it.
function Minigames.choose_pit(pit: string): boolean
	local wanted = string.lower(pit)
	local deadline = time() + Minigames.DIALOGUE_TIMEOUT_MS
	while time() < deadline do
		for _, option in ipairs(ChatOptions.get() or {}) do
			if string.find(string.lower(option.text), wanted, 1, true) ~= nil then
				if not ChatOptions.select(option.text) and ChatOptions.find(option.text) ~= nil then
					return ChatOptions.select(option.text, nil, 0)
				end
				return true
			end
		end
		sleep(Minigames.POLL_MS)
	end
	Log.log("Minigames", `no dialogue offered the rat pit {pit}`)
	return false
end

-- Starts the teleport by the spell's list ("list") or the Grouping view ("grouping"), as the account's biometrics favour unless `via` says which. `pit` answers Rat Pits. The cast itself is not waited for.
-- When it didn't work the second result says why, and a list left open is closed.
function Minigames.teleport(name: string, pit: string?, via: ("list" | "grouping")?): (boolean, string?)
	local way = via or (if Biometrics.random_boolean(0.5) then "list" else "grouping")
	local started: boolean
	if way == "list" then
		local opened, why = Minigames.open()
		if not opened then
			return false, why
		end
		started = Minigames.select(name)
		if not started then
			Minigames.close()
		end
	else
		started = Grouping.teleport(name)
	end
	if not started then
		return false, `couldn't start the teleport to {name} by the {way}`
	end
	if pit ~= nil and not Minigames.choose_pit(pit) then
		return false, `couldn't choose the rat pit {pit}`
	end
	return true, nil
end

return Minigames
