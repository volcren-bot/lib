--!strict
-- The gnome glider map (group 138, `gliders` in the cache): a map of the seven landing places, each a model with its name beside it, opened by the "Glider" option of any glider pilot.
-- The pilots are different NPCs by landing place, so the option is all that identifies one. A place is chosen by clicking its model; the game offers the place's name as the menu option there.
-- Quests gate the places; one you can't use may look or behave differently. That is not known here, because it was only seen on an account with all of them done.
local Host = require("@lib/host")
local menu = Host.menu
local widget = Host.widget
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
type Npc = Host.Npc
type Tile = { x: number, y: number, plane: number? }
local Log = require("@lib/utils/log")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Mouse = require("@lib/utils/input/mouse")
local Npcs = require("@lib/main/entities/npcs")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Walker = require("@lib/main/walker")

local Gnomeglider = {}

Gnomeglider.GROUP = 138
-- The components searched for places (each place's model carries its name as its first menu option), and the close button.
Gnomeglider.LAST_COMPONENT = 40
Gnomeglider.CLOSE = 26
-- The option of the pilots that opens the map.
Gnomeglider.OPTION = "Glider"

Gnomeglider.OPEN_TIMEOUT_MS = 3000
Gnomeglider.HOVER_TIMEOUT_MS = 800
Gnomeglider.CONFIRM_TIMEOUT_MS = 4000
Gnomeglider.POLL_MS = 50
-- The menu follows the mouse a frame or so late, and would still show the place before.
Gnomeglider.SETTLE_MS = 150
-- A pause (min, max in ms) after `open` finds the map, before it returns.
Gnomeglider.OPEN_SETTLE_MS = { 250, 500 }

-- Finding the pilot: how far from you to look, how many NPCs to ask at most, and how long to wait after hovering one for its menu.
Gnomeglider.PILOT_RANGE = 12
Gnomeglider.PILOT_ASK_LIMIT = 8
Gnomeglider.PILOT_HOVER_MS = 350

-- Every landing place, as the game names it. Use these rather than typing a name: `Gnomeglider.select(Gnomeglider.Site.KarHewo)`.
export type Site =
	"Ta Quir Priw"
	| "Sindarpos"
	| "Lemanto Andra"
	| "Kar-Hewo"
	| "Gandius"
	| "Lemantolly Undri"
	| "Ookookolly Undri"

Gnomeglider.Site = table.freeze({
	TaQuirPriw = "Ta Quir Priw",
	Sindarpos = "Sindarpos",
	LemantoAndra = "Lemanto Andra",
	KarHewo = "Kar-Hewo",
	Gandius = "Gandius",
	LemantollyUndri = "Lemantolly Undri",
	OokookollyUndri = "Ookookolly Undri",
}) :: {
	TaQuirPriw: "Ta Quir Priw",
	Sindarpos: "Sindarpos",
	LemantoAndra: "Lemanto Andra",
	KarHewo: "Kar-Hewo",
	Gandius: "Gandius",
	LemantollyUndri: "Lemantolly Undri",
	OokookollyUndri: "Ookookolly Undri",
}

export type Destination = {
	name: string,
	-- the model: where to hover and click
	area: Widget,
}

function Gnomeglider.is_open(): boolean
	return Toplevel.is_open(Gnomeglider.GROUP)
end

-- Whether the map is open, polled for up to `timeout_ms` (3 seconds by default).
function Gnomeglider.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Gnomeglider.OPEN_TIMEOUT_MS)
	while true do
		if Gnomeglider.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Gnomeglider.POLL_MS)
	end
end

-- The places on the map, top to bottom. The game keeps each name as its model's first menu option, which the widget reads (`action`), so nothing is hovered. Nil when the map isn't open.
function Gnomeglider.destinations(): { Destination }?
	if not Gnomeglider.is_open() then
		return nil
	end
	local found: { Destination } = {}
	for child = 0, Gnomeglider.LAST_COMPONENT do
		local w = widget(Gnomeglider.GROUP, child)
		if w ~= nil and w.kind == 6 and not w.hidden and w.action ~= nil and w.action ~= "" and w.action ~= "Close" then
			table.insert(found, { name = w.action, area = w })
		end
	end
	table.sort(found, function(a: Destination, b: Destination)
		return a.area.y < b.area.y
	end)
	return found
end

function Gnomeglider.names(): { string }?
	local all = Gnomeglider.destinations()
	if all == nil then
		return nil
	end
	local names: { string } = {}
	for _, d in ipairs(all) do
		table.insert(names, d.name)
	end
	return names
end

-- The place called `name`, ignoring case: an exact name, else one name containing the other ("Undri" would fit two, so it fits none) if only one place fits.
function Gnomeglider.find(name: string): Destination?
	local all = Gnomeglider.destinations()
	if all == nil then
		return nil
	end
	local wanted = string.lower(name)
	local loose: Destination? = nil
	local loose_count = 0
	for _, d in ipairs(all) do
		local have = string.lower(d.name)
		if have == wanted then
			return d
		elseif string.find(have, wanted, 1, true) or string.find(wanted, have, 1, true) then
			loose = d
			loose_count += 1
		end
	end
	return if loose_count == 1 then loose else nil
