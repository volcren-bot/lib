--!strict
-- Fairy rings: the transport network of Zanaris. A ring is used through its three dials (the main screen interface, group 398 `fairyrings`: each dial turns one step at a time through four letters,
-- and "Confirm" teleports to the code they spell) or through the travel log (the side tab that opens beside it, group 381: the codes used before, each with its place, one click on a row teleports).
-- Both are opened together by the "Configure" option of a "Fairy ring". When the interface is closed, the ring offers "Last-destination (CODE)" for the last code used.
-- A code is three letters, one from each dial: the first from A, D, C, B, the second from I, L, K, J and the third from P, S, R, Q (in the order the dials turn clockwise).
-- Destinations are given either as a code ("aiq", "A I Q", "a-i-q") or as a part of the place's name ("mudskipper", "ardougne zoo"), in any case.
local Host = require("@lib/host")
local widget = Host.widget
local widget_children = Host.widget_children
local host_varbit = Host.varbit
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
type Loc = Host.Loc
type Tile = { x: number, y: number, plane: number? }
local Biometrics = require("@lib/main/antiban/biometrics")
local Diaries = require("@lib/main/diaries")
local Geometry = require("@lib/utils/math/geometry")
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Log = require("@lib/utils/log")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Mouse = require("@lib/utils/input/mouse")
local Objects = require("@lib/main/entities/objects")
local Quests = require("@lib/main/quests")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Walker = require("@lib/main/walker")
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

local Box = Geometry.Box

-- (the host also returns an error as a second result, which would be taken as an argument by calls such as `table.insert`)
local function varbit(id: number): number
	return (host_varbit(id)) or 0
end

local Fairyring = {}
local Dial = {}
local TravelLog = {}
Fairyring.Dial = Dial
Fairyring.Log = TravelLog

-- The ring object and the options used on it.
Fairyring.OBJECT = "Fairy ring"
Fairyring.CONFIGURE = "Configure"
Fairyring.LAST = "Last-destination"
-- The ring option that goes to Zanaris, and the quest it needs besides what every ring use needs.
Fairyring.ZANARIS = "Zanaris"
Fairyring.ZANARIS_QUEST = "Lost City"
-- The ring's submenu of favourite codes, and the varbits of the four favourites: each holds the three dial positions then a flag that says it is set.
Fairyring.FAVOURITES = "Favourites"
Fairyring.FAVOURITE_VARBITS = {
	{ 4555, 5008, 5009, 5010 },
	{ 5011, 5012, 5013, 5014 },
	{ 5015, 5016, 5017, 5018 },
	{ 5019, 5020, 5021, 5022 },
}
-- How close to the ring to get before its menu is opened.
Fairyring.MENU_NEAR = 4

Fairyring.OPEN_TIMEOUT_MS = 4000
Fairyring.POLL_MS = 50
-- How long a teleport may take to take effect after it is asked for, and how far away a position must be to count as arrived (a walk to the ring never counts).
Fairyring.TELEPORT_TIMEOUT_MS = 8000
Fairyring.ARRIVED_DISTANCE = 20
-- A pause (min, max in ms) after `open` finds the interface, before it returns.
Fairyring.OPEN_SETTLE_MS = { 250, 500 }
-- The chance a biometric is rolled around for using the travel log (when the place is in it) instead of the dials.
Fairyring.LOG_CHANCE = 0.3

-- What using the rings needs: two varbits the game itself reads to decide (the quest part: `fairyring_use` and `fairyring_permission`, which "Fairytale II - Cure a Queen"
-- sets as you advance; its "Use of fairy rings" requirement in the diary list is exactly this check), and one of a staff or the diary.
Fairyring.USE_VARBIT = 2328
Fairyring.PERMISSION_VARBIT = 2329
Fairyring.USE_NEEDED = 1
Fairyring.PERMISSION_NEEDED = 2
Fairyring.STAVES = { "Dramen staff", "Lunar staff" }
-- The diary region and tier whose completion makes a staff unnecessary (Lumbridge & Draynor, elite).
Fairyring.DIARY_REGION = "lumbridge"
Fairyring.DIARY_TIER = "elite"

