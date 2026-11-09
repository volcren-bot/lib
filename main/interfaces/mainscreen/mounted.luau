--!strict
local Host = require("@lib/host")
local sleep = Host.sleep
local widget = Host.widget
local widget_children = Host.widget_children
type Widget = Host.Widget
local Chat = require("@lib/main/interfaces/chatbox/chat")
local House = require("@lib/main/house")
local Mouse = require("@lib/utils/input/mouse")
local Objects = require("@lib/main/entities/objects")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Widgets = require("@lib/main/interfaces/widgets")

local Mounted = {}

Mounted.GROUP = 187
Mounted.LIST = 3
Mounted.CLOSE = 4
Mounted.LOCKED_COLOUR = "5f5f5f"
Mounted.MENU_OPTION = "Teleport menu"
Mounted.CAPE_OPTION = "Teleport"
Mounted.OPEN_TIMEOUT_MS = 8000
Mounted.CLOSE_TIMEOUT_MS = 3000
Mounted.POLL_MS = 50
Mounted.SETTLE_MS = { 250, 500 }

export type Kind = "glory" | "cape" | "talisman" | "digsite"

export type Destination = {
	name: string,
	available: boolean,
	row: Widget,
}

function Mounted.is_open(): boolean
	return Toplevel.is_open(Mounted.GROUP)
end

function Mounted.destinations(): { Destination }?
	if not Mounted.is_open() then
		return nil
	end
	local found: { Destination } = {}
	for _, row in ipairs(widget_children(Mounted.GROUP, Mounted.LIST) or {}) do
		if row.kind == 4 and not row.hidden and row.text ~= nil then
			local name = string.match(Chat.clean(row.text), "^%w+:%s*(.+)$")
			if name ~= nil then
				local locked = string.find(row.text, `<col={Mounted.LOCKED_COLOUR}>`, 1, true) ~= nil
				table.insert(found, { name = name, available = not locked, row = row })
			end
		end
	end
	return found
end

function Mounted.find(name: string): Destination?
	local wanted = string.lower(name)
	local match: Destination? = nil
	for _, d in ipairs(Mounted.destinations() or {}) do
		if string.find(string.lower(d.name), wanted, 1, true) ~= nil then
			if match ~= nil then
				return nil
			end
			match = d
		end
	end
	return match
end

function Mounted.select(name: string): boolean
	local d = Mounted.find(name)
	if d == nil or not d.available then
		return false
	end
	Mouse.click(d.row)
	return Widgets.wait_for(function()
		return not Mounted.is_open()
	end, Mounted.CLOSE_TIMEOUT_MS, Mounted.POLL_MS)
end

function Mounted.close(): boolean
	return Toplevel.close(Mounted.GROUP, function(): Widget?
		return widget(Mounted.GROUP, Mounted.CLOSE)
	end)
end

local function wait_open(): boolean
	if not Widgets.wait_for(Mounted.is_open, Mounted.OPEN_TIMEOUT_MS, Mounted.POLL_MS) then
		return false
	end
	sleep(Random.int(Mounted.SETTLE_MS[1], Mounted.SETTLE_MS[2]))
	return true
end

function Mounted.teleport(kind: Kind, place: string): (boolean, string?, boolean?)
	local names = House.FURNITURE[kind]
	local loc = if names ~= nil then House.reach(names) else nil
	if loc == nil then
		return false, `no {kind} to reach in this house`, true
	end
	if kind == "glory" or kind == "cape" then
		local option = if kind == "cape" then Mounted.CAPE_OPTION else place
		if not Objects.approach(loc, option) then
			return false, `couldn't click {option}`
		end
		return true
	end
	if not Toplevel.escape_clear() then
		return false, "another interface is open"
	end
	if not Objects.approach(loc, Mounted.MENU_OPTION) then
		return false, `couldn't click {Mounted.MENU_OPTION}`
	end
	if not wait_open() then
		return false, "the list didn't open"
	end
	local d = Mounted.find(place)
	if d == nil or not d.available then
		Mounted.close()
		return false, `{place} isn't there or isn't unlocked`, true
	end
	if not Mounted.select(place) then
		Mounted.close()
		return false, `{place} couldn't be chosen`
	end
	return true
end

return Mounted
