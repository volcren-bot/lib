--!strict
-- The hot air balloons' map (group 469, `zep_balloon_map` in the cache), opened by "Fly" on a balloon's pilot or "Use" on its basket. The pilots are different NPCs, often with an empty name, so "Fly" is what identifies one.
-- A place is chosen by clicking its name on the map, whose menu only says "Travel". The flight is a jump of a few seconds, and it spends one log of the place's kind, from the inventory or the log storage at any balloon.
-- The stored counts aren't in the game's variables: they are only said in the chat, so they are read from there. A count not said yet is taken to be there, and a flight that doesn't happen says otherwise for a while.
local Host = require("@lib/host")
local menu = Host.menu
local widget = Host.widget
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
type Npc = Host.Npc
type Loc = Host.Loc
local ChatOptions = require("@lib/main/interfaces/chatbox/chat_options")
local GameVal = require("@lib/utils/game_val")
local Log = require("@lib/utils/log")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Mouse = require("@lib/utils/input/mouse")
local Npcs = require("@lib/main/entities/npcs")
local Objects = require("@lib/main/entities/objects")
local Player = require("@lib/main/player")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")

local Balloon = {}

Balloon.GROUP = 469
Balloon.CLOSE = 26
-- The inventory's container, the options that open the map and read the storage, the map's option, and what the baskets and storages are called.
Balloon.INVENTORY = 93
Balloon.OPTION = "Fly"
Balloon.BASKET = "Basket"
Balloon.BASKET_OPTION = "Use"
Balloon.STORAGE = "Log storage"
Balloon.CHECK_OPTION = "Check"
Balloon.TRAVEL = "Travel"

Balloon.OPEN_TIMEOUT_MS = 3000
Balloon.HOVER_TIMEOUT_MS = 800
Balloon.FLIGHT_TIMEOUT_MS = 6000
Balloon.CHECK_TIMEOUT_MS = 4000
Balloon.POLL_MS = 50
-- The menu follows the mouse a frame or so late, and would still show the place before.
Balloon.SETTLE_MS = 150
-- A pause (min, max in ms) after `open` finds the map, before it returns.
Balloon.OPEN_SETTLE_MS = { 250, 500 }
-- Finding the pilot: how far to look, how many NPCs to ask at most, and how long to wait after hovering one.
Balloon.PILOT_RANGE = 12
Balloon.PILOT_ASK_LIMIT = 8
Balloon.PILOT_HOVER_MS = 350
-- A jump of this many tiles is the flight: walking can't do it.
Balloon.LAND_DISTANCE = 6
-- How long a log is taken to be out after a flight didn't happen, which could also be a click that missed.
Balloon.OUT_MS = 5 * 60 * 1000

export type Place = "Entrana" | "Taverley" | "Crafting Guild" | "Varrock" | "Castle Wars" | "Grand Tree"

Balloon.Place = table.freeze({
	Entrana = "Entrana",
	Taverley = "Taverley",
	CraftingGuild = "Crafting Guild",
	Varrock = "Varrock",
	CastleWars = "Castle Wars",
	GrandTree = "Grand Tree",
}) :: {
	Entrana: "Entrana",
	Taverley: "Taverley",
	CraftingGuild: "Crafting Guild",
	Varrock: "Varrock",
	CastleWars: "Castle Wars",
	GrandTree: "Grand Tree",
}

-- A kind of log: its item id, and how the chat names it, in lowercase.
export type LogKind = { id: number, name: string }

local LOGS: LogKind = { id = 1511, name = "logs" }
local OAK: LogKind = { id = 1521, name = "oak logs" }
local WILLOW: LogKind = { id = 1519, name = "willow logs" }
local YEW: LogKind = { id = 1515, name = "yew logs" }
local MAGIC: LogKind = { id = 1513, name = "magic logs" }

Balloon.LOG_KINDS = { LOGS, OAK, WILLOW, YEW, MAGIC }

-- Each place: the map's component that is clicked, the log it takes, and the varbit and value that unlock it.
Balloon.PLACES = {
	["Castle Wars"] = { button = 13, log = YEW, varbit = 2869, value = 1 },
	["Grand Tree"] = { button = 14, log = MAGIC, varbit = 2870, value = 1 },
	["Crafting Guild"] = { button = 15, log = OAK, varbit = 2871, value = 1 },
	["Entrana"] = { button = 16, log = LOGS, varbit = 2867, value = 2 },
	["Taverley"] = { button = 17, log = LOGS, varbit = 2868, value = 2 },
	["Varrock"] = { button = 18, log = WILLOW, varbit = 2872, value = 1 },
} :: { [string]: { button: number, log: LogKind, varbit: number, value: number } }

export type Destination = {
	name: string,
	-- the name on the map: where to hover and click
	area: Widget,
	log: LogKind,
	unlocked: boolean,
}