-- The three dials: their varbits (0 to 3, going clockwise) and the letters at each position.
Dial.GROUP = 398
Dial.TITLE = 2
Dial.CONFIRM = 26
Dial.CLOSE = 27
-- The click areas of each dial, clockwise first.
Dial.CLOCKWISE = { 19, 21, 23 }
Dial.COUNTER_CLOCKWISE = { 20, 22, 24 }
Dial.VARBITS = { 3985, 3986, 3987 }
Dial.LETTERS = { { "A", "D", "C", "B" }, { "I", "L", "K", "J" }, { "P", "S", "R", "Q" } }
-- The varbit of the last code used: the first dial's position times 16, plus the second's times 4, plus the third's.
Dial.LAST_VARBIT = 5374

Dial.OPEN_TIMEOUT_MS = 3000
-- How long a turn may take to show in the dial's varbit, how many times a turn is tried, and how long a confirmed code may leave the interface open before it is called a failure.
Dial.TURN_TIMEOUT_MS = 1500
Dial.TURN_TRIES = 3
Dial.CONFIRM_TIMEOUT_MS = 4000
Dial.POLL_MS = 50

-- The travel log tab: its title, the search box, the list of rows (a description is a row's clickable text, its code is a separate text at the same height) and the scrolled panel they sit in.
TravelLog.GROUP = 381
TravelLog.TITLE = 6
TravelLog.LIST = 8
TravelLog.TITLE_TEXT = "Travel log"
TravelLog.OPTION = "Use code"
-- Where the code texts are besides the list's own children: the favourites at the top, as plain texts of the group.
TravelLog.FIRST_COMPONENT = 12
TravelLog.LAST_COMPONENT = 170
TravelLog.MAX_SCROLLS = 40
TravelLog.OPEN_TIMEOUT_MS = 3000
TravelLog.CONFIRM_TIMEOUT_MS = 4000
TravelLog.POLL_MS = 50

-- The places of the codes, as the travel log words them ("Region: Place"). These are the codes the log has been seen to list; a code that isn't here can still be given as a code.
export type Place = { code: string, name: string }

Fairyring.PLACES = table.freeze({
	{ code = "AIQ", name = "Asgarnia: Mudskipper Point" },
	{ code = "AIR", name = "Islands: South-east of Ardougne" },
	{ code = "AIS", name = "Varlamore: Auburn Valley" },
	{ code = "AJP", name = "Varlamore: Avium Savannah" },
	{ code = "AJQ", name = "Dungeons: Dorgesh-Kaan cave" },
	{ code = "AJR", name = "Fremennik Province: Fremennik Slayer Cave" },
	{ code = "AJS", name = "Islands: Penguins" },
	{ code = "AKQ", name = "Kandarin: Piscatoris Hunter area" },
	{ code = "AKS", name = "Feldip Hills: Jungle Hunter area" },
	{ code = "ALP", name = "Fremennik Province: Lighthouse" },
	{ code = "ALQ", name = "Morytania: Haunted Woods" },
	{ code = "ALR", name = "Other Realms: Abyss" },
	{ code = "ALS", name = "Kandarin: McGrubor's Wood" },
	{ code = "BIP", name = "Islands: River Salve" },
	{ code = "BIQ", name = "Kharidian Desert: Near the Kalphite Hive" },
	{ code = "BIS", name = "Kandarin: Ardougne Zoo unicorns" },
	{ code = "BJR", name = "Other Realms: Fisher King" },
	{ code = "BJS", name = "Islands: Near Zul-Andra" },
	{ code = "BKP", name = "Feldip Hills: South of Castle Wars" },
	{ code = "BKR", name = "Morytania: Mort Myre" },
	{ code = "BLP", name = "Dungeons: Mor Ul Rek" },
	{ code = "BLR", name = "Kandarin: Legends' Guild" },
	{ code = "BLS", name = "Kebos Lowlands: South of Mount Quidamortem" },
	{ code = "CIP", name = "Islands: Miscellania" },
	{ code = "CIR", name = "Kebos Lowlands: South of Mount Karuulm" },
	{ code = "CIS", name = "Great Kourend: Arceuus Library" },
	{ code = "CJR", name = "Kandarin: Sinclair Mansion" },
	{ code = "CKP", name = "Other Realms: Cosmic Entity's plane" },
	{ code = "CKQ", name = "Varlamore: Aldarin" },
	{ code = "CKR", name = "Karamja: Tai Bwo Wannai Village" },
	{ code = "CKS", name = "Morytania: Canifis" },
	{ code = "CLP", name = "Islands: South of Draynor Village" },
	{ code = "CLR", name = "Islands: Ape Atoll" },
	{ code = "DIP", name = "Other Realms: Abyssal Nexus" },
	{ code = "DIR", name = "Other Realms: Goraks' plane" },
	{ code = "DIS", name = "Misthalin: Wizards' Tower" },
	{ code = "DJP", name = "Kandarin: Tower of Life" },
	{ code = "DJR", name = "Great Kourend: Chasm of Fire" },
	{ code = "DKP", name = "Karamja: Gnome Glider" },
	{ code = "DKR", name = "Misthalin: Edgeville" },
	{ code = "DKS", name = "Fremennik Province: Polar Hunter area" },
	{ code = "DLP", name = "Islands: Grimstone" },
	{ code = "DLQ", name = "Kharidian Desert: North of Nardah" },
	{ code = "DLR", name = "Islands: Poison Waste" },
} :: { Place })

-- A letter -> its position on each dial, from `Dial.LETTERS`.
local POSITIONS: { { [string]: number } } = {}
for dial, letters in ipairs(Dial.LETTERS) do
	POSITIONS[dial] = {}
	for position, letter in ipairs(letters) do
		POSITIONS[dial][letter] = position - 1
	end
end

-- The code spelled by three dial positions (0 to 3 each), "AIP" for all zeros. Nil when one isn't a position.
function Fairyring.code_of(positions: { number }): string?
	local code = ""
	for dial = 1, 3 do
		local letter = Dial.LETTERS[dial][(positions[dial] or -1) + 1]
		if letter == nil then
			return nil
		end
		code ..= letter
	end
	return code
end

-- The positions of a code, nil when it is not a code.
function Fairyring.positions_of(code: string): { number }?
	local letters = Fairyring.parse_code(code)
	if letters == nil then
		return nil
	end
	local positions: { number } = {}
	for dial = 1, 3 do
		table.insert(positions, POSITIONS[dial][string.sub(letters, dial, dial)])
	end
	return positions
end

-- A code written as the player might write it ("aiq", "A I Q", "a-i-q", "A.I.Q") as three capital letters, each from its dial. Nil when the text is not a code.
function Fairyring.parse_code(text: string): string?
	local letters = string.upper((string.gsub(text, "[%s%-%._,]", "")))
	if #letters ~= 3 then
		return nil
	end
	for dial = 1, 3 do
		if POSITIONS[dial][string.sub(letters, dial, dial)] == nil then
			return nil
		end
	end
	return letters
end

-- The place of a code among `Fairyring.PLACES`.
function Fairyring.place(code: string): string?
	local letters = Fairyring.parse_code(code)
	for _, p in ipairs(Fairyring.PLACES) do
		if p.code == letters then
			return p.name
		end
	end
	return nil
end

-- What a text names: a code (as it is) or else a part of a place's name, in any case, among the places of `Fairyring.PLACES` and the travel log's own (when it is open).
-- An exact name wins; otherwise exactly one place must contain the text. Returns the code and the place's name, or nil and why not.
function Fairyring.resolve(text: string): (string?, string?)
	local code = Fairyring.parse_code(text)
	if code ~= nil then
		return code, Fairyring.place(code)
	end
	local wanted = string.lower((string.gsub(text, "^%s*(.-)%s*$", "%1")))
	if wanted == "" then
		return nil, "nothing to look for"
	end
	local seen: { [string]: Place } = {}
	local order: { Place } = {}
	local function add(p: Place)
		if seen[p.code] == nil then
			seen[p.code] = p
			table.insert(order, p)
		end
	end
	for _, d in ipairs(TravelLog.destinations() or {}) do
		add({ code = d.code, name = d.name })
	end
	for _, p in ipairs(Fairyring.PLACES) do
		add(p)
	end
	local matches: { Place } = {}
	for _, p in ipairs(order) do
		local name = string.lower(p.name)
		if name == wanted or string.lower((string.gsub(p.name, "^[^:]*:%s*", ""))) == wanted then
			return p.code, p.name
		elseif string.find(name, wanted, 1, true) then
			table.insert(matches, p)
		end
	end
	if #matches == 1 then
		return matches[1].code, matches[1].name
	elseif #matches == 0 then
		return nil, `no place matches "{text}"`
	end
	local names: { string } = {}
	for _, p in ipairs(matches) do
		table.insert(names, p.name)
	end
	return nil, `"{text}" fits {#matches} places: {table.concat(names, "; ")}`
end

-- Whether the rings can be used now, and if not why: the quest part (the game's own check, see `USE_VARBIT`), then a Dramen or Lunar staff in the inventory or worn, or the
-- Lumbridge & Draynor elite diary.
function Fairyring.can_use(): (boolean, string?)
	if
		varbit(Fairyring.USE_VARBIT) < Fairyring.USE_NEEDED
		or varbit(Fairyring.PERMISSION_VARBIT) < Fairyring.PERMISSION_NEEDED
	then
		return false, 'the fairy rings need "Fairytale II - Cure a Queen" started and advanced'
	end
	if Inventory.contains_any(Fairyring.STAVES) or Wornitems.contains_any(Fairyring.STAVES) then
		return true, nil
	end
	if Diaries.tier(Fairyring.DIARY_REGION, Fairyring.DIARY_TIER) == true then
		return true, nil
	end
	return false,
		"the fairy rings need a Dramen or Lunar staff (carried or worn) or the Lumbridge & Draynor elite diary"
end

-- Errors with the reason when the rings can't be used.
function Fairyring.require()
	local ok, why = Fairyring.can_use()
	if not ok then
		error(why or "the fairy rings can't be used", 2)
	end
end

----------------------------------------------------------------------------------------------------
-- The dials (main screen)

function Dial.is_open(): boolean
	return Toplevel.is_open(Dial.GROUP)
end

-- Whether the dials are open, polled for up to `timeout_ms` (3 seconds by default).
function Dial.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Dial.OPEN_TIMEOUT_MS)
	while true do
		if Dial.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Dial.POLL_MS)
	end
