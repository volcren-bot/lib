--!strict
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
local Widgets = require("@lib/main/interfaces/widgets")

local Minigames = {}

Minigames.GROUP = 951
Minigames.VIEW = 4
Minigames.FRAME = 2
Minigames.CLOSE_INDEX = 11
Minigames.LAST_COMPONENT = 40
Minigames.LABEL_INDEX = 4
Minigames.SPELL = "Minigame Teleport"
Minigames.SELECT = "Select"
Minigames.RAT_PITS = "Rat Pits"

Minigames.OPEN_TIMEOUT_MS = 3000
Minigames.HOVER_TIMEOUT_MS = 800
Minigames.DIALOGUE_TIMEOUT_MS = 3000
Minigames.POLL_MS = 50
Minigames.SETTLE_MS = 150
Minigames.OPEN_SETTLE_MS = { 250, 500 }
Minigames.NOTCH_PIXELS = 79
Minigames.MAX_NOTCHES = 3
Minigames.MAX_SCROLLS = 40

export type Teleport = {
	name: string,
	location: string,
	area: Widget,
}

local function letters(text: string): string
	local only = string.gsub(string.lower(text), "%A", "")
	return (string.gsub(only, "minigameteleport$", ""))
end

local function offers(option: string, id: number?, index: number?): boolean
	return Widgets.wait_for(function(): boolean
		for _, entry in ipairs(menu() or {}) do
			if entry.option ~= "Cancel" then
				return entry.option == option
					and (id == nil or entry.id == id)
					and (index == nil or entry.index == index)
			end
		end
		return false
	end, Minigames.HOVER_TIMEOUT_MS, Minigames.POLL_MS)
end

local function shown(w: Widget, view: Widget): boolean
	return w.y >= view.y and w.y + w.height <= view.y + view.height
end

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

function Minigames.is_open(): boolean
	return Toplevel.is_open(Minigames.GROUP)
end

function Minigames.wait_open(timeout_ms: number?): boolean
	return Widgets.wait_for(Minigames.is_open, timeout_ms or Minigames.OPEN_TIMEOUT_MS, Minigames.POLL_MS)
end

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

function Minigames.find(name: string): Teleport?
	local wanted = letters(name)
	for _, t in ipairs(Minigames.teleports() or {}) do
		if letters(t.name) == wanted then
			return t
		end
	end
	return nil
end

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

local Grouping = {}
Minigames.Grouping = Grouping

Grouping.GROUP = 76
Grouping.PANEL = 707
Grouping.TAB = 5
Grouping.DROPDOWN = 6
Grouping.SELECTED = 11
Grouping.LIST = 18
Grouping.ROWS = 22
Grouping.BUTTON = 32
Grouping.NO_ACTIVITY = "Select an activity..."
Grouping.TELEPORT = "Teleport to"

export type Activity = {
	name: string,
	index: number,
	area: Widget,
}

function Grouping.is_open(): boolean
	if SidePanels.current() ~= SidePanels.SIDE_CHANNELS then
		return false
	end
	local w = widget(Grouping.GROUP, 0)
	return w ~= nil and not w.hidden and w.width > 0
end

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

function Grouping.list_open(): boolean
	local w = widget(Grouping.GROUP, Grouping.LIST)
	return w ~= nil and not w.hidden and Grouping.is_open()
end

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
		if not Widgets.wait_for(Grouping.list_open, Minigames.OPEN_TIMEOUT_MS, Minigames.POLL_MS) then
			return false
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
	if
		Widgets.wait_within(function(): boolean
			local now = Grouping.selected()
			return now ~= nil and letters(now) == wanted
		end, Minigames.OPEN_TIMEOUT_MS, Minigames.POLL_MS)
	then
		return true
	end
	Log.log("Minigames", `choosing {activity.name} didn't take`)
	return false
end

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
