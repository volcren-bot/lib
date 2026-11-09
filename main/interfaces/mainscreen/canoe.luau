--!strict
local Host = require("@lib/host")
local menu = Host.menu
local sleep = Host.sleep
local time = Host.time
local widget = Host.widget
type Loc = Host.Loc
type Npc = Host.Npc
local ChatOptions = require("@lib/main/interfaces/chatbox/chat_options")
local Mouse = require("@lib/utils/input/mouse")
local Npcs = require("@lib/main/entities/npcs")
local Objects = require("@lib/main/entities/objects")
local Player = require("@lib/main/player")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Widgets = require("@lib/main/interfaces/widgets")

local Canoe = {}

Canoe.SHAPE_GROUP = 416
Canoe.SHAPE_CLOSE = 9
Canoe.ARDOUGNE_MAP = 952
Canoe.LUMBRIDGE_MAP = 953
Canoe.MAP_CLOSE = 5

Canoe.STATION = "Canoe Station"
Canoe.CHOP = "Chop-down"
Canoe.SHAPE = "Shape-Canoe"
Canoe.FLOAT = "Float"
Canoe.PADDLE = "Paddle Canoe"
Canoe.TRAVEL = "Travel to"
Canoe.STORE_AXE = "Store-axe"
Canoe.NO_AXE = "no axe"
Canoe.CANT_REACH = "this canoe can't reach that far"
Canoe.NO_AXE_TEXT = "you need an axe"

Canoe.STATION_RANGE = 12
Canoe.POLL_MS = 100
Canoe.HOVER_TIMEOUT_MS = 800
Canoe.OPEN_TIMEOUT_MS = 5000
Canoe.STEP_TIMEOUT_MS = 10000
Canoe.SETTLED_MS = 700
Canoe.TRIP_TIMEOUT_MS = 45000
Canoe.ARRIVED_NEAR = 4

export type Kind = "Log" | "Dugout" | "Stable dugout" | "Waka"
export type Stage = "chop" | "shape" | "float" | "paddle"

Canoe.Kind = table.freeze({
	Log = "Log",
	Dugout = "Dugout",
	StableDugout = "Stable dugout",
	Waka = "Waka",
}) :: {
	Log: "Log",
	Dugout: "Dugout",
	StableDugout: "Stable dugout",
	Waka: "Waka",
}

Canoe.KINDS = {
	["Log"] = { button = 20, level = 12 },
	["Dugout"] = { button = 18, level = 27 },
	["Stable dugout"] = { button = 12, level = 42 },
	["Waka"] = { button = 11, level = 57 },
} :: { [Kind]: { button: number, level: number } }

Canoe.PLACES = {
	["Castle Wars"] = { map = Canoe.ARDOUGNE_MAP, button = 7, tile = { x = 2436, y = 3134 } },
	["Tree Gnome Village"] = { map = Canoe.ARDOUGNE_MAP, button = 12, tile = { x = 2486, y = 3188 } },
	["The Clock Tower"] = { map = Canoe.ARDOUGNE_MAP, button = 17, tile = { x = 2577, y = 3261 } },
	["Chaos Druid Tower"] = { map = Canoe.ARDOUGNE_MAP, button = 22, tile = { x = 2571, y = 3360 } },
	["Tree Gnome Stronghold"] = { map = Canoe.ARDOUGNE_MAP, button = 27, tile = { x = 2523, y = 3408 } },
	["Lumbridge"] = { map = Canoe.LUMBRIDGE_MAP, button = 7, tile = { x = 3240, y = 3242 } },
	["Champions Guild"] = { map = Canoe.LUMBRIDGE_MAP, button = 12, tile = { x = 3199, y = 3344 } },
	["Barbarian Village"] = { map = Canoe.LUMBRIDGE_MAP, button = 17, tile = { x = 3109, y = 3415 } },
	["Edgeville"] = { map = Canoe.LUMBRIDGE_MAP, button = 22, tile = { x = 3128, y = 3503 } },
	["Ferox Enclave"] = { map = Canoe.LUMBRIDGE_MAP, button = 27, tile = { x = 3154, y = 3638 } },
	["Wilderness Pond"] = { map = Canoe.LUMBRIDGE_MAP, button = 28, tile = { x = 3141, y = 3796 } },
} :: { [string]: { map: number, button: number, tile: { x: number, y: number } } }

