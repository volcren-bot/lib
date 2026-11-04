--!strict
-- The Portal Nexus in a player's house (group 17, `telenexus_teleport` in the cache): up to 33 teleports in two lists, opened by "Teleport Menu". The list's names are short ("Fenken' Castle"), so `find` is loose.
-- The rows scroll in a view far shorter than the list, and below the view a click would land on the floor, so a row is scrolled to first and only clicked once the menu offers it. Each list's rows are text, and the component after it holds the rows' clickable areas, by the same index.
local Host = require("@lib/host")
local menu = Host.menu
local widget = Host.widget
local widget_children = Host.widget_children
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
type Loc = Host.Loc
local Chat = require("@lib/main/interfaces/chatbox/chat")
local House = require("@lib/main/house")
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Objects = require("@lib/main/entities/objects")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")

local Nexus = {}

Nexus.GROUP = 17
Nexus.LISTS = { 12, 16 }
-- The scrolling view, and the option a row offers.
Nexus.VIEW = 11
Nexus.CONTINUE = "Continue"
-- The frame holds the close button as its child 13.
Nexus.FRAME = 1
Nexus.CLOSE_INDEX = 13
Nexus.OBJECT = "Portal Nexus"
Nexus.OPTION = "Teleport Menu"
Nexus.OPEN_TIMEOUT_MS = 8000
Nexus.GONE_TIMEOUT_MS = 3000
Nexus.POLL_MS = 50
-- A pause (min, max in ms) after the list opens.
Nexus.SETTLE_MS = { 250, 500 }
Nexus.HOVER_TIMEOUT_MS = 800
-- How far a notch of the wheel scrolls, the most notches at a time, and how many scrolls to try.
Nexus.NOTCH_PIXELS = 79
Nexus.MAX_NOTCHES = 3
Nexus.MAX_SCROLLS = 30

export type Destination = {
	key: string,
	name: string,
	-- where to click
	area: Widget,
}

function Nexus.is_open(): boolean
	return Toplevel.is_open(Nexus.GROUP)
end

-- Opens the list, going to the Nexus's floor and walking to it. False and why.
function Nexus.open(): (boolean, string?)
	if Nexus.is_open() then
		return true, nil
	end
	local nexus = House.reach(Nexus.OBJECT)
	if nexus == nil then
		return false, "no Portal Nexus in this house"
	end
	if not Objects.approach(nexus, Nexus.OPTION) then
		return false, `couldn't use {Nexus.OPTION}`
	end
	local deadline = time() + Nexus.OPEN_TIMEOUT_MS
	while not Nexus.is_open() do
		if time() >= deadline then
			return false, "the list didn't open"
		end
		sleep(Nexus.POLL_MS)
	end
	Random.sleep(Nexus.SETTLE_MS[1], Nexus.SETTLE_MS[2])
	return true, nil
end

-- Every teleport of the open list. Nil when it isn't open.
function Nexus.destinations(): { Destination }?
	if not Nexus.is_open() then
		return nil
	end
	local found: { Destination } = {}
	for _, list in ipairs(Nexus.LISTS) do
		local rows = widget_children(Nexus.GROUP, list) or {}
		local areas: { [number]: Widget } = {}
		if #rows > 0 then
			for _, area in ipairs(widget_children(Nexus.GROUP, list + 1) or {}) do
				areas[area.index] = area
			end
		end
		for _, row in ipairs(rows) do
			if row.kind == 4 and not row.hidden and row.text ~= nil then
				local key, name = string.match(Chat.clean(row.text), "^(%w+)%s*:%s*(.+)$")
				if key ~= nil and name ~= nil then
					local area = areas[row.index]
					if area then
						table.insert(found, { key = key, name = name, area = area })
					end
				end
			end
		end
	end
	return found
end

local function plain(text: string): string
	return (string.gsub(string.lower(text), "[^%w ]", ""))
end

-- The teleport called `name`: the exact name, else one that starts with the other, else a list name whose first word starts the wanted one's ("Fenken' Castle" for "Fenkenstrain's Castle").
function Nexus.find(name: string): Destination?
	local all = Nexus.destinations() or {}
	local wanted = plain(name)
	for _, d in ipairs(all) do
		if plain(d.name) == wanted then
			return d
		end
	end
	for _, d in ipairs(all) do
		local have = plain(d.name)
		if string.sub(have, 1, #wanted) == wanted or string.sub(wanted, 1, #have) == have then
			return d
		end
	end
	local first = string.match(wanted, "^%S+") or wanted
	for _, d in ipairs(all) do
		local head = string.match(plain(d.name), "^%S+") or ""
		if #head >= 4 and string.sub(first, 1, #head) == head then
			return d
		end
	end
	return nil
end

-- Scrolls until the teleport is fully in view, and returns it. Nil when it isn't in the list or the list won't scroll.
local function scroll_to(name: string): Destination?
	local last: number? = nil
	for _ = 1, Nexus.MAX_SCROLLS do
		local view = widget(Nexus.GROUP, Nexus.VIEW)
		local d = Nexus.find(name)
		if view == nil or d == nil then
			return nil
		end
		local y, height = d.area.y, d.area.height
		if y >= view.y and y + height <= view.y + view.height then
			return d
		end
		if last == y then
			return nil
		end
		last = y
		local down = y > view.y
		local away = if down then y + height - (view.y + view.height) else view.y - y
		Mouse.scroll(math.clamp(math.ceil(away / Nexus.NOTCH_PIXELS), 1, Nexus.MAX_NOTCHES), down, view)
		Random.sleep(150, 300)
	end
	return nil
end

-- Whether the menu where the mouse is now would pick this row on a left click, waiting a moment for the game to show it.
local function offers(area: Widget): boolean
	local deadline = time() + Nexus.HOVER_TIMEOUT_MS
	repeat
		local first = (menu() or {})[1]
		if first ~= nil and first.option == Nexus.CONTINUE and first.id == area.id and first.index == area.index then
			return true
		end
		sleep(Nexus.POLL_MS)
	until time() >= deadline
	return false
end

-- Scrolls to a teleport of the open list and clicks it once the menu offers it. True once the list has gone: the trip follows.
function Nexus.select(name: string): boolean
	local d = scroll_to(name)
	if d == nil then
		return false
	end
	Mouse.move(d.area)
	if not offers(d.area) then
		Log.log("Nexus", `the menu didn't offer {d.name}`)
		return false
	end
	Mouse.click()
	local deadline = time() + Nexus.GONE_TIMEOUT_MS
	while Nexus.is_open() do
		if time() >= deadline then
			return false
		end
		sleep(Nexus.POLL_MS)
	end
	return true
end

function Nexus.close(): boolean
	return Toplevel.close(Nexus.GROUP, function(): Widget?
		for _, child in ipairs(widget_children(Nexus.GROUP, Nexus.FRAME) or {}) do
			if child.index == Nexus.CLOSE_INDEX then
				return child
			end
		end
		return widget(Nexus.GROUP, Nexus.FRAME)
	end)
end

return Nexus