end

-- Where the three dials are, 0 to 3 each.
function Dial.positions(): { number }
	local positions: { number } = {}
	for _, id in ipairs(Dial.VARBITS) do
		table.insert(positions, varbit(id))
	end
	return positions
end

-- The code the dials spell now.
function Dial.code(): string?
	return Fairyring.code_of(Dial.positions())
end

local function area(component: number): Widget?
	local w = widget(Dial.GROUP, component)
	return if w ~= nil and not w.hidden then w else nil
end

-- Turns a dial one step (`clockwise` or not) and waits for it to show. False when it didn't turn.
function Dial.turn(dial: number, clockwise: boolean): boolean
	local varbit_id = Dial.VARBITS[dial]
	local zone = (if clockwise then Dial.CLOCKWISE else Dial.COUNTER_CLOCKWISE)[dial]
	if varbit_id == nil or zone == nil then
		return false
	end
	local before = varbit(varbit_id)
	for _ = 1, Dial.TURN_TRIES do
		local w = area(zone)
		if w == nil then
			return false
		end
		Mouse.click(w)
		local deadline = time() + Dial.TURN_TIMEOUT_MS
		while time() < deadline do
			if varbit(varbit_id) ~= before then
				return true
			end
			sleep(Dial.POLL_MS)
		end
	end
	return false
