--!strict
-- Choosing a charter destination the way a player would: with the keyboard, on the map, or in the side list, chosen by chance.
-- A charter trader's menu shows two interfaces at once, both in this module:
--   `Chartering.Tab` is the ship list, the game tab that replaces the side panel (the cache calls it `chartering_menu_side`). Its rows read `<col=ffffff>K</col> :  Name`, scrolled in a list of about ten, and the key K sends the boat.
--   `Chartering.Map` is the sea chart in the middle of the screen (group 72, `sailing_menu`). Its markers carry no text: hovering one makes the game offer the port's name as the menu option, so names are read by hovering and kept.
-- The two list the same ports in different orders, so they are not matched by position. The functions on `Chartering` itself work over both.
local Host = require("@lib/host")
local menu = Host.menu
local widget = Host.widget
local widget_children = Host.widget_children
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
local Biometrics = require("@lib/main/antiban/biometrics")
local Geometry = require("@lib/utils/math/geometry")
local Keyboard = require("@lib/utils/input/keyboard")
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Box = Geometry.Box
type Box = Geometry.Box
local Point = Geometry.Point
type Point = Geometry.Point
type Tile = { x: number, y: number, plane: number? }

local Chartering = {}
local Tab = {}
local Map = {}
Chartering.Tab = Tab
Chartering.Map = Map

-- The ship list (side tab)
Tab.GROUP = 885
Tab.LIST = 4
Tab.TITLE = 7

Tab.OPEN_TIMEOUT_MS = 8000
Tab.POLL_MS = 150
Tab.MAX_SCROLLS = 30

export type Destination = {
	-- the letter or digit the list shows before the name ("1", "A")
	key: string,
	name: string,
	-- the port's place in the game's list: the keys count up from 0 and skip the port the trader is in
	port: number,
	-- fully inside the scrolled list
	visible: boolean,
	row: Widget,
}

local function list(): Widget?
	local w = widget(Tab.GROUP, Tab.LIST)
	if w == nil or w.hidden then
		return nil
	end
	return w
end

function Tab.is_open(): boolean
	return list() ~= nil
end

function Tab.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Tab.OPEN_TIMEOUT_MS)
	while true do
		if Tab.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Tab.POLL_MS)
	end
end

-- "<col=ffffff>K</col> :  Name" is the key "K" and the name "Name".
local function split(text: string): (string?, string?)
	local plain = string.gsub(text, "<[^>]*>", "")
	local key, name = string.match(plain, "^%s*(%w+)%s*:%s*(.-)%s*$")
	return key, name
end

-- The ports you can sail to from here, top to bottom. The port you are in is not listed.
function Tab.destinations(): { Destination }?
	local view = list()
	if view == nil then
		return nil
	end
	local children = widget_children(Tab.GROUP, Tab.LIST)
	if children == nil then
		return nil
	end
	local found: { Destination } = {}
	for _, child in ipairs(children) do
		if child.kind == 4 and not child.hidden and child.text ~= nil then
			local key, name = split(child.text)
			if key ~= nil and name ~= nil and name ~= "" then
				table.insert(found, {
					key = key,
					name = name,
					-- a row is a picture (even index) and its text (the odd one after it)
					port = (child.index - 1) // 2,
					visible = child.y >= view.y and child.y + child.height <= view.y + view.height,
					row = child,
				})
			end
		end
	end
	table.sort(found, function(a: Destination, b: Destination)
		return a.row.y < b.row.y
	end)
	return found
end

-- The destination called `name`, ignoring case. An exact name wins; else one name containing the other ("Shipyard" in "Karamja Shipyard") if only one port fits.
-- The key is never matched: the letters differ by port.
function Tab.find(name: string): Destination?
	local all = Tab.destinations()
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

function Tab.names(): { string }?
	local all = Tab.destinations()
	if all == nil then
		return nil
	end
	local names: { string } = {}
	for _, d in ipairs(all) do
		table.insert(names, d.name)
	end
	return names
end

local function box_of(w: Widget): Box
	return Box.new(w.x, w.y, w.x + w.width - 1, w.y + w.height - 1)
end