Canoe.STATIONS = {
	[12163] = { varbit = 1839, map = Canoe.LUMBRIDGE_MAP },
	[12164] = { varbit = 1840, map = Canoe.LUMBRIDGE_MAP },
	[12165] = { varbit = 1841, map = Canoe.LUMBRIDGE_MAP },
	[12166] = { varbit = 1842, map = Canoe.LUMBRIDGE_MAP },
	[39638] = { varbit = 10527, map = Canoe.LUMBRIDGE_MAP },
	[60845] = { varbit = 20254, map = Canoe.ARDOUGNE_MAP },
	[60846] = { varbit = 20258, map = Canoe.ARDOUGNE_MAP },
	[60847] = { varbit = 20256, map = Canoe.ARDOUGNE_MAP },
	[60848] = { varbit = 20257, map = Canoe.ARDOUGNE_MAP },
	[60849] = { varbit = 20255, map = Canoe.ARDOUGNE_MAP },
} :: { [number]: { varbit: number, map: number } }

Canoe.KEEPERS = { 1323, 1324, 1325, 1326, 10370, 15601, 15602, 15603, 15604, 15605 }

function Canoe.kind_for_level(level: number?): Kind
	local best: Kind = "Waka"
	for name, kind in Canoe.KINDS do
		if level ~= nil and kind.level >= level and kind.level < Canoe.KINDS[best].level then
			best = name
		end
	end
	return best
end

function Canoe.station(): Loc?
	local here = Player.position()
	if here == nil then
		return nil
	end
	local loc = Objects.nearest(Canoe.STATION, here)
	if loc == nil or Objects.distance(loc, here) > Canoe.STATION_RANGE or Canoe.STATIONS[loc.id] == nil then
		return nil
	end
	return loc
end