end

-- Turns the dials to spell `code` (any way `Fairyring.parse_code` reads), each by the shortest way: a half turn goes either way by chance. True when they spell it.
function Dial.set(code: string): boolean
	local target = Fairyring.positions_of(code)
	if target == nil or not Dial.is_open() then
		return false
	end
	for dial = 1, 3 do
		local now = varbit(Dial.VARBITS[dial])
		local steps = (target[dial] - now) % 4
		if steps ~= 0 then
			local clockwise = steps == 1 or (steps == 2 and Random.chance(0.5))
			local count = if clockwise then steps else 4 - steps
			for _ = 1, count do
				if not Dial.turn(dial, clockwise) then
					return false
				end
				Random.sleep(80, 260)
			end
		end
		Random.sleep(60, 220)
	end
	local now = Dial.positions()
	return now[1] == target[1] and now[2] == target[2] and now[3] == target[3]
end

-- Presses "Confirm", which teleports to the code the dials spell, and waits for the interface to go. False when it stayed open (a code with no ring).
function Dial.confirm(): boolean
	local w = area(Dial.CONFIRM)
	if w == nil then
		return false
	end
	Mouse.click(w)
	local deadline = time() + Dial.CONFIRM_TIMEOUT_MS
	while time() < deadline do
		if not Dial.is_open() then
			return true
		end
		sleep(Dial.POLL_MS)
	end
	Log.log("Fairyring", "confirming left the dials open")
	return false