function Balloon.is_open(): boolean
	return Toplevel.is_open(Balloon.GROUP)
end

-- Whether the map is open, polled for up to `timeout_ms` (`OPEN_TIMEOUT_MS` by default).
function Balloon.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Balloon.OPEN_TIMEOUT_MS)
	while true do
		if Balloon.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Balloon.POLL_MS)
	end
end

-- Whether the account has this balloon, by the game's varbit. It doesn't need the map.
function Balloon.is_unlocked(place: Place): boolean
	local p = Balloon.PLACES[place]
	return p ~= nil and Host.varbit(p.varbit) == p.value
end

-- Every place on the map. The map shows them all, unlocked or not. Nil when it isn't open.
function Balloon.destinations(): { Destination }?
	if not Balloon.is_open() then
		return nil
	end
	local found: { Destination } = {}
	for name, p in Balloon.PLACES do
		local w = widget(Balloon.GROUP, p.button)
		if w ~= nil and not w.hidden then
			table.insert(found, { name = name, area = w, log = p.log, unlocked = Balloon.is_unlocked(name :: any) })
		end
	end
	return found
end

-- The place called `name`, ignoring case. Nil when the map isn't open or has no such place.
function Balloon.find(name: string): Destination?
	local wanted = string.lower(name)
	for _, d in ipairs(Balloon.destinations() or {}) do
		if string.lower(d.name) == wanted then
			return d
		end
	end
	return nil
end

-- When a flight last didn't happen, by log name.
local out_of: { [string]: number } = {}

-- The logs in storage as the chat last said, by log name in lowercase, from the crate's "This crate currently contains ..." and a flight's "You have 29 sets of Magic logs left in storage.". A kind not said yet is missing.
-- The chat is read newest first, and the game keeps it for the session, so this can be called anywhere.
function Balloon.stored(): { [string]: number }
	local counts: { [string]: number } = {}
	local all = Host.chat_messages() or {}
	for i = #all, 1, -1 do
		local text = string.lower(all[i].text)
		local number, name = string.match(text, "you have (%d+) sets? of ([%a ]+) left in storage")
		if number ~= nil and name ~= nil and counts[name] == nil then
			counts[name] = tonumber(number) :: number
		end
		if string.find(text, "this crate currently contains", 1, true) ~= nil then
			text = string.gsub(text, "<br>", " ")
			for _, kind in ipairs(Balloon.LOG_KINDS) do
				if counts[kind.name] == nil then
					-- an unnamed kind is none; "30 logs" isn't to be found inside "30 oak logs"
					counts[kind.name] = tonumber(string.match(text, `(%d+) {kind.name}`) or "0") :: number
				end
			end
			break
		end
	end
	return counts
end

-- Whether the inventory holds the log a flight to this place takes.
function Balloon.holds_log(place: Place): boolean
	local p = Balloon.PLACES[place]
	if p == nil then
		return false
	end
	for _, item in ipairs(Host.item_container(Balloon.INVENTORY) or {}) do
		if item.id == p.log.id then
			return true
		end
	end
	return false
end

-- Whether a flight to this place has a log to spend: one in the inventory, or in storage unless the chat said or a flight showed there are none.
function Balloon.has_log(place: Place): boolean
	local p = Balloon.PLACES[place]
	if p == nil then
		return false
	end
	if Balloon.holds_log(place) then
		return true
	end
	local out = out_of[p.log.name]
	if out ~= nil and time() - out < Balloon.OUT_MS then
		return false
	end
	local count = Balloon.stored()[p.log.name]
	return count == nil or count > 0
end

-- Whether the menu where the mouse is now would travel to this place on a left click, waiting a moment for the game to show it.
local function offers(id: number): boolean
	local deadline = time() + Balloon.HOVER_TIMEOUT_MS
	while true do
		for _, entry in ipairs(menu() or {}) do
			if entry.option ~= "Cancel" then
				if entry.option == Balloon.TRAVEL and entry.id == id then
					return true
				end
				break
			end
		end
		if time() >= deadline then
			return false
		end
		sleep(Balloon.POLL_MS)
	end
end

-- Clicks a place on the map and waits for the flight and for the map to go, which it does a moment after landing. True when it happened. When it didn't the second result says why: then the place's log is taken to be out for `OUT_MS`.
-- The click only happens once the menu under the mouse offers that place's "Travel".
function Balloon.select(place: Place): (boolean, string?)
	local d = Balloon.find(place)
	if d == nil then
		return false, `{place} isn't on the map`
	end
	Mouse.move(d.area)
	sleep(Balloon.SETTLE_MS)
	if not offers(d.area.id) then
		return false, `the menu didn't offer {d.name}`
	end
	local from = Player.position()
	if from == nil then
		return false, "the player's position isn't known"
	end
	Mouse.click()
	local deadline = time() + Balloon.FLIGHT_TIMEOUT_MS
	while time() < deadline do
		local now = Player.position()
		if now ~= nil and math.max(math.abs(now.x - from.x), math.abs(now.y - from.y)) >= Balloon.LAND_DISTANCE then
			local closing = time() + Balloon.OPEN_TIMEOUT_MS
			while Balloon.is_open() and time() < closing do
				sleep(Balloon.POLL_MS)
			end
			return true, nil
		end
		sleep(Balloon.POLL_MS)
	end
	out_of[d.log.name] = time()
	Log.log("Balloon", `the flight to {d.name} didn't happen: taking {d.log.name} to be out`)
	return false, `the flight to {d.name} didn't happen`
