--!strict
local Host = require("@lib/host")
local menu = Host.menu
local widget = Host.widget
local widget_children = Host.widget_children
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
local Chat = require("@lib/main/interfaces/chatbox/chat")
local House = require("@lib/main/house")
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Objects = require("@lib/main/entities/objects")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Widgets = require("@lib/main/interfaces/widgets")

local Nexus = {}

Nexus.GROUP = 17
Nexus.LISTS = { 12, 16 }
Nexus.VIEW = 11
Nexus.CONTINUE = "Continue"
Nexus.FRAME = 1
Nexus.CLOSE_INDEX = 13
Nexus.OBJECT = "Portal Nexus"
Nexus.OPTION = "Teleport Menu"
Nexus.OPEN_TIMEOUT_MS = 8000
Nexus.GONE_TIMEOUT_MS = 3000
Nexus.POLL_MS = 50
Nexus.SETTLE_MS = { 250, 500 }
Nexus.HOVER_TIMEOUT_MS = 800
Nexus.NOTCH_PIXELS = 79
Nexus.MAX_NOTCHES = 3
Nexus.MAX_SCROLLS = 30

export type Destination = {
	key: string,
	name: string,
	area: Widget,
}

function Nexus.is_open(): boolean
	return Toplevel.is_open(Nexus.GROUP)
end

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
	if not Widgets.wait_for(Nexus.is_open, Nexus.OPEN_TIMEOUT_MS, Nexus.POLL_MS) then
		return false, "the list didn't open"
	end
	Random.sleep(Nexus.SETTLE_MS[1], Nexus.SETTLE_MS[2])
	return true, nil
end

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

function Nexus.find(name: string): Destination?
	local all = Nexus.destinations() or {}
	for _, d in ipairs(all) do
		if string.lower(d.name) == string.lower(name) then
			return d
		end
	end
	for _, d in ipairs(all) do
		if House.same_place(d.name, name) then
			return d
		end
	end
	return nil
end

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
	return Widgets.wait_for(function()
		return not Nexus.is_open()
	end, Nexus.GONE_TIMEOUT_MS, Nexus.POLL_MS)
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
