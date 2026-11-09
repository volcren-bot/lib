--!strict
local Host = require("@lib/host")
local widget = Host.widget
local widget_children = Host.widget_children
local host_varbit = Host.varbit
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
local Widgets = require("@lib/main/interfaces/widgets")
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

local Box = Geometry.Box

local function varbit(id: number): number
	return (host_varbit(id)) or 0
end

local function trim(text: string): string
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

local Fairyring = {}
local Dial = {}
local TravelLog = {}
Fairyring.Dial = Dial
Fairyring.Log = TravelLog

Fairyring.OBJECT = "Fairy ring"
Fairyring.SPIRITUAL = "Spiritual Fairy Tree"
Fairyring.CONFIGURE = "Configure"
Fairyring.LAST = "Last-destination"
Fairyring.ZANARIS = "Zanaris"
Fairyring.ZANARIS_QUEST = "Lost City"
Fairyring.FAVOURITES = "Favourites"
Fairyring.FAVOURITE_VARBITS = {
	{ 4555, 5008, 5009, 5010 },
	{ 5011, 5012, 5013, 5014 },
	{ 5015, 5016, 5017, 5018 },
	{ 5019, 5020, 5021, 5022 },
}
Fairyring.MENU_NEAR = 4

Fairyring.OPEN_TIMEOUT_MS = 4000
Fairyring.POLL_MS = 50
Fairyring.TELEPORT_TIMEOUT_MS = 8000
Fairyring.ARRIVED_DISTANCE = 20
Fairyring.OPEN_SETTLE_MS = { 250, 500 }
Fairyring.LOG_CHANCE = 0.3

Fairyring.USE_VARBIT = 2328
Fairyring.PERMISSION_VARBIT = 2329
Fairyring.USE_NEEDED = 1
Fairyring.PERMISSION_NEEDED = 2
Fairyring.STAVES = { "Dramen staff", "Lunar staff" }
Fairyring.DIARY_REGION = "lumbridge"
Fairyring.DIARY_TIER = "elite"

Dial.GROUP = 398
Dial.TITLE = 2
Dial.CONFIRM = 26
Dial.CLOSE = 27
Dial.CLOCKWISE = { 19, 21, 23 }
Dial.COUNTER_CLOCKWISE = { 20, 22, 24 }
Dial.VARBITS = { 3985, 3986, 3987 }
Dial.LETTERS = { { "A", "D", "C", "B" }, { "I", "L", "K", "J" }, { "P", "S", "R", "Q" } }
Dial.LAST_VARBIT = 5374

Dial.OPEN_TIMEOUT_MS = 3000
Dial.TURN_TIMEOUT_MS = 1500
Dial.TURN_TRIES = 3
Dial.CONFIRM_TIMEOUT_MS = 4000
Dial.POLL_MS = 50

TravelLog.GROUP = 381
TravelLog.TITLE = 6
TravelLog.LIST = 8
TravelLog.TITLE_TEXT = "Travel log"
TravelLog.OPTION = "Use code"
TravelLog.FIRST_COMPONENT = 12
TravelLog.LAST_COMPONENT = 170
TravelLog.MAX_SCROLLS = 40
TravelLog.OPEN_TIMEOUT_MS = 3000
TravelLog.CONFIRM_TIMEOUT_MS = 4000
TravelLog.POLL_MS = 50

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

local POSITIONS: { { [string]: number } } = {}
for dial, letters in ipairs(Dial.LETTERS) do
	POSITIONS[dial] = {}
	for position, letter in ipairs(letters) do
		POSITIONS[dial][letter] = position - 1
	end
end

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

function Fairyring.place(code: string): string?
	local letters = Fairyring.parse_code(code)
	for _, p in ipairs(Fairyring.PLACES) do
		if p.code == letters then
			return p.name
		end
	end
	return nil
end

function Fairyring.resolve(text: string): (string?, string?)
	local code = Fairyring.parse_code(text)
	if code ~= nil then
		return code, Fairyring.place(code)
	end
	local wanted = string.lower(trim(text))
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

function Fairyring.require()
	local ok, why = Fairyring.can_use()
	if not ok then
		error(why or "the fairy rings can't be used", 2)
	end
end

function Dial.is_open(): boolean
	return Toplevel.is_open(Dial.GROUP)
end

function Dial.wait_open(timeout_ms: number?): boolean
	return Widgets.wait_for(Dial.is_open, timeout_ms or Dial.OPEN_TIMEOUT_MS, Dial.POLL_MS)
end

function Dial.positions(): { number }
	local positions: { number } = {}
	for _, id in ipairs(Dial.VARBITS) do
		table.insert(positions, varbit(id))
	end
	return positions
end

function Dial.code(): string?
	return Fairyring.code_of(Dial.positions())
end

local function area(component: number): Widget?
	local w = widget(Dial.GROUP, component)
	return if w ~= nil and not w.hidden then w else nil
end

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
		if
			Widgets.wait_within(function()
				return varbit(varbit_id) ~= before
			end, Dial.TURN_TIMEOUT_MS, Dial.POLL_MS)
		then
			return true
		end
	end
	return false
end

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

function Dial.confirm(): boolean
	local w = area(Dial.CONFIRM)
	if w == nil then
		return false
	end
	Mouse.click(w)
	if Widgets.wait_within(function()
		return not Dial.is_open()
	end, Dial.CONFIRM_TIMEOUT_MS, Dial.POLL_MS) then
		return true
	end
	Log.log("Fairyring", "confirming left the dials open")
	return false
end

