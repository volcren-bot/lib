--!strict
-- What a house has mounted on its walls: the amulet of glory, the mythical cape, Xeric's talisman and the digsite pendant. The trips are free.
-- The glory names its places as options and the cape's "Teleport" has one place. The talisman and the pendant list theirs under "Teleport menu" (group 187, the game's generic `menu` list), and their first options change with the "Configuration" the player set, so those aren't used. Their "Remove" option takes them out of the house, and nothing here can click it.
local Host = require("@lib/host")
local sleep = Host.sleep
local time = Host.time
local widget = Host.widget
local widget_children = Host.widget_children
type Widget = Host.Widget
local Chat = require("@lib/main/interfaces/chatbox/chat")
local House = require("@lib/main/house")
local Mouse = require("@lib/utils/input/mouse")
local Objects = require("@lib/main/entities/objects")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")

local Mounted = {}

Mounted.GROUP = 187
Mounted.LIST = 3
Mounted.CLOSE = 4
-- The colour tag the game puts around a place you haven't unlocked.
Mounted.LOCKED_COLOUR = "5f5f5f"
Mounted.MENU_OPTION = "Teleport menu"
Mounted.CAPE_OPTION = "Teleport"
Mounted.OPEN_TIMEOUT_MS = 8000
Mounted.CLOSE_TIMEOUT_MS = 3000
Mounted.POLL_MS = 50
-- A pause (min, max in ms) after the list opens.
Mounted.SETTLE_MS = { 250, 500 }

export type Kind = "glory" | "cape" | "talisman" | "digsite"

export type Destination = {
	name: string,
	-- false for a place you haven't unlocked
	available: boolean,
	row: Widget,
}

function Mounted.is_open(): boolean
	return Toplevel.is_open(Mounted.GROUP)
end

-- The places of the open list ("Xeric's Glade"), top to bottom. Nil when it isn't open.
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

-- The place in the open list whose name contains `name`, ignoring case, when only one does.
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

-- Clicks a place in the open list and waits for it to close. True once it has.
function Mounted.select(name: string): boolean
	local d = Mounted.find(name)
	if d == nil or not d.available then
		return false
	end
	Mouse.click(d.row)
	local deadline = time() + Mounted.CLOSE_TIMEOUT_MS
	while Mounted.is_open() do
		if time() >= deadline then
			return false
		end
		sleep(Mounted.POLL_MS)
	end
	return true
end

function Mounted.close(): boolean
	return Toplevel.close(Mounted.GROUP, function(): Widget?
		return widget(Mounted.GROUP, Mounted.CLOSE)
	end)
end

local function wait_open(): boolean
	local deadline = time() + Mounted.OPEN_TIMEOUT_MS
	while not Mounted.is_open() do
		if time() >= deadline then
			return false
		end
		sleep(Mounted.POLL_MS)
	end
	sleep(Random.int(Mounted.SETTLE_MS[1], Mounted.SETTLE_MS[2]))
	return true
end

-- Finds the piece in the house the player is in, goes to it and starts the teleport to `place`, which isn't waited for.
-- False with why when it didn't start, and true third when trying again is pointless: the piece or the place isn't there.
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