local function next_step(loc: Loc): (Stage?, string?)
	if not Objects.hover(loc) then
		return nil, nil
	end
	local deadline = time() + Canoe.HOVER_TIMEOUT_MS
	repeat
		for _, entry in ipairs(menu() or {}) do
			if Objects.owns(loc, entry) then
				if entry.option == Canoe.CHOP then
					return "chop", entry.option
				elseif entry.option == Canoe.SHAPE then
					return "shape", entry.option
				elseif entry.option == Canoe.PADDLE then
					return "paddle", entry.option
				elseif string.sub(entry.option, 1, #Canoe.FLOAT) == Canoe.FLOAT then
					return "float", entry.option
				end
			end
		end
		sleep(Canoe.POLL_MS)
	until time() >= deadline
	return nil, nil
end

function Canoe.stage(): Stage?
	local loc = Canoe.station()
	if loc == nil then
		return nil
	end
	return (next_step(loc))
end

local function newest_uid(): number
	local all = Host.chat_messages() or {}
	local last = all[#all]
	return if last ~= nil then last.uid else 0
end

local function said_no_axe(seen: number): boolean
	local all = Host.chat_messages() or {}
	for i = #all, 1, -1 do
		if all[i].uid == seen then
			return false
		end
		if string.find(string.lower(all[i].text), Canoe.NO_AXE_TEXT, 1, true) ~= nil then
			return true
		end
	end
	return false
end

local function wait_state(varbit: number, before: number): (boolean, string?)
	local seen = newest_uid()
	local deadline = time() + Canoe.STEP_TIMEOUT_MS
	local last, since = before, time()
	while time() < deadline do
		local now = Host.varbit(varbit)
		if said_no_axe(seen) then
			return false, Canoe.NO_AXE
		end
		if now ~= last then
			last, since = now :: number, time()
		elseif last ~= before and time() - since >= Canoe.SETTLED_MS then
			return true
		end
		sleep(Canoe.POLL_MS)
	end
	return false
end

local function click_button(group: number, child: number, option: string): boolean
	local w = widget(group, child)
	if w == nil or w.hidden then
		return false
	end
	Mouse.move(w)
	local id = group * 65536 + child
	local deadline = time() + Canoe.HOVER_TIMEOUT_MS
	repeat
		local first = (menu() or {})[1]
		if first ~= nil and first.id == id and string.sub(first.option, 1, #option) == option then
			Mouse.click()
			return true
		end
		sleep(Canoe.POLL_MS)
	until time() >= deadline
	return false
end

local function close(group: number, child: number)
	Toplevel.close(group, function(): Host.Widget?
		return widget(group, child)
	end)
end

local function wait_open(group: number): boolean
	return Widgets.wait_for(function(): boolean
		return Toplevel.is_open(group)
	end, Canoe.OPEN_TIMEOUT_MS, Canoe.POLL_MS)
end

local function chop(loc: Loc, varbit: number): (boolean, string?)
	local before = Host.varbit(varbit) :: number
	if not Objects.approach(loc, Canoe.CHOP) then
		return false, "couldn't click the station"
	end
	local ok, why = wait_state(varbit, before)
	return ok, if ok then nil else why or "the station wasn't chopped"
end

local function shape(loc: Loc, varbit: number, kind: Kind): (boolean, string?)
	local before = Host.varbit(varbit) :: number
	if not Objects.approach(loc, Canoe.SHAPE) or not wait_open(Canoe.SHAPE_GROUP) then
		return false, "the shaping interface didn't open"
	end
	if not click_button(Canoe.SHAPE_GROUP, Canoe.KINDS[kind].button, "Make") then
		close(Canoe.SHAPE_GROUP, Canoe.SHAPE_CLOSE)
		return false, `can't make a {kind} canoe`
	end
	local ok, why = wait_state(varbit, before)
	return ok, if ok then nil else why or "the canoe wasn't shaped"
end

local function float(loc: Loc, varbit: number, option: string): (boolean, string?)
	local before = Host.varbit(varbit) :: number
	if Objects.approach(loc, option) and wait_state(varbit, before) then
		return true
	end
	return false, "the canoe wasn't floated"
end

local function paddle(loc: Loc, place: string): (boolean, string?)
	local p = Canoe.PLACES[place]
	if not Objects.approach(loc, Canoe.PADDLE) or not wait_open(p.map) then
		return false, "the map didn't open"
	end
	if not click_button(p.map, p.button, Canoe.TRAVEL) then
		close(p.map, Canoe.MAP_CLOSE)
		return false, Canoe.CANT_REACH
	end
	if
		Widgets.wait_within(function(): boolean
			local now = Player.position()
			return now ~= nil and math.max(math.abs(now.x - p.tile.x), math.abs(now.y - p.tile.y)) <= Canoe.ARRIVED_NEAR
		end, Canoe.TRIP_TIMEOUT_MS, Canoe.POLL_MS * 2)
	then
		return true
	end
	return false, "the trip didn't land"
end

function Canoe.travel(place: string, kind: Kind?): (boolean, string?)
	if Canoe.PLACES[place] == nil then
		return false, `{place} isn't a canoe stop`
	end
	for _ = 1, 4 do
		local loc = Canoe.station()
		if loc == nil then
			return false, "no canoe station here"
		end
		local varbit = Canoe.STATIONS[loc.id].varbit
		local stage, option = next_step(loc)
		local ok, why
		if stage == "chop" then
			ok, why = chop(loc, varbit)
		elseif stage == "shape" then
			ok, why = shape(loc, varbit, kind or Canoe.Kind.Waka)
		elseif stage == "float" then
			ok, why = float(loc, varbit, option :: string)
		elseif stage == "paddle" then
			return paddle(loc, place)
		else
			return false, "couldn't read the station"
		end
		if not ok then
			return false, why
		end
	end
	return false, "the station didn't get to its last step"
end

function Canoe.keeper(): Npc?
	local here = Player.position()
	if here == nil then
		return nil
	end
	local all = Npcs.find()
	if all == nil then
		return nil
	end
	local best: Npc? = nil
	local best_distance = math.huge
	for _, id in ipairs(Canoe.KEEPERS) do
		local npc: Npc? = nil
		local npc_distance = math.huge
		for _, n in ipairs(all) do
			local d = Npcs.distance(n, here)
			if n.id == id and d < npc_distance then
				npc, npc_distance = n, d
			end
		end
		if npc ~= nil and npc_distance <= Canoe.STATION_RANGE and npc_distance < best_distance then
			best, best_distance = npc, npc_distance
		end
	end
	return best
end

function Canoe.swap_axe(): boolean
	local npc = Canoe.keeper()
	if npc == nil or not Npcs.approach(npc, Canoe.STORE_AXE) then
		return false
	end
	local deadline = time() + Canoe.OPEN_TIMEOUT_MS
	while time() < deadline do
		if ChatOptions.contains_continue() then
			return ChatOptions.continue_chat(0)
		end
		sleep(Canoe.POLL_MS)
	end
	return false
end

return Canoe
