--!strict
-- The quetzal transport map of Varlamore: a map with a model for every landing site. Renu's is group 874 (`quetzal_menu` in the cache) and the whistle's group 949 (`quetzalwhistle_menu`), laid out alike. The markers carry no text, but the game keeps each site's name as the
-- marker's first menu option (`Widget.action`), so names are read without hovering; hovering one also makes the game offer the name (like the charter map, `@lib/main/interfaces/mainscreen/chartering`).
-- The map is opened with "Travel" on Renu or "Signal" on a quetzal whistle. A site that isn't unlocked on an account may look or behave differently; that is not known here, because it was only seen on an account with every site unlocked.
local Host = require("@lib/host")
local menu = Host.menu
local widget = Host.widget
local widget_children = Host.widget_children
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
type Npc = Host.Npc
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Log = require("@lib/utils/log")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Mouse = require("@lib/utils/input/mouse")
local Npcs = require("@lib/main/entities/npcs")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Walker = require("@lib/main/walker")

local Quetzal = {}

Quetzal.GROUP = 874
Quetzal.WHISTLE_GROUP = 949
-- The component whose children are the markers, the model that marks the site you are at, and the close button.
Quetzal.MARKERS = 12
Quetzal.HERE = 13
Quetzal.CLOSE = 18
-- The NPC and the option that open the map.
Quetzal.NPC = "Renu"
Quetzal.OPTION = "Travel"
-- The whistles that also open the map, the option that does it, and the inventory's container.
Quetzal.WHISTLES = { 29271, 29273, 29275, 33120 }
Quetzal.WHISTLE_OPTION = "Signal"
Quetzal.INVENTORY = 93
-- The option of Renu and the whistle that flies straight to the last site, and the varbit where the game keeps it (`quetzal_last_destination`): 1 for the map's first marker and so on.
Quetzal.LAST_OPTION = "Last-destination"
Quetzal.LAST_VARBIT = 9950

Quetzal.OPEN_TIMEOUT_MS = 3000
Quetzal.HOVER_TIMEOUT_MS = 800
Quetzal.CONFIRM_TIMEOUT_MS = 4000
Quetzal.POLL_MS = 50
-- The menu follows the mouse a frame or so late, and would still show the marker before.
Quetzal.SETTLE_MS = 150
-- A pause (min, max in ms) after `open` finds the map, before it returns.
Quetzal.OPEN_SETTLE_MS = { 250, 500 }

-- Every landing site, as the game names it. Use these rather than typing a name: `Quetzal.select(Quetzal.Site.Aldarin)`.
export type Site =
	"Civitas illa Fortis"
	| "The Teomat"
	| "Sunset Coast"
	| "Hunter Guild"
	| "Cam Torum Entrance"
	| "Colossal Wyrm Remains"
	| "Outer Fortis"
	| "Fortis Colosseum"
	| "Aldarin"
	| "Quetzacalli Gorge"
	| "Salvager Overlook"
	| "Tal Teklan"
	| "Auburnvale"
	| "Kastori"

Quetzal.Site = table.freeze({
	CivitasillaFortis = "Civitas illa Fortis",
	TheTeomat = "The Teomat",
	SunsetCoast = "Sunset Coast",
	HunterGuild = "Hunter Guild",
	CamTorumEntrance = "Cam Torum Entrance",
	ColossalWyrmRemains = "Colossal Wyrm Remains",
	OuterFortis = "Outer Fortis",
	FortisColosseum = "Fortis Colosseum",
	Aldarin = "Aldarin",
	QuetzacalliGorge = "Quetzacalli Gorge",
	SalvagerOverlook = "Salvager Overlook",
	TalTeklan = "Tal Teklan",
	Auburnvale = "Auburnvale",
	Kastori = "Kastori",
}) :: {
	CivitasillaFortis: "Civitas illa Fortis",
	TheTeomat: "The Teomat",
	SunsetCoast: "Sunset Coast",
	HunterGuild: "Hunter Guild",
	CamTorumEntrance: "Cam Torum Entrance",
	ColossalWyrmRemains: "Colossal Wyrm Remains",
	OuterFortis: "Outer Fortis",
	FortisColosseum: "Fortis Colosseum",
	Aldarin: "Aldarin",
	QuetzacalliGorge: "Quetzacalli Gorge",
	SalvagerOverlook: "Salvager Overlook",
	TalTeklan: "Tal Teklan",
	Auburnvale: "Auburnvale",
	Kastori: "Kastori",
}