end

-- The close button, nil when the map isn't open.
function Balloon.close_button(): Widget?
	local w = widget(Balloon.GROUP, Balloon.CLOSE)
	if w == nil or w.hidden or not Balloon.is_open() then
		return nil
	end
	return w
end

-- Closes the map: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.
function Balloon.close(key_probability: number?): boolean
	if not Balloon.is_open() then
		return true
	end
	return Toplevel.close(
		Balloon.GROUP,
		Balloon.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

-- The NPC near you (within `PILOT_RANGE` tiles) that offers "Fly", found by asking: those the cache calls a balloon's first (`zep_`), then the rest, nearest first, up to `PILOT_ASK_LIMIT` hovered. Nil when there is none.
function Balloon.find_pilot(): Npc?
	local me = Player.position()
	if me == nil then
		return nil
	end
	local candidates: { { npc: Npc, rank: number } } = {}
	for _, n in ipairs(Host.npcs() or {}) do
		local d = math.max(math.abs(n.x - me.x), math.abs(n.y - me.y))
		if d <= Balloon.PILOT_RANGE then
			local name = GameVal.name(GameVal.NPC, n.id)
			local ours = name ~= nil and string.find(name, "zep_", 1, true) ~= nil
			table.insert(candidates, { npc = n, rank = if ours then d else d + 1000 })
		end
	end
	table.sort(candidates, function(a, b)
		return a.rank < b.rank
	end)
	for i, c in ipairs(candidates) do
		if i > Balloon.PILOT_ASK_LIMIT then
			break
		end
		if Npcs.hover(c.npc) then
			sleep(Balloon.PILOT_HOVER_MS)
			for _, entry in ipairs(Minimenu.entries() or {}) do
				if entry.option == Balloon.OPTION then
					return c.npc
				end
			end
		end
	end
	return nil
end

-- The nearest loc called `name` within `PILOT_RANGE` tiles of you.
local function near_loc(name: string): Loc?
	local me = Player.position()
	if me == nil then
		return nil
	end
	local loc = Objects.nearest(name, me)
	if loc == nil or Objects.distance(loc, me) > Balloon.PILOT_RANGE then
		return nil
	end
	return loc
end

-- Opens the map with "Fly" on the pilot near you (or `npc`), else "Use" on the basket, walking closer first unless `walk` is false, and waits for it. True when it is open, also if it already was. When it didn't work the second result says why.
function Balloon.open(npc: Npc?, walk: boolean?): (boolean, string?)
	if Balloon.is_open() then
		return true, nil
	end
	if not Toplevel.escape_clear() then
		return false, "another interface is open"
	end
	local pilot = npc or Balloon.find_pilot()
	local picked: boolean
	if pilot ~= nil then
		if walk ~= false then
			picked = Npcs.approach(pilot, Balloon.OPTION)
		else
			picked = Npcs.interact(pilot, Balloon.OPTION)
		end
	else
		local basket = near_loc(Balloon.BASKET)
		if basket == nil then
			return false, "no balloon nearby"
		end
		picked = Objects.approach(basket, Balloon.BASKET_OPTION)
	end
	if not picked then
		return false, "couldn't open the map"
	end
	if not Balloon.wait_open() then
		return false, "the map didn't open"
	end
	Random.sleep(Balloon.OPEN_SETTLE_MS[1], Balloon.OPEN_SETTLE_MS[2])
	return true, nil
end

-- Reads the log storage near you with "Check", dismisses the message and returns the counts, by log name in lowercase. Nil when there is no storage nearby or nothing was said. This also clears what the run took to be out.
function Balloon.check(): { [string]: number }?
	local box = near_loc(Balloon.STORAGE)
	if box == nil then
		return nil
	end
	if not Objects.approach(box, Balloon.CHECK_OPTION) then
		return nil
	end
	local deadline = time() + Balloon.CHECK_TIMEOUT_MS
	while not ChatOptions.contains_continue() do
		if time() >= deadline then
			return nil
		end
		sleep(Balloon.POLL_MS)
	end
	if not ChatOptions.continue_chat() and ChatOptions.contains_continue() then
		ChatOptions.continue_chat(0)
	end
	table.clear(out_of)
	return Balloon.stored()
end

return Balloon