-- Scrolls the list until the destination is fully shown and returns it. Nil when it isn't in the list or the list wouldn't move.
function Tab.scroll_to(name: string): Destination?
	local last: number? = nil
	for _ = 1, Tab.MAX_SCROLLS do
		local d = Tab.find(name)
		local view = list()
		if d == nil or view == nil then
			return nil
		end
		if d.visible then
			return d
		end
		-- stuck at either end of the list
		if last == d.row.y then
			return nil
		end
		last = d.row.y
		local down = d.row.y > view.y
		Mouse.scroll(Biometrics.random_mode_integer(2, 1, 3), down, box_of(view))
		Random.sleep(80, 250)
	end
	return nil
end

-- Clicks the destination (scrolling to it first), which sends the boat. False when it isn't in the list; the sailing itself is not waited for.
function Tab.select(name: string): boolean
	local d = Tab.scroll_to(name)
	if d == nil then
		return false
	end
	Mouse.click(d.row)
	return true
end

-- The key code of a destination's key: a digit or letter, which the game takes as the key of the same name (letters in capitals).
function Tab.key_code(d: Destination): number?
	local key = string.upper(d.key)
	if #key ~= 1 then
		return nil
	end
	local code = string.byte(key)
	if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) then
		return code
	end
	return nil
end

-- Presses the destination's key, which sends the boat like a click does (the row shows the key: `K :  Name`). No scrolling is needed. False when the name isn't in the list.
function Tab.press(name: string): boolean
	local d = Tab.find(name)
	if d == nil then
		return false
	end
	local code = Tab.key_code(d)
	if code == nil then
		return false
	end
	Keyboard.key_press(code)
	return true
end

-- The sea chart (main screen)
Map.GROUP = 72
Map.CLOSE = 2
Map.MARKERS = 3

-- The marker picture of a port you can sail to, and of the one you are in. (A marker under the mouse is drawn with another picture, so the picture says nothing else.)
Map.MARKER_SPRITE = 6916
Map.HERE_SPRITE = 6918

Map.OPEN_TIMEOUT_MS = 8000
Map.HOVER_TIMEOUT_MS = 800
Map.POLL_MS = 50
Map.SETTLE_MS = 150
-- Spacing in pixels of the points tried when looking for a spot that belongs to a marker.
Map.GRID = 3

export type Marker = {
	-- the marker's place among the map's children (always even): its picture is at `index`, its transparent click square at `index + 1`
	index: number,
	-- the picture
	picture: Widget,
	-- a spot that really belongs to this marker: the squares of neighbouring markers are bigger than their pictures and the later ones lie on top, so a picture's own centre can belong to another port
	spot: Point,
	-- the port you are in, which can't be sailed to
	here: boolean,
}

function Map.is_open(): boolean
	local w = widget(Map.GROUP, Map.MARKERS)
	return w ~= nil and not w.hidden
end

function Map.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Map.OPEN_TIMEOUT_MS)
	while true do
		if Map.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Map.POLL_MS)
	end
end

local function covers(w: Widget, x: number, y: number): boolean
	return x >= w.x and y >= w.y and x < w.x + w.width and y < w.y + w.height
end