end

-- The close button, nil when the dials aren't open.
function Dial.close_button(): Widget?
	local w = widget(Dial.GROUP, Dial.CLOSE)
	if w == nil or w.hidden or not Dial.is_open() then
		return nil
	end
	return w
end

-- Closes the dials (and with them the travel log): Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.
function Dial.close(key_probability: number?): boolean
	if not Dial.is_open() then
		return true
	end
	return Toplevel.close(
		Dial.GROUP,
		Dial.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

----------------------------------------------------------------------------------------------------
-- The travel log (side tab)

export type Destination = {
	code: string,
	-- "Region: Place"
	name: string,
	-- fully inside the scrolled list
	visible: boolean,
	-- the row: where to click
	row: Widget,
}

function TravelLog.is_open(): boolean
	local title = widget(TravelLog.GROUP, TravelLog.TITLE)
	return title ~= nil and not title.hidden and title.text == TravelLog.TITLE_TEXT
end

-- Whether the log is open, polled for up to `timeout_ms` (3 seconds by default).
function TravelLog.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or TravelLog.OPEN_TIMEOUT_MS)
	while true do
		if TravelLog.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(TravelLog.POLL_MS)
	end
end

-- "<br>Asgarnia: Mudskipper Point " is the place "Asgarnia: Mudskipper Point".
local function clean(text: string): string
	local plain = string.gsub(text, "<[^>]*>", "")
	return (string.gsub(plain, "^%s*(.-)%s*$", "%1"))
end

-- The codes the log lists, top to bottom with the places they lead to. Nil when it isn't open. The code and the place of a row are two texts at the same height: the code in the list's own
-- children (or, for the favourites at the top, a text of the group), the place in the row's clickable text.
function TravelLog.destinations(): { Destination }?
	if not TravelLog.is_open() then
		return nil
	end
	local view = widget(TravelLog.GROUP, TravelLog.LIST)
	if view == nil then
		return nil
	end
	local codes: { [number]: string } = {}
	for _, child in ipairs(widget_children(TravelLog.GROUP, TravelLog.LIST) or {}) do
		if child.kind == 4 and not child.hidden and child.text ~= nil then
			local letters = Fairyring.parse_code(child.text)
			if letters ~= nil then
				codes[child.y] = letters
			end
		end
	end
	local rows: { Widget } = {}
	for component = TravelLog.FIRST_COMPONENT, TravelLog.LAST_COMPONENT do
		local w = widget(TravelLog.GROUP, component)
		if w ~= nil and w.kind == 4 and not w.hidden and w.text ~= nil then
			if w.action == TravelLog.OPTION then
				table.insert(rows, w)
			elseif w.action == nil then
				local letters = Fairyring.parse_code(w.text)
				if letters ~= nil then
					codes[w.y] = letters
				end
			end
		end
	end
	local found: { Destination } = {}
	for _, row in ipairs(rows) do
		local code = codes[row.y]
		local name = clean(row.text or "")
		if code ~= nil and name ~= "" then
			table.insert(found, {
				code = code,
				name = name,
				visible = row.y >= view.y and row.y + row.height <= view.y + view.height,
				row = row,
			})
		end
	end
	table.sort(found, function(a: Destination, b: Destination)
		return a.row.y < b.row.y
	end)
	return found