-- The sites in the map's order.
local SITE_ORDER: { Site } = {
	"Civitas illa Fortis",
	"The Teomat",
	"Sunset Coast",
	"Hunter Guild",
	"Cam Torum Entrance",
	"Colossal Wyrm Remains",
	"Outer Fortis",
	"Fortis Colosseum",
	"Aldarin",
	"Quetzacalli Gorge",
	"Salvager Overlook",
	"Tal Teklan",
	"Auburnvale",
	"Kastori",
}

export type Marker = {
	-- the marker's place among the map's children
	index: number,
	-- the model: where to hover and click
	area: Widget,
	-- the site you are at (the game puts a second model on it)
	here: boolean,
}

-- The group of the map that is open, nil when none is.
local function open_group(): number?
	if Toplevel.is_open(Quetzal.GROUP) then
		return Quetzal.GROUP
	end
	return if Toplevel.is_open(Quetzal.WHISTLE_GROUP) then Quetzal.WHISTLE_GROUP else nil
end

function Quetzal.is_open(): boolean
	return open_group() ~= nil
end

-- Whether the map is open, polled for up to `timeout_ms` (3 seconds by default).
function Quetzal.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Quetzal.OPEN_TIMEOUT_MS)
	while true do
		if Quetzal.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Quetzal.POLL_MS)
	end
end

-- The sites on the map, in the map's own order.
-- Marker index to site name. The game keeps the name as the marker's first menu option, which the widget reads (`action`), so nothing needs hovering; a name that couldn't be read that way is
-- learned by hovering (`learn`). The map is the same wherever Renu stands, so what was read stays valid until the script ends.
local known: { [number]: string } = {}

function Quetzal.markers(): { Marker }?
	local group = open_group()
	if group == nil then
		return nil
	end
	local children = widget_children(group, Quetzal.MARKERS)
	if children == nil then
		return nil
	end
	local mark = widget(group, Quetzal.HERE)
	local found: { Marker } = {}
	for _, child in ipairs(children) do
		if not child.hidden then
			if child.action ~= nil and child.action ~= "" then
				known[child.index] = child.action
			end
			table.insert(found, {
				index = child.index,
				area = child,
				here = mark ~= nil and not mark.hidden and mark.x == child.x and mark.y == child.y,
			})
		end
	end
	return found
end

-- The site named by the menu where the mouse is now, waiting a moment for the game to offer it.
local function menu_name(): string?
	local deadline = time() + Quetzal.HOVER_TIMEOUT_MS
	while true do
		for _, entry in ipairs(menu() or {}) do
			if entry.option ~= "Cancel" and entry.option ~= "Close" then
				return entry.option
			end
		end
		if time() >= deadline then
			return nil
		end
		sleep(Quetzal.POLL_MS)
	end
end

-- The site a marker leads to, read from the menu while the mouse is over it.
function Quetzal.hover_name(marker: Marker): string?
	Mouse.move(marker.area)
	sleep(Quetzal.SETTLE_MS)
	return menu_name()
end

-- Reads a marker's name and keeps it. Two markers never share a name, so a name another marker already has was a stale read: it is read again, and dropped if it repeats.
local function learn(marker: Marker): string?
	for _ = 1, 2 do
		local name = Quetzal.hover_name(marker)
		if name == nil then
			return nil
		end
		local taken = false
		for index, other in pairs(known) do
			if other == name and index ~= marker.index then
				taken = true
			end
		end
		if not taken then
			known[marker.index] = name
			return name
		end
		sleep(Quetzal.SETTLE_MS)
	end
	return nil
end

-- The name of every site, by marker index. Names come from the markers' menu options; any that can't be read that way are hovered.
function Quetzal.names(): { [number]: string }?
	local markers = Quetzal.markers()
	if markers == nil then
		return nil
	end
	local names: { [number]: string } = {}
	for _, marker in ipairs(markers) do
		local name = known[marker.index] or learn(marker)
		if name ~= nil then
			names[marker.index] = name
		end
		if known[marker.index] == nil then
			Random.sleep(40, 160)
		end
	end
	return names