-- The ports shown on the map (the ones the game hides are not in this trader's reach), in the map's own order. A marker whose square is entirely covered is left out.
function Map.markers(): { Marker }?
	if not Map.is_open() then
		return nil
	end
	local children = widget_children(Map.GROUP, Map.MARKERS)
	if children == nil then
		return nil
	end
	local by_index: { [number]: Widget } = {}
	for _, child in ipairs(children) do
		by_index[child.index] = child
	end
	local found: { Marker } = {}
	for _, picture in ipairs(children) do
		local square = by_index[picture.index + 1]
		if
			picture.kind == 5
			and picture.index % 2 == 0
			and not picture.hidden
			and square ~= nil
			and not square.hidden
		then
			-- the squares drawn later, which win where they overlap
			local above: { Widget } = {}
			for _, other in ipairs(children) do
				if other.kind == 3 and other.index % 2 == 1 and other.index > square.index and not other.hidden then
					table.insert(above, other)
				end
			end
			-- points of the picture first, else of the whole square, on a grid of a few pixels
			local near: { Point } = {}
			local rest: { Point } = {}
			for y = square.y + 1, square.y + square.height - 2, Map.GRID do
				for x = square.x + 1, square.x + square.width - 2, Map.GRID do
					local free = true
					for _, other in ipairs(above) do
						if covers(other, x, y) then
							free = false
							break
						end
					end
					if free then
						table.insert(if covers(picture, x, y) then near else rest, Point.new(x, y))
					end
				end
			end
			local pool = if #near > 0 then near else rest
			if #pool > 0 then
				table.insert(found, {
					index = picture.index,
					picture = picture,
					spot = pool[Random.int(1, #pool)],
					here = picture.sprite == Map.HERE_SPRITE,
				})
			end
		end
	end
	return found
end

-- The port named by the menu where the mouse is now, waiting a moment for the game to offer it.
local function menu_name(): string?
	local deadline = time() + Map.HOVER_TIMEOUT_MS
	while true do
		for _, entry in ipairs(menu() or {}) do
			-- the port's name is the first entry that is not the menu's own
			if entry.option ~= "Cancel" and entry.option ~= "Close" then
				return entry.option
			end
		end
		if time() >= deadline then
			return nil
		end
		sleep(Map.POLL_MS)
	end
end

-- The port a marker leads to, read from the menu while the mouse is over it. Nil for the port you are in.
function Map.hover_name(marker: Marker): string?
	if marker.here then
		return nil
	end
	Mouse.move(marker.spot)
	-- the menu follows the mouse a frame or so late, and would still show the marker before
	sleep(Map.SETTLE_MS)
	return menu_name()
end

-- Marker index to port name, learned by hovering. The chart is the same wherever the trader is, so what was read stays valid until the script ends.
local known: { [number]: string } = {}

-- Reads a marker's name and keeps it. Two markers never share a name, so a name another marker already has was a stale read: it is read again, and dropped if it repeats.
local function learn(marker: Marker): string?
	for _ = 1, 2 do
		local name = Map.hover_name(marker)
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
		sleep(Map.SETTLE_MS)
	end
	return nil
end

-- The name of every port you can sail to, by marker index. Markers not read before are hovered now, so the first call moves the mouse over the whole map.
function Map.names(): { [number]: string }?
	local markers = Map.markers()
	if markers == nil then
		return nil
	end
	local names: { [number]: string } = {}
	for _, marker in ipairs(markers) do
		if not marker.here then
			local name = known[marker.index]
			if name == nil then
				name = learn(marker)
				Random.sleep(40, 160)
			end
			if name ~= nil then
				names[marker.index] = name
			end
		end
	end
	return names
end

-- The marker of the port called `name`, ignoring case: an exact name, else one name containing the other if only one port fits.
function Map.find(name: string): Marker?
	local markers = Map.markers()
	if markers == nil then
		return nil
	end
	local wanted = string.lower(name)
	-- ports already read are looked at first, so a map that was hovered once costs no more mouse moves
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
		if not marker.here then
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

-- Clicks the port's marker, which sends the boat. False when no port on the map has that name; the sailing itself is not waited for.
-- The click only happens once the menu under the mouse offers the port that was asked for, so a marker that was misread costs nothing.
function Map.select(name: string): boolean
	local marker = Map.find(name)
	if marker == nil then
		return false
	end
	local expected = known[marker.index]
	Mouse.move(marker.spot)
	sleep(Map.SETTLE_MS)
	if expected == nil or menu_name() ~= expected then
		return false
	end
	Mouse.click()
	return true
end

-- Closes the map: Escape (chance `key_probability`; nil or 0 is a biometric) unless "Esc to close" is off, else the close button. Waits for it to go. See `Toplevel.close`.
function Map.close(key_probability: number?): boolean
	return Toplevel.close(Map.GROUP, function()
		local w = widget(Map.GROUP, Map.CLOSE)
		return if w ~= nil and not w.hidden then w else nil
	end, if key_probability ~= nil and key_probability > 0 then key_probability else nil)
end

-- Both together
-- The chance of a biometric's choice: pressing the destination's key, and (if not) using the map rather than the list.
Chartering.KEY_CHANCE = 0.5
Chartering.MAP_CHANCE = 0.4

-- How long to wait for the interface to go after choosing a destination before the next way is tried, and how often to look.
Chartering.CONFIRM_TIMEOUT_MS = 4000
Chartering.POLL_MS = 100

-- Finding the trader: how far from `near` to look, how many NPCs to ask at most, and how long to wait after hovering one for its menu.
Chartering.TRADER_RANGE = 12
Chartering.TRADER_ASK_LIMIT = 8
Chartering.TRADER_HOVER_MS = 350
-- A pause (min, max in ms) after `open` finds the menu, before it returns: a key pressed in the first moments after the menu appears is ignored by the game.
Chartering.SETTLE_MS = { 250, 500 }

-- Every charter port, as the game names it: read from live lists, except `CivitasIllaFortis` (key D, the port the list was read in) and `RedRock` (key K), which come from the transport data
-- (`TRANSPORTS/transports/charter_ships.tsv`) and haven't been seen in a live list. Use these rather than typing a name: `Chartering.select(Chartering.Port.Catherby)`.
-- The game numbers its ports with keys 0-9 then A-N; G, H and L have never been seen, so they are not here yet.
-- A trader doesn't offer every port, and never the one it is in, so selecting a port that isn't offered just fails.
export type Port =
	"Port Sarim"
	| "Brimhaven"
	| "Catherby"
	| "Mos Le'Harmless"
	| "Musa Point"
	| "Port Khazard"
	| "Port Phasmatys"
	| "Karamja Shipyard"
	| "Port Tyras"
	| "Corsair Cove"
	| "Prifddinas"
	| "Port Piscarilius"
	| "Land's End"
	| "Aldarin"
	| "Sunset Coast"
	| "The Pandemonium"
	| "The Summer Shore"
	| "Deepfin Point"
	| "Port Roberts"
	| "Civitas illa Fortis"
	| "Red Rock"

Chartering.Port = table.freeze({
	PortSarim = "Port Sarim",
	Brimhaven = "Brimhaven",
	Catherby = "Catherby",
	MosLeHarmless = "Mos Le'Harmless",
	MusaPoint = "Musa Point",
	PortKhazard = "Port Khazard",
	PortPhasmatys = "Port Phasmatys",
	KaramjaShipyard = "Karamja Shipyard",
	PortTyras = "Port Tyras",
	CorsairCove = "Corsair Cove",
	Prifddinas = "Prifddinas",
	PortPiscarilius = "Port Piscarilius",
	LandsEnd = "Land's End",
	Aldarin = "Aldarin",
	SunsetCoast = "Sunset Coast",
	ThePandemonium = "The Pandemonium",
	TheSummerShore = "The Summer Shore",
	DeepfinPoint = "Deepfin Point",
	PortRoberts = "Port Roberts",
	CivitasIllaFortis = "Civitas illa Fortis",
	RedRock = "Red Rock",
}) :: {
	PortSarim: "Port Sarim",
	Brimhaven: "Brimhaven",
	Catherby: "Catherby",
	MosLeHarmless: "Mos Le'Harmless",
	MusaPoint: "Musa Point",
	PortKhazard: "Port Khazard",
	PortPhasmatys: "Port Phasmatys",
	KaramjaShipyard: "Karamja Shipyard",
	PortTyras: "Port Tyras",
	CorsairCove: "Corsair Cove",
	Prifddinas: "Prifddinas",
	PortPiscarilius: "Port Piscarilius",
	LandsEnd: "Land's End",
	Aldarin: "Aldarin",
	SunsetCoast: "Sunset Coast",
	ThePandemonium: "The Pandemonium",
	TheSummerShore: "The Summer Shore",
	DeepfinPoint: "Deepfin Point",
	PortRoberts: "Port Roberts",
	CivitasIllaFortis: "Civitas illa Fortis",
	RedRock: "Red Rock",
}

export type Method = "key" | "map" | "list"

function Chartering.is_open(): boolean
	return Tab.is_open() or Map.is_open()
end

-- Waits for the list or the map to open.
function Chartering.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Tab.OPEN_TIMEOUT_MS)
	while true do
		if Chartering.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Tab.POLL_MS)
	end
end

-- A chance given by the caller, else a biometric around `default`. Zero means "no choice made", as nil does.
local function chance(given: number?, default: number): number
	if given ~= nil and given > 0 then
		return given
	end
	return Biometrics.random_double(default)
end

-- The ways to choose `name` that can work now, the one picked by chance first. The key needs the list (it shows the key), the map needs the map, the list the list.
local function plan(name: string, key_probability: number?, map_probability: number?): { Method }
	local in_list = Tab.is_open() and Tab.find(name) ~= nil
	local on_map = Map.is_open()
	local order: { Method } = {}
	local function add(method: Method)
		if not table.find(order, method) then
			table.insert(order, method)
		end
	end
	if in_list and Random.chance(chance(key_probability, Chartering.KEY_CHANCE)) then
		add("key")
	end
	if on_map and Random.chance(chance(map_probability, Chartering.MAP_CHANCE)) then
		add("map")
	end
	-- the fallbacks, clicking before anything else: the list, then the map
	if Tab.is_open() then
		add("list")
	end
	if on_map then
		add("map")
	end
	if in_list then
		add("key")
	end
	return order
end

local function gone(timeout_ms: number): boolean
	local deadline = time() + timeout_ms
	while true do
		if not Chartering.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Chartering.POLL_MS)
	end