end

-- The log's row for a destination given as a code or a part of a place's name; nil when the log doesn't list it.
function TravelLog.find(text: string): Destination?
	local all = TravelLog.destinations()
	if all == nil then
		return nil
	end
	local code = Fairyring.resolve(text)
	if code == nil then
		return nil
	end
	for _, d in ipairs(all) do
		if d.code == code then
			return d
		end
	end
	return nil
end

-- Scrolls the log until the destination's row is fully shown and returns it. Nil when the log doesn't list it or won't move.
function TravelLog.scroll_to(text: string): Destination?
	local last: number? = nil
	for _ = 1, TravelLog.MAX_SCROLLS do
		local d = TravelLog.find(text)
		local view = widget(TravelLog.GROUP, TravelLog.LIST)
		if d == nil or view == nil then
			return nil
		end
		if d.visible then
			return d
		end
		if last == d.row.y then
			return nil
		end
		last = d.row.y
		local down = d.row.y > view.y
		Mouse.scroll(Random.int(1, 3), down, Box.new(view.x, view.y, view.x + view.width - 1, view.y + view.height - 1))
		Random.sleep(80, 250)
	end
	return nil
end

-- Clicks the destination's row ("Use code"), which turns the dials to its code (it doesn't teleport: `Dial.confirm` does). Scrolls to it first. False when the log doesn't list it or the
-- dials didn't turn to it.
function TravelLog.select(text: string): boolean
	local d = TravelLog.scroll_to(text)
	if d == nil then
		return false
	end
	Mouse.click(d.row)
	local deadline = time() + TravelLog.CONFIRM_TIMEOUT_MS
	while time() < deadline do
		if Dial.code() == d.code then
			return true
		end
		sleep(TravelLog.POLL_MS)
	end
	Log.log("Fairyring", `using {d.code} didn't turn the dials`)
	return false
end

----------------------------------------------------------------------------------------------------
-- Both together

export type Method = "dial" | "log" | "last" | "favourite" | "zanaris"

-- The nearest fairy ring among the objects loaded, by straight distance on the plane you are on first. Nil when none is loaded.
function Fairyring.nearest(): Loc?
	local me = Walker.position()
	if me == nil then
		return nil
	end
	local best: Loc? = nil
	local best_rank = math.huge
	for _, loc in ipairs(Objects.find(Fairyring.OBJECT) or {}) do
		local rank = Objects.distance(loc, me) + (if loc.plane == me.plane then 0 else 1000)
		if rank < best_rank then
			best, best_rank = loc, rank
		end
	end
	return best
end

function Fairyring.is_open(): boolean
	return Dial.is_open()
end

-- Opens the dials and the travel log with "Configure" on the nearest fairy ring (or `ring`), walking closer first unless `walk` is false. True when they are open (also if they already were).
-- Errors when the rings can't be used (see `Fairyring.can_use`). When it didn't work the second result says why.
function Fairyring.open(ring: Loc?, walk: boolean?): (boolean, string?)
	Fairyring.require()
	if Dial.is_open() then
		return true, nil
	end
	if not Toplevel.escape_clear() then
		return false, "another interface is open"
	end
	local target = ring or Fairyring.nearest()
	if target == nil then
		return false, "no fairy ring around"
	end
	local picked: boolean
	if walk ~= false then
		picked = Objects.approach(target, Fairyring.CONFIGURE)
	else
		picked = Objects.interact(target, Fairyring.CONFIGURE)
	end
	if not picked then
		if not Minimenu.has(Fairyring.CONFIGURE) or not Minimenu.select(Fairyring.CONFIGURE) then
			return false, `couldn't {Fairyring.CONFIGURE} the ring`
		end
	end
	if not Dial.wait_open(Fairyring.OPEN_TIMEOUT_MS) then
		return false, "the dials didn't open"
	end
	Random.sleep(Fairyring.OPEN_SETTLE_MS[1], Fairyring.OPEN_SETTLE_MS[2])
	return true, nil