end

-- The marker of the site called `name`, ignoring case: an exact name, else one name containing the other if only one site fits. Markers not read before are hovered as needed.
function Quetzal.find(name: string): Marker?
	local markers = Quetzal.markers()
	if markers == nil then
		return nil
	end
	local wanted = string.lower(name)
	local loose: Marker? = nil
	local loose_count = 0
	local function check(marker: Marker, have: string): Marker?
		have = string.lower(have)
		if have == wanted then
			return marker
		elseif string.find(have, wanted, 1, true) or string.find(wanted, have, 1, true) then
			loose = marker
			loose_count += 1
		end
		return nil
	end
	local unread: { Marker } = {}
	for _, marker in ipairs(markers) do
		local have = known[marker.index]
		if have == nil then
			table.insert(unread, marker)
		else
			local exact = check(marker, have)
			if exact then
				return exact
			end
		end
	end
	if loose_count == 0 or #unread > 0 then
		for _, marker in ipairs(unread) do
			local have = learn(marker)
			if have ~= nil then
				local exact = check(marker, have)
				if exact then
					return exact
				end
			end
			Random.sleep(40, 160)
		end
	end
	return if loose_count == 1 then loose else nil
end

local function gone(timeout_ms: number): boolean
	local deadline = time() + timeout_ms
	while true do
		if not Quetzal.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Quetzal.POLL_MS)
	end
end

-- Clicks the site's marker, which sends the quetzal, and waits for the map to go. False when no site has that name, the click wasn't on that site, or the map stayed open.
-- The click only happens once the menu under the mouse offers the site that was asked for.
function Quetzal.select(site: Site): boolean
	local marker = Quetzal.find(site)
	if marker == nil then
		return false
	end
	local expected = known[marker.index]
	Mouse.move(marker.area)
	sleep(Quetzal.SETTLE_MS)
	if expected == nil or menu_name() ~= expected then
		return false
	end
	Mouse.click()
	if gone(Quetzal.CONFIRM_TIMEOUT_MS) then
		return true
	end
	Log.log("Quetzal", `clicking {expected} left the map open`)
	return false
end

-- The close button, nil when the map isn't open.
function Quetzal.close_button(): Widget?
	local group = open_group()
	if group == nil then
		return nil
	end
	local w = widget(group, Quetzal.CLOSE)
	return if w == nil or w.hidden then nil else w
end