end

-- The place named by the menu where the mouse is now, waiting a moment for the game to offer it.
local function menu_name(): string?
	local deadline = time() + Gnomeglider.HOVER_TIMEOUT_MS
	while true do
		for _, entry in ipairs(menu() or {}) do
			if entry.option ~= "Cancel" and entry.option ~= "Close" then
				return entry.option
			end
		end
		if time() >= deadline then
			return nil
		end
		sleep(Gnomeglider.POLL_MS)
	end
end

local function gone(timeout_ms: number): boolean
	local deadline = time() + timeout_ms
	while true do
		if not Gnomeglider.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Gnomeglider.POLL_MS)
	end
end

-- Clicks the place's model, which sends the glider, and waits for the map to go. False when no place has that name, the click wasn't on that place, or the map stayed open.
-- The click only happens once the menu under the mouse offers the place that was asked for (the models overlap), so a wrong spot costs nothing. The flight is not waited for.
function Gnomeglider.select(site: Site): boolean
	local d = Gnomeglider.find(site)
	if d == nil then
		return false
	end
	Mouse.move(d.area)
	sleep(Gnomeglider.SETTLE_MS)
	if menu_name() ~= d.name then
		Log.log("Gnomeglider", `the menu didn't offer {d.name}`)
		return false
	end
	Mouse.click()
	if gone(Gnomeglider.CONFIRM_TIMEOUT_MS) then
		return true
	end
	Log.log("Gnomeglider", `clicking {d.name} left the map open`)
	return false
end

-- The close button, nil when the map isn't open.
function Gnomeglider.close_button(): Widget?
	local w = widget(Gnomeglider.GROUP, Gnomeglider.CLOSE)
	if w == nil or w.hidden or not Gnomeglider.is_open() then
		return nil
	end
	return w
end

-- Closes the map: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.
function Gnomeglider.close(key_probability: number?): boolean
	if not Gnomeglider.is_open() then
		return true
	end
	return Toplevel.close(
		Gnomeglider.GROUP,
		Gnomeglider.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

-- The NPC near `near` (you by default; within `range` tiles, `PILOT_RANGE` by default) that offers "Glider", found by asking: each one, nearest first, is hovered and its menu read.
-- The pilots are different NPCs by landing place and their names come through empty, so the option is all that identifies one. Nil when there is none.
function Gnomeglider.find_pilot(near: Tile?, range: number?): Npc?
	local at = near or Walker.position()
	if at == nil then
		return nil
	end
	local reach = range or Gnomeglider.PILOT_RANGE
	local candidates: { { npc: Npc, distance: number } } = {}
	for _, n in ipairs(Host.npcs() or {}) do
		local d = math.max(math.abs(n.x - at.x), math.abs(n.y - at.y))
		if d <= reach then
			table.insert(candidates, { npc = n, distance = d })
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	for i, c in ipairs(candidates) do
		if i > Gnomeglider.PILOT_ASK_LIMIT then
			break
		end
		if Npcs.hover(c.npc) then
			sleep(Gnomeglider.PILOT_HOVER_MS)
			for _, entry in ipairs(Minimenu.entries() or {}) do
				if entry.option == Gnomeglider.OPTION then
					return c.npc
				end
			end
		end
	end
	return nil
end

-- Opens the map from the nearest pilot (or `npc`), walking closer first unless `walk` is false, and waits for it; true when it is open (also if it already was).
-- When it didn't work the second result says why.
function Gnomeglider.open(npc: Npc?, walk: boolean?): (boolean, string?)
	if Gnomeglider.is_open() then
		return true, nil
	end
	if not Toplevel.escape_clear() then
		return false, "another interface is open"
	end
	local target = npc or Gnomeglider.find_pilot()
	if target == nil then
		Log.log("Gnomeglider", "no glider pilot around")
		return false, "no glider pilot nearby"
	end
	local picked: boolean
	if walk ~= false then
		picked = Npcs.approach(target, Gnomeglider.OPTION)
	else
		picked = Npcs.interact(target, Gnomeglider.OPTION)
	end
	if not picked then
		-- the menu was open on something else, or the click missed: take the option if the menu offers it
		local offered = false
		for _, entry in ipairs(Minimenu.entries() or {}) do
			if entry.option == Gnomeglider.OPTION then
				offered = true
			end
		end
		if not offered or not Minimenu.select(Gnomeglider.OPTION) then
			return false, `couldn't {Gnomeglider.OPTION} the pilot`
		end
	end
	if not Gnomeglider.wait_open() then
		return false, "the map didn't open"
	end
	Random.sleep(Gnomeglider.OPEN_SETTLE_MS[1], Gnomeglider.OPEN_SETTLE_MS[2])
	return true, nil
end

return Gnomeglider