end

-- Closes the dials and the travel log.
function Fairyring.close(key_probability: number?): boolean
	return Dial.close(key_probability)
end

-- The last code used, which the ring offers as "Last-destination (CODE)" while the interface is closed. Nil when the game has none.
function Fairyring.last_code(): string?
	local last = varbit(Dial.LAST_VARBIT)
	if last < 0 or last > 63 then
		return nil
	end
	return Fairyring.code_of({ last // 16, (last // 4) % 4, last % 4 })
end

-- The ring's menu option for the last code used: "Last-destination (DIS)". Nil when there is none.
function Fairyring.last_option(): string?
	local code = Fairyring.last_code()
	return if code ~= nil then `{Fairyring.LAST} ({code})` else nil
end

-- Waits for the teleport to take you at least `ARRIVED_DISTANCE` tiles from `from`; true when it did.
local function arrived(from: Tile?): boolean
	if from == nil then
		return true
	end
	local deadline = time() + Fairyring.TELEPORT_TIMEOUT_MS
	while time() < deadline do
		local now = Walker.position()
		if
			now ~= nil
			and (
				now.plane ~= from.plane
				or math.max(math.abs(now.x - from.x), math.abs(now.y - from.y)) >= Fairyring.ARRIVED_DISTANCE
			)
		then
			return true
		end
		sleep(Fairyring.POLL_MS)
	end
	return false
end

-- Uses "Last-destination" on the nearest ring (or `ring`), walking closer first unless `walk` is false, and waits for the teleport. Errors when the rings can't be used. False when the
-- interface is open, there is no last code or no ring, or nothing happened.
function Fairyring.travel_last(ring: Loc?, walk: boolean?): boolean
	Fairyring.require()
	local option = Fairyring.last_option()
	if option == nil or Dial.is_open() then
		return false
	end
	local target = ring or Fairyring.nearest()
	if target == nil then
		return false
	end
	local from = Walker.position()
	local picked: boolean
	if walk ~= false then
		picked = Objects.approach(target, option)
	else
		picked = Objects.interact(target, option)
	end
	if not picked then
		return false
	end
	return arrived(from)
end

-- The favourite codes, as the ring's "Favourites" submenu lists them (up to four, in the order of their slots). Read from the game's variables, so nothing is opened.
function Fairyring.favourites(): { string }
	local codes: { string } = {}
	for _, ids in ipairs(Fairyring.FAVOURITE_VARBITS) do
		if varbit(ids[4]) ~= 0 then
			local code = Fairyring.code_of({ varbit(ids[1]), varbit(ids[2]), varbit(ids[3]) })
			if code ~= nil then
				table.insert(codes, code)
			end
		end
	end
	return codes
end

-- Whether `code` is one of the favourites.
function Fairyring.is_favourite(code: string): boolean
	local letters = Fairyring.parse_code(code)
	return letters ~= nil and table.find(Fairyring.favourites(), letters) ~= nil
end

-- Uses a favourite from the ring's menu: right clicks the nearest ring (or `ring`), walking close to it first unless `walk` is false, opens "Favourites" and picks the code, then waits for
-- the teleport. Errors when the rings can't be used. False when the code isn't a favourite, the interface is open, there is no ring or nothing happened.
function Fairyring.travel_favourite(code: string, ring: Loc?, walk: boolean?): boolean
	Fairyring.require()
	local letters = Fairyring.parse_code(code)
	if letters == nil or Dial.is_open() or not Fairyring.is_favourite(letters) then
		return false
	end
	local target = ring or Fairyring.nearest()
	if target == nil then
		return false
	end
	local from = Walker.position()
	if walk ~= false and from ~= nil and Objects.distance(target, from) > Fairyring.MENU_NEAR then
		local at = { x = target.x, y = target.y, plane = target.plane }
		if not Walker.walk(at, { near = Fairyring.MENU_NEAR, transports = false, plane = target.plane }) then
			return false
		end
	end
	if not Objects.hover(target) or not Minimenu.select_submenu(letters, nil, Fairyring.FAVOURITES) then
		Minimenu.close()
		return false
	end
	return arrived(from)
end

-- Goes to Zanaris with the ring's "Zanaris" option on the nearest ring (or `ring`), walking closer first unless `walk` is false, and waits for the teleport. Errors when the rings can't
-- be used or Lost City isn't complete. False when the interface is open, there is no ring or nothing happened.
function Fairyring.travel_zanaris(ring: Loc?, walk: boolean?): boolean
	Fairyring.require()
	if Quests.state(Fairyring.ZANARIS_QUEST) ~= "complete" then
		error(`Zanaris needs the quest "{Fairyring.ZANARIS_QUEST}" complete`, 2)
	end
	if Dial.is_open() then
		return false
	end
	local target = ring or Fairyring.nearest()
	if target == nil then
		return false
	end
	local from = Walker.position()
	local picked: boolean
	if walk ~= false then
		picked = Objects.approach(target, Fairyring.ZANARIS)
	else
		picked = Objects.interact(target, Fairyring.ZANARIS)
	end
	if not picked then
		return false
	end
	return arrived(from)
end

-- Teleports to a destination given as a code ("aiq", "A I Q") or a part of a place's name ("mudskipper"), in any case, and waits for the teleport. Errors when the rings can't be used
-- (see `Fairyring.can_use`) and when the text names no single place. Returns the way it was done ("last", "favourite", "dial", "log" or "zanaris", the ring's own option, which is what the text "zanaris" means), or nil when nothing happened.
-- The way is picked by chance unless `method` says: "last" when the destination is the last code used and the interface is closed (the ring's own option), then "favourite" when it is
-- one of the ring's favourites (its menu), else the travel log (chance `LOG_CHANCE`, when it lists the place) or the dials. A way that fails is followed by the dials.
-- `ring` is the ring to use, the nearest by default.
function Fairyring.travel(text: string, method: Method?, ring: Loc?): Method?
	Fairyring.require()
	if
		method == "zanaris" or (method == nil and string.lower((string.gsub(text, "^%s*(.-)%s*$", "%1"))) == "zanaris")
	then
		return if Fairyring.travel_zanaris(ring) then "zanaris" else nil
	end
	local code, name = Fairyring.resolve(text)
	if code == nil then
		error(name or `"{text}" isn't a fairy ring destination`, 2)
	end
	local from = Walker.position()
	if (method == nil or method == "last") and not Dial.is_open() and Fairyring.last_code() == code then
		if Fairyring.travel_last(ring) then
			return "last"
		end
	end
	if method == "last" then
		return nil
	end
	if (method == nil or method == "favourite") and not Dial.is_open() and Fairyring.is_favourite(code) then
		if Fairyring.travel_favourite(code, ring) then
			return "favourite"
		end
	end
	if method == "favourite" then
		return nil
	end
	local ok, why = Fairyring.open(ring)
	if not ok then
		Log.log("Fairyring", why or "couldn't open the dials")
		return nil
	end
	local way: Method? = method
	if way == nil and TravelLog.find(code) ~= nil and Random.chance(Biometrics.random_double(Fairyring.LOG_CHANCE)) then
		way = "log"
	end
	if way == "log" then
		if TravelLog.select(code) and Dial.confirm() and arrived(from) then
			return "log"
		end
		if not Dial.is_open() then
			return nil
		end
		Log.log("Fairyring", `the log didn't take {code}, using the dials`)
	end
	if Dial.set(code) and Dial.confirm() and arrived(from) then
		return "dial"
	end
	return nil
end

return Fairyring