-- Closes the map: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.
function Quetzal.close(key_probability: number?): boolean
	local group = open_group()
	if group == nil then
		return true
	end
	return Toplevel.close(
		group,
		Quetzal.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

-- How many nameless NPCs near you are asked at most when looking for Renu, how far to look, and how long to wait after hovering one for its menu.
Quetzal.ASK_LIMIT = 6
Quetzal.ASK_RANGE = 12
Quetzal.HOVER_MS = 350

-- The nearest Renu among the NPCs loaded, by straight distance. Renu's name comes through empty (the game shows the NPC as another one), so when no NPC is called Renu the nameless ones
-- near you are hovered, nearest first, and the one whose menu offers "Travel" on "Renu" is taken. Nil when there is none.
function Quetzal.nearest(): Npc?
	local me = Walker.position()
	if me == nil then
		return nil
	end
	local named = Npcs.nearest(Quetzal.NPC, me)
	if named ~= nil then
		return named
	end
	local candidates: { { npc: Npc, distance: number } } = {}
	for _, n in ipairs(Host.npcs() or {}) do
		local d = math.max(math.abs(n.x - me.x), math.abs(n.y - me.y))
		if Npcs.clean_name(n.name) == "" and d <= Quetzal.ASK_RANGE then
			table.insert(candidates, { npc = n, distance = d })
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	for i, c in ipairs(candidates) do
		if i > Quetzal.ASK_LIMIT then
			break
		end
		if Npcs.hover(c.npc) then
			sleep(Quetzal.HOVER_MS)
			for _, entry in ipairs(Minimenu.entries() or {}) do
				if entry.option == Quetzal.OPTION and string.find(string.lower(entry.target), "renu", 1, true) then
					return c.npc
				end
			end
		end
	end
	return nil
end

-- Opens the map by talking to the nearest Renu (or `npc`), walking closer first unless `walk` is false, and waits for it; true when it is open (also if it already was).
function Quetzal.open(npc: Npc?, walk: boolean?): boolean
	if Quetzal.is_open() then
		return true
	end
	if not Toplevel.escape_clear() then
		return false
	end
	local target = npc or Quetzal.nearest()
	if target == nil then
		Log.log("Quetzal", `no {Quetzal.NPC} around`)
		return false
	end
	local picked: boolean
	if walk ~= false then
		picked = Npcs.approach(target, Quetzal.OPTION)
	else
		picked = Npcs.interact(target, Quetzal.OPTION)
	end
	if not picked then
		-- the menu was open on something else, or the click missed: take the option if what's hovered is Renu
		local uptext = Minimenu.uptext()
		if uptext == nil or not string.find(string.lower(uptext), string.lower(Quetzal.NPC), 1, true) then
			return false
		end
		if not Minimenu.select(Quetzal.OPTION) then
			return false
		end
	end
	if not Quetzal.wait_open() then
		return false
	end
	Random.sleep(Quetzal.OPEN_SETTLE_MS[1], Quetzal.OPEN_SETTLE_MS[2])
	return true
end

-- The site "Last-destination" flies to, as the game has it now, whoever flew there; nil when it has none or one this module doesn't know.
function Quetzal.last_destination(): Site?
	return SITE_ORDER[Host.varbit(Quetzal.LAST_VARBIT) or 0]
end

-- Whether "Last-destination" goes to the site called `name`, ignoring case, one name containing the other being enough ("Cam Torum").
function Quetzal.is_last(name: string): boolean
	local last = Quetzal.last_destination()
	if last == nil then
		return false
	end
	local have, wanted = string.lower(last), string.lower(name)
	return string.find(have, wanted, 1, true) ~= nil or string.find(wanted, have, 1, true) ~= nil
end

-- Flies to the last site with the nearest Renu (or `npc`), walking closer first unless `walk` is false. True when the option was clicked; the flight is not waited for.
function Quetzal.fly_last(npc: Npc?, walk: boolean?): boolean
	if not Toplevel.escape_clear() then
		return false
	end
	local target = npc or Quetzal.nearest()
	if target == nil then
		Log.log("Quetzal", `no {Quetzal.NPC} around`)
		return false
	end
	if walk ~= false then
		return Npcs.approach(target, Quetzal.LAST_OPTION)
	end
	return Npcs.interact(target, Quetzal.LAST_OPTION)
end

-- The inventory slot of a quetzal whistle, nil when none is held.
function Quetzal.whistle_slot(): number?
	for _, item in ipairs(Host.item_container(Quetzal.INVENTORY) or {}) do
		if table.find(Quetzal.WHISTLES, item.id) ~= nil then
			return item.slot
		end
	end
	return nil
end

-- Opens the map with the whistle in the inventory, from anywhere; true when it is open (also if it already was). When it didn't work the second result says why.
-- An empty whistle only says so in the chat, so it shows as a map that doesn't open.
function Quetzal.signal(): (boolean, string?)
	if Quetzal.is_open() then
		return true, nil
	end
	local slot = Quetzal.whistle_slot()
	if slot == nil then
		return false, "no whistle held"
	end
	if not Toplevel.escape_clear() then
		return false, "another interface is open"
	end
	if not Inventory.interact_slot(slot, Quetzal.WHISTLE_OPTION) then
		return false, `couldn't {Quetzal.WHISTLE_OPTION} the whistle`
	end
	if not Quetzal.wait_open() then
		return false, "the map didn't open (no charges?)"
	end
	Random.sleep(Quetzal.OPEN_SETTLE_MS[1], Quetzal.OPEN_SETTLE_MS[2])
	return true, nil
end

-- Flies to the last site with the whistle in the inventory, from anywhere. True when the option was clicked; the flight is not waited for, and an empty whistle only says so in the chat.
function Quetzal.signal_last(): boolean
	local slot = Quetzal.whistle_slot()
	if slot == nil or not Toplevel.escape_clear() then
		return false
	end
	return Inventory.interact_slot(slot, Quetzal.LAST_OPTION)
end

return Quetzal