end

-- Chooses the destination, which sends the boat and costs the fare. The way is picked by chance, from the keyboard (chance `key_probability`), then the map (`map_probability`), else the side list;
-- a chance of nil or 0 is a biometric (around KEY_CHANCE and MAP_CHANCE). A way that leaves the interface open for CONFIRM_TIMEOUT_MS is followed by the next, clicking ones before the key.
-- Returns the way that worked, or nil if the name isn't offered or none did. The sailing is not waited for.
function Chartering.select(port: Port, key_probability: number?, map_probability: number?): Method?
	local name: string = port
	local order = plan(name, key_probability, map_probability)
	for _, method in ipairs(order) do
		local sent = if method == "key"
			then Tab.press(name)
			elseif method == "map" then Map.select(name)
			else Tab.select(name)
		if sent then
			if gone(Chartering.CONFIRM_TIMEOUT_MS) then
				return method
			end
			Log.log("Chartering", `{method} to {name} left the interface open`)
		else
			Log.log("Chartering", `couldn't choose {name} by {method}`)
		end
		if not Chartering.is_open() then
			-- a way that failed to confirm but did close it: the boat is on its way
			return if sent then method else nil
		end
	end
	return nil
end

-- The NPC near `near` (within `range` tiles, `TRADER_RANGE` by default) that offers `option`, found by asking: each one, nearest first, is hovered and its menu read.
-- The traders are different NPCs by port, so the option ("Charter") is all that identifies one.
function Chartering.find_trader(option: string, near: Tile, range: number?): Host.Npc?
	local npcs = Host.npcs()
	if npcs == nil then
		return nil
	end
	local reach = range or Chartering.TRADER_RANGE
	local candidates: { { npc: Host.Npc, distance: number } } = {}
	for _, n in ipairs(npcs) do
		local d = math.max(math.abs(n.x - near.x), math.abs(n.y - near.y))
		if d <= reach then
			table.insert(candidates, { npc = n, distance = d })
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	local Npcs = (require :: any)("@lib/main/entities/npcs")
	local Minimenu = (require :: any)("@lib/main/interfaces/minimenu")
	for i, c in ipairs(candidates) do
		if i > Chartering.TRADER_ASK_LIMIT then
			break
		end
		if Npcs.hover(c.npc) then
			sleep(Chartering.TRADER_HOVER_MS)
			for _, entry in ipairs(Minimenu.entries() or {}) do
				if entry.option == option then
					return c.npc
				end
			end
		end
	end
	return nil
end

-- Opens the charter menu: talks to the trader near `near` with `option` (default "Charter") and waits for the list or the map. True if it is open (also if it already was).
-- When it didn't work the second result says why.
function Chartering.open(option: string?, near: Tile?, range: number?): (boolean, string?)
	if Chartering.is_open() then
		return true, nil
	end
	local say = option or "Charter"
	local Npcs = (require :: any)("@lib/main/entities/npcs")
	local at = near
	if at == nil then
		local Player = (require :: any)("@lib/main/player")
		at = Player.position()
	end
	if at == nil then
		return false, "no position"
	end
	local npc = Chartering.find_trader(say, at, range)
	if npc == nil then
		return false, "no trader nearby"
	end
	if not Npcs.interact(npc, say) then
		return false, `couldn't {say} the trader`
	end
	if not Chartering.wait_open(Tab.OPEN_TIMEOUT_MS) then
		return false, "the destination list didn't open"
	end
	Random.sleep(Chartering.SETTLE_MS[1], Chartering.SETTLE_MS[2])
	return true, nil
end

return Chartering