function Dial.close_button(): Widget?
	local w = widget(Dial.GROUP, Dial.CLOSE)
	if w == nil or w.hidden or not Dial.is_open() then
		return nil
	end
	return w
end

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

export type Destination = {
	code: string,
	name: string,
	visible: boolean,
	row: Widget,
}

function TravelLog.is_open(): boolean
	local title = widget(TravelLog.GROUP, TravelLog.TITLE)
	return title ~= nil and not title.hidden and title.text == TravelLog.TITLE_TEXT
end

function TravelLog.wait_open(timeout_ms: number?): boolean
	return Widgets.wait_for(TravelLog.is_open, timeout_ms or TravelLog.OPEN_TIMEOUT_MS, TravelLog.POLL_MS)
end

local function clean(text: string): string
	return trim((string.gsub(text, "<[^>]*>", "")))
end

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

function TravelLog.select(text: string): boolean
	local d = TravelLog.scroll_to(text)
	if d == nil then
		return false
	end
	Mouse.click(d.row)
	if
		Widgets.wait_within(function()
			return Dial.code() == d.code
		end, TravelLog.CONFIRM_TIMEOUT_MS, TravelLog.POLL_MS)
	then
		return true
	end
	Log.log("Fairyring", `using {d.code} didn't turn the dials`)
	return false
end

export type Method = "dial" | "log" | "last" | "favourite" | "zanaris"

function Fairyring.nearest(): Loc?
	local me = Walker.position()
	if me == nil then
		return nil
	end
	local best: Loc? = nil
	local best_rank = math.huge
	for _, name in { Fairyring.OBJECT, Fairyring.SPIRITUAL } do
		for _, loc in ipairs(Objects.find(name) or {}) do
			local rank = Objects.distance(loc, me) + (if loc.plane == me.plane then 0 else 1000)
			if rank < best_rank then
				best, best_rank = loc, rank
			end
		end
	end
	return best
end

function Fairyring.is_open(): boolean
	return Dial.is_open()
end

local function option_on(ring: Loc, option: string): string
	if ring.name ~= Fairyring.SPIRITUAL then
		return option
	end
	if option == Fairyring.ZANARIS then
		return `Ring-{option}`
	end
	return `Ring-{string.lower(string.sub(option, 1, 1))}{string.sub(option, 2)}`
end

local function use(target: Loc, option: string, walk: boolean?): boolean
	if walk ~= false then
		return Objects.approach(target, option)
	end
	return Objects.interact(target, option)
end

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
	local option = option_on(target, Fairyring.CONFIGURE)
	if not use(target, option, walk) then
		if not Minimenu.has(option) or not Minimenu.select(option) then
			return false, `couldn't {option} the ring`
		end
	end
	if not Dial.wait_open(Fairyring.OPEN_TIMEOUT_MS) then
		return false, "the dials didn't open"
	end
	Random.sleep(Fairyring.OPEN_SETTLE_MS[1], Fairyring.OPEN_SETTLE_MS[2])
	return true, nil
end

function Fairyring.close(key_probability: number?): boolean
	return Dial.close(key_probability)
end

function Fairyring.last_code(): string?
	local last = varbit(Dial.LAST_VARBIT)
	if last < 0 or last > 63 then
		return nil
	end
	return Fairyring.code_of({ last // 16, (last // 4) % 4, last % 4 })
end

function Fairyring.last_option(): string?
	local code = Fairyring.last_code()
	return if code ~= nil then `{Fairyring.LAST} ({code})` else nil
end

local function arrived(from: Tile?): boolean
	if from == nil then
		return true
	end
	local origin: Tile = from
	return Widgets.wait_within(function()
		local now = Walker.position()
		return now ~= nil
			and (
				now.plane ~= origin.plane
				or math.max(math.abs(now.x - origin.x), math.abs(now.y - origin.y)) >= Fairyring.ARRIVED_DISTANCE
			)
	end, Fairyring.TELEPORT_TIMEOUT_MS, Fairyring.POLL_MS)
end

local function ride(ring: Loc?, walk: boolean?, option: string): boolean
	local target = ring or Fairyring.nearest()
	if target == nil then
		return false
	end
	local from = Walker.position()
	if not use(target, option_on(target, option), walk) then
		return false
	end
	return arrived(from)
end

function Fairyring.travel_last(ring: Loc?, walk: boolean?): boolean
	Fairyring.require()
	local option = Fairyring.last_option()
	if option == nil or Dial.is_open() then
		return false
	end
	return ride(ring, walk, option)
end

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

function Fairyring.is_favourite(code: string): boolean
	local letters = Fairyring.parse_code(code)
	return letters ~= nil and table.find(Fairyring.favourites(), letters) ~= nil
end

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

function Fairyring.travel_zanaris(ring: Loc?, walk: boolean?): boolean
	Fairyring.require()
	if Quests.state(Fairyring.ZANARIS_QUEST) ~= "complete" then
		error(`Zanaris needs the quest "{Fairyring.ZANARIS_QUEST}" complete`, 2)
	end
	if Dial.is_open() then
		return false
	end
	return ride(ring, walk, Fairyring.ZANARIS)
end

function Fairyring.travel(text: string, method: Method?, ring: Loc?): Method?
	Fairyring.require()
	if method == "zanaris" or (method == nil and string.lower(trim(text)) == "zanaris") then
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
	local around = ring or Fairyring.nearest()
	local has_favourites = around == nil or around.name ~= Fairyring.SPIRITUAL
	if
		(method == nil or method == "favourite")
		and has_favourites
		and not Dial.is_open()
		and Fairyring.is_favourite(code)
	then
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
