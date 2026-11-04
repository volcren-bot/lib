--!strict
-- Transports the walker can use, from the data the loader sends (`Host.transports`). `choose` weighs walking against them and `travel` uses the best; see docs/main/transports.md.
local Host = require("@lib/host")
local sleep = Host.sleep
local time = Host.time
local Chartering = require("@lib/main/interfaces/mainscreen/chartering")
local GameState = require("@lib/main/game_state")
local Log = require("@lib/utils/log")
local Random = require("@lib/utils/math/random")

type Transport = Host.Transport
type Loc = Host.Loc
type Tile = { x: number, y: number, plane: number? }

local Transports = {}

-- Transports are used by the walker unless this is false (or a walk passes `transports = false`).
Transports.ENABLED = true
-- A transport has to save this many game ticks over walking.
Transports.MIN_SAVING_TICKS = 30
-- Walking at a run, with a detour, for the tiles apart.
Transports.WALK_TICKS_PER_TILE = 0.6
-- Ticks added to a spell's duration for the cast, and how long to wait to land.
Transports.CAST_SLACK_TICKS = 3
Transports.LAND_TIMEOUT_MS = 8000
-- A cast the data says takes longer than that (the home teleports): how long past its duration to wait, and how long it may take to start.
Transports.SLOW_CAST_SLACK_MS = 3000
Transports.SLOW_CAST_START_MS = 3000
-- A jump of this many tiles between two looks is a trip: walking can't do it.
Transports.LAND_DISTANCE = 6
-- How long after landing to wait for the scene to load.
Transports.SETTLE_TIMEOUT_MS = 10000
-- A transport that failed isn't chosen again for this long.
Transports.RETRY_AFTER_MS = 5 * 60 * 1000
-- A charter trip: ticks added for the trader's menu, and how long the boat may take to come.
Transports.CHARTER_SLACK_TICKS = 6
Transports.CHARTER_SAIL_TIMEOUT_MS = 15000
-- Leaving a boat: the gangplank's name, how long to try, and how near the dock counts as arrived.
Transports.GANGPLANK = "Gangplank"
Transports.CROSS_TIMEOUT_MS = 20000
Transports.ARRIVED_NEAR = 4
-- A gate: ticks added for the click, how long the step through may take, and how near the far tile counts.
Transports.LINK_SLACK_TICKS = 2
Transports.LINK_TIMEOUT_MS = 8000
Transports.LINK_ARRIVED_NEAR = 1
-- What a passage (a far hop of `transports.tsv`: a tunnel, a cart, a ladder to another part of the map) adds to the data's duration, in ticks.
Transports.PASSAGE_SLACK_TICKS = 3
-- A lever: ticks added for the pull, how long the teleport may take, how near its destination counts, and how far from the row's tile the object may be.
Transports.LEVER_SLACK_TICKS = 3
Transports.LEVER_TIMEOUT_MS = 12000
Transports.LEVER_ARRIVED_NEAR = 2
Transports.LEVER_OBJECT_NEAR = 3
-- Whether a balloon may count on logs in storage, which can't be read before a flight. Off: a balloon is only used with its log in the inventory.
Transports.BALLOON_STORAGE = false
-- Whether a trip may go from safety into the Wilderness: off unless a script asks (this, or `options.wilderness` for one plan).
Transports.WILDERNESS = false
-- The `UNLOCK_*` items of the data: the varbit that says so (Karamja elite diary, the guard's permission), or `true` when the game shows none: paying the ghost captain, and the tablet on a Xeric's talisman.
Transports.UNLOCKS = {
	UNLOCK_KARAMJA_ELITE = { varbit = 4566, at_least = 1 },
	UNLOCK_MOR_UL_REK = { varbit = 5646, at_least = 1 },
	UNLOCK_DRAGONTOOTH = true,
	UNLOCK_XERICS_HONOUR = true,
} :: { [string]: { varbit: number, at_least: number } | boolean }
-- The item groups of the data that have to be worn to use a row: the walk puts them on from the inventory when it gets there, and leaves them on.
Transports.WORN_GROUPS = { "CROSSBOW", "MITH_GRAPPLE", "CLIMBING_BOOTS" }
Transports.WEAR_OPTIONS = { "Wield", "Wear", "Equip" }
Transports.WEAR_TIMEOUT_MS = 2500
-- What going from where you land in the house to the furniture adds, in ticks.
Transports.HOUSE_SLACK_TICKS = 12
-- A canoe trip: what chopping, shaping and floating add to the data's duration, in ticks.
Transports.CANOE_SLACK_TICKS = 20
-- Tries per transport, the pause between them.
Transports.ATTEMPTS = 3
Transports.RETRY_PAUSE_MS = 1500
-- A charter or boat retried from this close to its destination is taken to be aboard already.
Transports.ABOARD_NEAR = 15
-- A network of separate starts and ends (see `HUBS`): how long the trip may take to land.
Transports.HUB_TIMEOUT_MS = 20000
-- A ride (a boat, ferry, cart or magic carpet): ticks added to the data's duration, how long the dialogue and trip may take, and the pause between looks.
Transports.RIDE_SLACK_TICKS = 8
Transports.RIDE_TIMEOUT_MS = 45000
Transports.RIDE_POLL_MS = 200
-- How long after a conversation has ended without a trip before it counts as refused.
Transports.RIDE_QUIET_MS = 8000
-- How long a voyage that has begun may take to reach the destination.
Transports.RIDE_VOYAGE_MS = 40000
-- How far from the click the player has to be for a ride to have taken them: walking to the NPC is not that.
Transports.RIDE_LAND_DISTANCE = 25
-- The player's pose while riding a magic carpet, and how long a merchant a few tiles away may stay silent after the click.
Transports.CARPET_POSE = 6936
Transports.CARPET_SILENT_MS = 8000
-- Taken off a carpet ride's cost: a ride beats a walk of about the same length, which is longer than walking's straight line anyway.
Transports.CARPET_BONUS_TICKS = 15
-- How long after the click with nothing said and no trip before the click counts as having done nothing.
Transports.RIDE_SILENT_MS = 25000
-- Buying a cart ticket: how long it may take, how long after "Buy" the talk is over, and how long a quiet talk before it counts as gone nowhere.
Transports.TICKET_TIMEOUT_MS = 40000
Transports.TICKET_DONE_MS = 2500
Transports.TICKET_IDLE_MS = 8000
-- A pause (min, max in ms) after a boat lands: the gangplank doesn't take a click at once.
Transports.RIDE_DOCK_PAUSE_MS = { 2500, 4000 }
-- Finding a ride's NPC by asking: how far from the boarding tile, and how many of the nearest.
Transports.RIDE_NPC_RANGE = 12
Transports.RIDE_NPC_LOOKS = 8
-- Agility shortcuts are used by the walker unless this is false (or a walk passes `shortcuts = false`).
Transports.SHORTCUTS = true
-- A shortcut has to save this many tiles over walking round.
Transports.SHORTCUT_MIN_SAVING_TILES = 10
-- How long what the planner found out about the gated rows and grown trees is kept.
Transports.VALID_FOR_MS = 20 * 1000
-- Ticks added for a walk that changes plane.
Transports.PLANE_CHANGE_TICKS = 10
-- A goal that looks cut off but is at most this far is asked of the planner before a transport is taken.
Transports.CONFIRM_WALK_TILES = 64
-- The planner's `near` for that question.
Transports.CONFIRM_WALK_NEAR = 2
-- The item containers: the inventory and what is worn.
Transports.INVENTORY = 93
Transports.WORN = 94
-- How far from a dock or start tile the walk to it may stop.
Transports.DOCK_NEAR = 3
-- Teleport items are used unless this is false (or a plan excludes "items", or the item's name).
Transports.ITEMS = true
-- Ticks added to using an item, and to one that spends a charge, to keep it for a real saving.
Transports.ITEM_SLACK_TICKS = 3
Transports.ITEM_CHARGE_TICKS = 40
-- How long to wait to land after an item is clicked, and for its dialogue before taking the submenu.
Transports.ITEM_TIMEOUT_MS = 12000
Transports.ITEM_DIALOGUE_MS = 2500
-- The least often the destination is picked in the submenu; biometrics raise it up to always.
Transports.ITEM_SUBMENU_BASE = 0.7
-- The menu options that open an item's list of destinations, in the order tried.
Transports.ITEM_OPENERS = { "Rub", "Teleport", "Teleports", "Commune", "Break", "Operate" }
-- Options of an item that are never its teleport.
Transports.ITEM_NOT_TELEPORT = {
	"Wear",
	"Wield",
	"Use",
	"Drop",
	"Examine",
	"Check",
	"Check charges",
	"Check-charge",
	"Destroy",
	"Uncharge",
	"Toggle",
	"Remove",
	"Cancel",
	"Features",
	"Spellbook",
}
-- The underground (dungeons) is the same map 6,400 tiles north.
Transports.UNDERGROUND = 6400

export type Options = {
	-- names never to use: a spell's or item's as in the data ("Varrock Teleport"), a charter's or ride's label, a minigame's activity ("Castle Wars"), or a group: "spells", "minigames", "items", "charter", "ride", "gates", "levers", or a network's kind ("fairy_rings")
	exclude: { [string]: boolean }?,
	-- overrides `MIN_SAVING_TICKS`
	min_saving_ticks: number?,
	-- whether agility shortcuts join landmasses for the walk (default `Transports.SHORTCUTS`)
	shortcuts: boolean?,
	-- whether a trip may go from safety into the Wilderness (default `Transports.WILDERNESS`)
	wilderness: boolean?,
}

export type Choice = {
	-- "spell", "minigame", "item", "quetzal_whistle", "scroll_book", "charter", "link", "lever", "ride" or the kind of a network ("fairy_rings", ...)
	kind: string,
	transport: Transport,
	-- its name in the list of failures
	id: string?,
	-- a spell's name and its menu option (nil: the default one); an item's name and the destination to pick; empty for the rest
	spell: string,
	option: string?,
	-- ticks the whole way is expected to take, and ticks saved against walking
	ticks: number,
	saved: number,
}

local function lib(path: string): any
	return (require :: any)(path)
end

local function gap(a: Tile, b: Tile): number
	return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

-- A runner's way of saying what went wrong: logged, and false.
local function fail(id: string, why: string): boolean
	Log.log("Transports", `{id}: {why}`)
	return false
end

----------------------------------------------------------------------------------------------------
-- The data
----------------------------------------------------------------------------------------------------

-- `Host.transports` copies thousands of rows: read once, by kind.
local rows_by_kind: { [string]: { Transport } }? = nil
local item_ids: { [string]: { number } } = {}

local function rows_of(kind: string): { Transport }
	if rows_by_kind == nil then
		local data = Host.transports()
		if #data.transports == 0 then
			return {}
		end
		local grouped: { [string]: { Transport } } = {}
		for _, t in ipairs(data.transports) do
			local list = grouped[t.kind]
			if list == nil then
				list = {}
				grouped[t.kind] = list
			end
			table.insert(list, t)
		end
		for _, group in ipairs(data.items) do
			item_ids[string.upper(group.name)] = group.ids
		end
		rows_by_kind = grouped
		Log.log("Transports", `{#data.transports} rows (data: {data.source})`)
	end
	return (rows_by_kind :: { [string]: { Transport } })[kind] or {}
end

-- "Varrock Teleport: Grand Exchange" is the spell "Varrock Teleport" with the option "Grand Exchange", and "Teleport to House (Inside)" the option "Inside".
function Transports.split(name: string): (string, string?)
	local base, option = string.match(name, "^(.-): (.+)$")
	if base then
		return base, option
	end
	base, option = string.match(name, "^(.-) %((.-)%)$")
	if base then
		return base, option
	end
	return name, nil
end

-- The wilderness level of a tile, 0 outside it.
-- Whether a tile is in the Ferox Enclave: inside the Wilderness's bounds, but a safe zone with no fighting.
function Transports.in_ferox(x: number, y: number): boolean
	return x >= 3123 and x <= 3155 and y >= 3618 and y <= 3639
end

function Transports.wilderness_level(x: number, y: number): number
	if x >= 2944 and x < 3392 then
		if y >= 3523 and y < 3968 then
			return (y - 3520) // 8 + 1
		elseif y >= 9918 and y < 10368 then
			return (y - 9920) // 8 + 1
		end
	end
	return 0
end

----------------------------------------------------------------------------------------------------
-- Requirements
----------------------------------------------------------------------------------------------------

-- What one plan has read of the account: each read is an IPC round trip, and many rows test the same few.
type Check = {
	levels: { [string]: number }?,
	here_wild: number,
	into_wild: boolean,
	-- the goal is in the Ferox Enclave, so a trip may land in it
	goal_in_ferox: boolean?,
	vars: { [number]: number | boolean },
	quests: { [string]: boolean },
	castable: { [string]: boolean },
	held: { [number]: number }?,
	carpets_free: boolean?,
}

local function new_check(from: Tile?, into_wild: boolean?): Check
	return {
		levels = Transports.levels(),
		here_wild = if from then Transports.wilderness_level(from.x, from.y) else 0,
		into_wild = into_wild == true,
		vars = {},
		quests = {},
		castable = {},
		held = nil,
	}
end

-- Whether the varbit and varp tests of a row hold. They pick the row that applies (the spellbook, the diary, the house's place).
local function holds(t: Transport, c: Check): boolean
	for _, list in { t.varbits, t.varps } do
		local is_varp = list == t.varps
		for _, clause in ipairs(list) do
			local key = clause.id * 2 + (if is_varp then 1 else 0)
			local known = c.vars[key]
			if known == nil then
				known = (if is_varp then Host.varp(clause.id) else Host.varbit(clause.id)) or false
				c.vars[key] = known :: any
			end
			if known == false then
				return false
			end
			local value = known :: number
			-- "@" is a cooldown: the variable keeps the minute since the Unix epoch it started
			local ok = if clause.op == "="
				then value == clause.value
				elseif clause.op == ">" then value > clause.value
				elseif clause.op == "<" then value < clause.value
				elseif clause.op == "&" then bit32.band(value, clause.value) == clause.value
				elseif clause.op == "@" then Host.unix_time() / 60 - value >= clause.value
				else false
			if not ok then
				return false
			end
		end
	end
	return true
end

-- The player's levels by lowercase skill name, with `total` (the total level) and `combat` (the combat level), as the data's `Skills` column names them.
-- Skill levels are the current ones, boosts included, the way the game checks them; the total and combat levels use the real ones.
function Transports.levels(real_only: boolean?): { [string]: number }?
	local skills = Host.game_state().skills
	if skills == nil then
		return nil
	end
	local levels: { [string]: number } = {}
	local real: { [string]: number } = {}
	local total = 0
	for _, skill in ipairs(skills) do
		local name = string.lower(skill.name)
		levels[name] = if real_only then skill.real_level else skill.level
		real[name] = skill.real_level
		total += skill.real_level
	end
	levels.total = total
	local function r(name: string): number
		return real[name] or 1
	end
	-- combat level: a quarter of defence, hitpoints and half the prayer level, plus the best of the three styles
	local base = 0.25 * (r("defence") + r("hitpoints") + math.floor(r("prayer") / 2))
	local melee = 0.325 * (r("attack") + r("strength"))
	local ranged = 0.325 * math.floor(r("ranged") * 1.5)
	local magic = 0.325 * math.floor(r("magic") * 1.5)
	levels.combat = math.floor(base + math.max(melee, ranged, magic))
	return levels
end

local warned_skills: { [string]: boolean } = {}

-- Whether the skill levels a transport needs are met. `levels` is `Transports.levels()` unless given. A skill the data names that isn't known (not in `levels`) counts as not met.
function Transports.skills_met(t: Transport, levels: { [string]: number }?): boolean
	if #t.skills == 0 then
		return true
	end
	local have = levels or Transports.levels()
	if have == nil then
		return false
	end
	for _, need in ipairs(t.skills) do
		local name = string.lower(need.name)
		local level = have[name]
		if level == nil then
			if not warned_skills[name] then
				warned_skills[name] = true
				Log.log("Transports", `unknown skill "{need.name}" in the data: those transports are skipped`)
			end
			return false
		end
		if level < need.level then
			return false
		end
	end
	return true
end

-- The ids of a named item group (`COINS`), from the data's `item-variations.tsv`; a number names itself.
local function ids_of(name: string): { number }?
	local number = tonumber(name)
	if number ~= nil then
		return { number }
	end
	rows_of("")
	return item_ids[string.upper(name)]
end

local warned_items: { [string]: boolean } = {}

type ItemToken = { text: string, ids: { number }?, quantity: number }

-- One `Items` cell as any-of groups of all-of tokens. Kept: thousands of rows share a few hundred cells.
local parsed_items: { [string]: { { ItemToken } } } = {}

local function parse_items(cell: string): { { ItemToken } }
	local kept = parsed_items[cell]
	if kept ~= nil then
		return kept
	end
	local text = string.upper((string.gsub(cell, "%s", "")))
	text = string.gsub(string.gsub(text, "&&", "&"), "||", "|")
	local alternatives: { { ItemToken } } = {}
	for alternative in string.gmatch(text, "[^|]+") do
		local tokens: { ItemToken } = {}
		for token in string.gmatch(alternative, "[^&]+") do
			local name, quantity = string.match(token, "^([%w_]+)=(%d+)$")
			-- a slot, an unlock or an unknown group can't be counted
			local countable = name ~= nil and string.sub(name, 1, 7) ~= "UNLOCK_" and string.sub(name, -4) ~= "SLOT"
			table.insert(tokens, {
				text = token,
				ids = if countable then ids_of(name :: string) else nil,
				quantity = tonumber(quantity) or 0,
			})
		end
		table.insert(alternatives, tokens)
	end
	if rows_by_kind ~= nil then
		parsed_items[cell] = alternatives
	end
	return alternatives
end

-- The amounts of the items in the inventory and on the body, by item id.
local function held_counts(): { [number]: number }
	local counts: { [number]: number } = {}
	for _, container in { Transports.INVENTORY, Transports.WORN } do
		for _, item in ipairs(Host.item_container(container) or {}) do
			if item.id > 0 then
				counts[item.id] = (counts[item.id] or 0) + math.max(item.quantity, 1)
			end
		end
	end
	return counts
end

-- A comment above some rows that states a requirement: "Karamja (varbit:4566=0?COINS=200)" owes the items while the variable is at most the value.
type Note = { text: string, varp: boolean, id: number, value: number, items: string }

local notes: { [string]: Note | false } = {}
local warned_notes: { [string]: boolean } = {}

local function read_note(text: string): Note?
	local kept = notes[text]
	if kept ~= nil then
		return kept or nil
	end
	local kind, id, value, items = string.match(text, "(%a+):(%d+)=(%d+)%?([%w_=&|]+)")
	local note: Note? = nil
	if kind == "varbit" or kind == "varplayer" then
		note = {
			text = text,
			varp = kind == "varplayer",
			id = tonumber(id) :: number,
			value = tonumber(value) :: number,
			items = items :: string,
		}
	end
	notes[text] = note or false
	return note
end

local function note_passed(note: Note): boolean
	local now = if note.varp then Host.varp(note.id) else Host.varbit(note.id)
	return now ~= nil and now > note.value
end

local function warn_note(text: string)
	if text ~= "" and not warned_notes[text] then
		warned_notes[text] = true
		Log.log("Transports", `can't read what "{text}" asks: the ways under it are left out`)
	end
end

-- Whether an `UNLOCK_*` item is met: by its variable, or `true` when the game shows no variable, so it is taken as met until the trip is refused. Nil for one with neither, which isn't checked.
local function unlocked(token: ItemToken): boolean?
	local unlock = Transports.UNLOCKS[string.match(token.text, "^[%w_]+") or ""]
	if unlock == nil then
		return nil
	end
	if unlock == true then
		return true
	end
	local now = Host.varbit(unlock.varbit)
	return now ~= nil and now >= unlock.at_least
end

-- Whether the items a transport needs are held, in the inventory or worn (`counts`, else read now). `Items` is any-of groups (`|`) of all-of items (`&`).
function Transports.items_met(t: Transport, counts: { [number]: number }?): boolean
	if t.items == "" then
		return true
	end
	local note = if (t.note or "") ~= "" then read_note(t.note) else nil
	if note ~= nil and note.items == t.items and note_passed(note) then
		return true
	end
	local have = counts or held_counts()
	for _, tokens in ipairs(parse_items(t.items)) do
		local all = true
		for _, token in ipairs(tokens) do
			local ids = token.ids
			local unlock = if ids == nil then unlocked(token) else nil
			if unlock == false then
				all = false
				break
			elseif unlock == true then
				continue
			end
			if ids == nil then
				if not warned_items[token.text] then
					warned_items[token.text] = true
					Log.log("Transports", `can't check the item "{token.text}": transports that need it are skipped`)
				end
				all = false
				break
			end
			local count = 0
			for _, id in ipairs(ids) do
				count += have[id] or 0
			end
			if count < token.quantity then
				all = false
				break
			end
		end
		if all then
			return true
		end
	end
	return false
end

-- Whether the quests a transport needs are done (`known` remembers the answers of one plan).
function Transports.quests_done(t: Transport, known: { [string]: boolean }?): boolean
	if #t.quests == 0 then
		return true
	end
	local Journal = lib("@lib/main/interfaces/gametabs/journal")
	for _, name in ipairs(t.quests) do
		local done = known and known[name]
		if done == nil then
			done = Journal.is_quest_complete(name)
			if known then
				known[name] = done
			end
		end
		if not done then
			return false
		end
	end
	return true
end

-- Game ticks to walk between two tiles: the longer axis, a detour and running.
function Transports.walk_ticks(a: Tile, b: Tile): number
	return gap(a, b) * Transports.WALK_TICKS_PER_TILE
end

local function held(c: Check): { [number]: number }
	local counts = c.held
	if counts == nil then
		counts = held_counts()
		c.held = counts
	end
	return counts
end

-- The tests every row shares, cheapest first.
local function row_ok(t: Transport, c: Check): boolean
	return holds(t, c)
		and Transports.skills_met(t, c.levels)
		and Transports.quests_done(t, c.quests)
		and Transports.items_met(t, held(c))
end

local failed: { [string]: number } = {}

-- The axes held when a station last said there is none it can use: a held one can be too high a level. Nil when none has said so, or the axes held have changed since.
local no_canoe_axe: string? = nil

local function axes_held(have: { [number]: number }): string
	local ids: { string } = {}
	for _, id in ipairs(ids_of("AXE") or {}) do
		if (have[id] or 0) > 0 then
			table.insert(ids, tostring(id))
		end
	end
	return table.concat(ids, ",")
end

-- What a visit to the house showed isn't there, by furniture and by route id, for the rest of the run.
local house_missing: { [string]: boolean } = {}

local function is_house(tile: { x: number, y: number }): boolean
	return lib("@lib/main/house").is_tile(tile)
end

local function not_failed(id: string): boolean
	local at = failed[id]
	return at == nil or time() - at > Transports.RETRY_AFTER_MS
end

----------------------------------------------------------------------------------------------------
-- Rows the planner has to be told about, and that join landmasses
----------------------------------------------------------------------------------------------------

type Gated = { keys: { string }, across: { Transport }, by_ends: { [string]: { Transport } }, at: number }
local gated_rows: { [boolean]: Gated } = {}

-- The gated climbs, links and shortcuts the player can use now: their names for the planner, and the rows that are a way across (links and shortcuts).
-- The types of transport the user turned off in the loader, by name.
local function turned_off(): { [string]: boolean }
	local off: { [string]: boolean } = {}
	for _, name in ipairs(Host.transport_settings().off) do
		off[name] = true
	end
	return off
end

-- Whether the user has this type of transport on in the loader. See the docs for the names.
function Transports.is_enabled(name: string): boolean
	return not turned_off()[name]
end

-- Raises an error that stops the script when the user has this type of transport off, for a script that can't work without it.
function Transports.require_enabled(name: string)
	if not Transports.is_enabled(name) then
		error(`this script needs the transport type "{name}", which is turned off in the loader's Settings`)
	end
end

-- Whether what a comment above a row asks for is met; set below, with the gates that read it.
local note_ok: (t: Transport, c: Check) -> boolean

-- Whether a row needs something put on to be used.
local function needs_worn(t: Transport): boolean
	for _, group in ipairs(Transports.WORN_GROUPS) do
		if string.find(t.items, group, 1, true) ~= nil then
			return true
		end
	end
	return false
end

local function gated(shortcuts: boolean?): Gated
	local on = (if shortcuts ~= nil then shortcuts else Transports.SHORTCUTS) and not turned_off().shortcuts
	local kept = gated_rows[on]
	if kept ~= nil and time() - kept.at < Transports.VALID_FOR_MS then
		return kept
	end
	local c = new_check()
	local keys: { string } = {}
	local across: { Transport } = {}
	local by_ends: { [string]: { Transport } } = {}
	local function allow(t: Transport, is_across: boolean)
		local o, d = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
		local ends = `{o.x},{o.y},{o.plane}>{d.x},{d.y},{d.plane}`
		by_ends[ends] = by_ends[ends] or {}
		table.insert(by_ends[ends], t)
		if is_across then
			table.insert(across, t)
		end
	end
	for _, kind in { "climb_gated", "link_gated" } do
		for _, t in ipairs(rows_of(kind)) do
			if row_ok(t, c) and note_ok(t, c) then
				allow(t, true)
			end
		end
	end
	if on then
		-- on the real levels: a boost can run out on the way
		local real = new_check()
		real.levels = Transports.levels(true)
		real.vars, real.quests, real.held = c.vars, c.quests, c.held
		for _, t in ipairs(rows_of("shortcut_gated")) do
			local o, d = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
			if
				Transports.wilderness_level(o.x, o.y) == 0
				and Transports.wilderness_level(d.x, d.y) == 0
				and row_ok(t, real)
			then
				allow(t, true)
			end
		end
	end
	-- several rows can join the same two tiles, like a wall's Grapple and Climb: the planner gets one that needs nothing put on, if there is one
	for ends, rows in by_ends do
		local plain: { Transport } = {}
		for _, t in ipairs(rows) do
			if not needs_worn(t) then
				table.insert(plain, t)
			end
		end
		local used = if #plain > 0 then plain else rows
		by_ends[ends] = used
		for _, t in ipairs(used) do
			table.insert(keys, `{ends}|{t.menu}`)
		end
	end
	local made = { keys = keys, across = across, by_ends = by_ends, at = time() }
	gated_rows[on] = made
	return made
end

-- The climbs and shortcuts that ask for something and that the player can use, as the planner names them ("x,y,plane>x,y,plane"), for `allow_climbs` of `Host.nav_plan`.
function Transports.allowed_climbs(options: { shortcuts: boolean? }?): { string }
	return gated(options and options.shortcuts).keys
end

----------------------------------------------------------------------------------------------------
-- Landmasses
----------------------------------------------------------------------------------------------------

local function tile_key(x: number, y: number, plane: number): number
	return x * 65536 + y * 4 + plane
end

-- Kept: they only change with a game update. 0: unknown, so walking is allowed.
local landmass_of: { [number]: number } = {}

local function learn_landmasses(points: { Tile })
	local missing: { { x: number, y: number, plane: number } } = {}
	local keys: { number } = {}
	for _, p in ipairs(points) do
		local plane = p.plane or 0
		local key = tile_key(p.x, p.y, plane)
		if landmass_of[key] == nil then
			landmass_of[key] = 0
			table.insert(missing, { x = p.x, y = p.y, plane = plane })
			table.insert(keys, key)
		end
	end
	if #missing > 0 then
		local numbers = Host.landmasses(missing)
		if numbers ~= nil then
			for i, key in ipairs(keys) do
				landmass_of[key] = numbers[i]
			end
		end
	end
end

local function landmass(p: Tile): number
	return landmass_of[tile_key(p.x, p.y, p.plane or 0)] or 0
end

----------------------------------------------------------------------------------------------------
-- The ways of travelling
----------------------------------------------------------------------------------------------------

-- A transport read once from a data row. `group` and `name` are what `exclude` can rule it out by.
type Route = {
	kind: string,
	transport: Transport,
	id: string,
	group: string,
	name: string,
	slack: number,
	spell: string,
	option: string?,
	-- the name of the type the user can turn off, when it isn't `group`
	setting: string?,
}

type Family = {
	kinds: { string },
	build: (t: Transport) -> Route?,
	usable: (route: Route, c: Check) -> boolean,
	routes: { Route }?,
}

local function both_ends(t: Transport): boolean
	return t.origin ~= nil and t.destination ~= nil
end

local function ends_id(prefix: string, t: Transport): string
	local o, d = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	return `{prefix} {o.x},{o.y} {d.x},{d.y}`
end

-- The Wilderness rule: never from safety into it unless asked. Once in it, leaving and moving within it are fine, but not walking out to a start in safety that leads back in.
local function wild_allowed(o: Host.TransportTile?, to: Host.TransportTile, c: Check): boolean
	if c.into_wild then
		return true
	end
	-- going to Clan Wars or Last Man Standing: the Enclave is safe, and with the goal inside it no walk through the Wilderness follows
	if
		c.goal_in_ferox
		and Transports.in_ferox(to.x, to.y)
		and (o == nil or Transports.wilderness_level(o.x, o.y) == 0)
	then
		return true
	end
	local to_wild = Transports.wilderness_level(to.x, to.y) > 0
	local from_wild = o ~= nil and Transports.wilderness_level(o.x, o.y) > 0
	if c.here_wild == 0 then
		return not to_wild and not from_wild
	end
	return not to_wild or o == nil or from_wild
end

local function safe(t: Transport, c: Check): boolean
	return wild_allowed(t.origin, t.destination :: Host.TransportTile, c) and c.here_wild <= (t.wilderness or 20)
end

-- Whether a gate can be passed: `(varbit:217=7?ECTO_TOKEN=2)` in the comment above its row means free once the quest keeping its progress in that varbit is complete, else the items after the `?`.
local function gate_open(t: Transport, c: Check): boolean
	local note = read_note(t.note or "")
	if note == nil then
		warn_note(t.note or "")
		return (t.note or "") == "" and Transports.items_met(t, held(c))
	end
	return note_passed(note) or Transports.items_met({ items = note.items } :: any, held(c))
end

-- Whether any row under this comment asks for the comment's items itself. Then the comment only says when those rows stop paying, as with Karamja's carts, and the free rows beside them aren't bound.
local note_named: { [string]: boolean } = {}

local function some_row_names(note: Note): boolean
	local known = note_named[note.text]
	if known ~= nil then
		return known
	end
	local named = false
	for _, kind in { "climb_gated", "link_gated" } do
		for _, t in ipairs(rows_of(kind)) do
			if t.note == note.text and t.items == note.items then
				named = true
			end
		end
	end
	note_named[note.text] = named
	return named
end

-- Rows under a comment stating a requirement: those that name its items check them themselves (`items_met`), and when no row names them it binds them all.
note_ok = function(t: Transport, c: Check): boolean
	if (t.note or "") == "" then
		return true
	end
	local note = read_note(t.note)
	if note == nil then
		warn_note(t.note)
		return false
	end
	if note_passed(note) or some_row_names(note) then
		return true
	end
	return Transports.items_met({ items = note.items } :: any, held(c))
end

local FAMILIES: { Family } = {
	{
		kinds = { "teleportation_spells", "teleportation_spells_home" },
		build = function(t: Transport): Route?
			if t.origin ~= nil or t.destination == nil then
				return nil
			end
			local spell, option = Transports.split(t.name)
			return {
				kind = "spell",
				setting = if t.kind == "teleportation_spells_home" then "home_teleports" else nil,
				transport = t,
				id = t.name,
				group = "spells",
				name = spell,
				slack = Transports.CAST_SLACK_TICKS,
				spell = spell,
				option = option,
			}
		end,
		usable = function(route: Route, c: Check): boolean
			local t = route.transport
			if not safe(t, c) or not holds(t, c) or not Transports.skills_met(t, c.levels) then
				return false
			end
			-- the game's own check covers the runes, and is shared by the spell's rows
			local known = c.castable[route.spell]
			if known == nil then
				local Magic = lib("@lib/main/interfaces/gametabs/magic")
				local spell = Magic.spell(route.spell)
				known = spell ~= nil and Magic.can_cast(spell)
				c.castable[route.spell] = known
			end
			return known and Transports.quests_done(t, c.quests)
		end,
	},
	{
		kinds = { "teleportation_minigames" },
		build = function(t: Transport): Route?
			if t.origin ~= nil or t.destination == nil then
				return nil
			end
			-- "Rat Pits Minigame Teleport: 1. Ardougne": the activity, and which pit
			local spell, option = Transports.split(t.name)
			local name = string.gsub(spell, "%s*Minigame Teleport$", "")
			return {
				kind = "minigame",
				transport = t,
				id = t.name,
				group = "minigames",
				name = name,
				slack = Transports.CAST_SLACK_TICKS,
				spell = name,
				option = if option ~= nil then string.match(option, "^%d+%.%s*(.+)$") or option else nil,
			}
		end,
		usable = function(route: Route, c: Check): boolean
			local t = route.transport
			return safe(t, c) and row_ok(t, c)
		end,
	},
	{
		kinds = { "teleportation_items" },
		build = function(t: Transport): Route?
			if t.origin ~= nil or t.destination == nil then
				return nil
			end
			local item, label = Transports.split(t.name)
			if string.find(t.items, "%d+=%d+") == nil then
				return nil
			end
			return {
				-- the book's scrolls are chosen in its own interface
				kind = if item == "Master scroll book" then "scroll_book" else "item",
				setting = if item == "Master scroll book" then "scroll_book" else nil,
				transport = t,
				id = t.name,
				group = "items",
				name = item,
				slack = Transports.ITEM_SLACK_TICKS + (if t.consumable then Transports.ITEM_CHARGE_TICKS else 0),
				spell = item,
				option = label,
			}
		end,
		usable = function(route: Route, c: Check): boolean
			local t = route.transport
			return Transports.ITEMS and safe(t, c) and Transports.items_met(t, held(c)) and row_ok(t, c)
		end,
	},
	{
		kinds = { "quetzal_whistle" },
		build = function(t: Transport): Route?
			if t.origin ~= nil or t.destination == nil then
				return nil
			end
			local item, label = Transports.split(t.name)
			return {
				kind = "quetzal_whistle",
				setting = "quetzal_whistle",
				transport = t,
				-- one id for every site: an empty whistle fails them all
				id = item,
				group = "items",
				name = item,
				slack = Transports.ITEM_SLACK_TICKS + Transports.ITEM_CHARGE_TICKS,
				spell = item,
				option = label,
			}
		end,
		usable = function(route: Route, c: Check): boolean
			local t = route.transport
			return Transports.ITEMS and safe(t, c) and row_ok(t, c)
		end,
	},
	{
		kinds = { "charter_ships" },
		build = function(t: Transport): Route?
			local label = string.match(t.name, "^%w+:%s*(.+)$")
			if not both_ends(t) or label == nil then
				return nil
			end
			local o = t.origin :: Host.TransportTile
			return {
				kind = "charter",
				transport = t,
				id = `charter {o.x},{o.y} {label}`,
				group = "charter",
				name = label,
				slack = Transports.CHARTER_SLACK_TICKS,
				spell = "",
			}
		end,
		usable = function(route: Route, c: Check): boolean
			return safe(route.transport, c) and row_ok(route.transport, c)
		end,
	},
	{
		kinds = { "boats", "ships", "minecarts" },
		build = function(t: Transport): Route?
			if not both_ends(t) then
				return nil
			end
			return {
				kind = "ride",
				transport = t,
				id = `{ends_id("ride", t)} {t.menu}`,
				group = "ride",
				-- the destination's name when the data gives it, else the menu without its id
				name = if t.name ~= "" then t.name else (string.gsub(t.menu, "%s*%d+%s*$", "")),
				slack = Transports.RIDE_SLACK_TICKS,
				spell = "",
			}
		end,
		usable = function(route: Route, c: Check): boolean
			return safe(route.transport, c) and row_ok(route.transport, c)
		end,
	},
	{
		kinds = { "magic_carpets" },
		build = function(t: Transport): Route?
			if not both_ends(t) then
				return nil
			end
			return {
				kind = "ride",
				transport = t,
				id = `{ends_id("ride", t)} {t.menu}`,
				group = "ride",
				setting = "magic_carpets",
				name = t.name,
				slack = -Transports.CARPET_BONUS_TICKS,
				spell = "",
			}
		end,
		-- the Desert hard diary makes the rides free, so the fare in the data need not be held
		usable = function(route: Route, c: Check): boolean
			local t = route.transport
			if not safe(t, c) or not holds(t, c) or not Transports.quests_done(t, c.quests) then
				return false
			end
			if Transports.items_met(t, held(c)) then
				return true
			end
			if c.carpets_free == nil then
				c.carpets_free = lib("@lib/main/diaries").tier("desert", "hard") == true
			end
			return c.carpets_free == true
		end,
	},
	{
		kinds = { "teleportation_portals" },
		-- the free-for-all portal is a PvP arena
		build = function(t: Transport): Route?
			if not both_ends(t) or string.find(t.menu, "Free-for-all", 1, true) ~= nil then
				return nil
			end
			local home = string.sub(t.menu, 1, 5) == "Home "
			return {
				-- out of the house it's the portal inside, wherever that is
				kind = if home and is_house(t.origin :: Host.TransportTile) then "house_exit" else "ride",
				transport = t,
				id = `{ends_id("ride", t)} {t.menu}`,
				group = if home then "house" else "portals",
				name = t.name,
				slack = Transports.PASSAGE_SLACK_TICKS,
				spell = "",
			}
		end,
		usable = function(route: Route, c: Check): boolean
			return safe(route.transport, c) and row_ok(route.transport, c)
		end,
	},
	{
		kinds = { "teleportation_portals_poh", "teleportation_boxes" },
		build = function(t: Transport): Route?
			if not both_ends(t) or not is_house(t.origin :: Host.TransportTile) then
				return nil
			end
			local furniture: string? = nil
			if t.kind == "teleportation_portals_poh" then
				furniture = if string.sub(t.menu, 1, 13) ~= "Enter Respawn" then "nexus" else nil
			else
				for _, kind in { "box", "glory", "cape", "talisman", "digsite" } do
					local name = lib("@lib/main/house").FURNITURE[kind][1]
					if string.find(t.menu, name, 1, true) ~= nil then
						furniture = kind
					end
				end
			end
			-- the respawn portal isn't used yet, and the box's Corporeal Beast is a boss's room
			if furniture == nil or string.find(t.name, "Corporeal", 1, true) ~= nil then
				return nil
			end
			local label = string.gsub(string.gsub(t.name, "^%w+:%s*", ""), " Portal$", "")
			return {
				kind = "house",
				transport = t,
				id = `house {furniture} {label}`,
				group = "house",
				name = label,
				slack = Transports.HOUSE_SLACK_TICKS,
				spell = furniture,
				option = label,
			}
		end,
		-- what is built can only be seen from inside. Until a visit has shown it, the variables say what is likely for the Nexus and the box, and nothing says it for the rest
		usable = function(route: Route, c: Check): boolean
			local House = lib("@lib/main/house")
			local built = House.seen(route.spell)
			if built == nil then
				local varbit = if route.spell == "box"
					then House.BOX_VARBIT
					elseif route.spell == "nexus" then House.NEXUS_VARBIT
					else nil
				built = varbit ~= nil and (Host.varbit(varbit) or 0) ~= 0
			end
			return built == true
				and safe(route.transport, c)
				and row_ok(route.transport, c)
				and not house_missing[route.spell]
				and not house_missing[route.id]
		end,
	},
	{
		kinds = { "canoes" },
		build = function(t: Transport): Route?
			if not both_ends(t) then
				return nil
			end
			return {
				kind = "canoe",
				transport = t,
				id = ends_id("canoe", t),
				group = "canoes",
				name = t.name,
				slack = Transports.CANOE_SLACK_TICKS,
				spell = "",
			}
		end,
		-- the game doesn't show whether a station's NPC holds an axe: that is assumed, until a station says otherwise
		usable = function(route: Route, c: Check): boolean
			local t = route.transport
			if not safe(t, c) or not holds(t, c) or not Transports.skills_met(t, c.levels) then
				return false
			end
			if no_canoe_axe ~= nil and axes_held(held(c)) ~= no_canoe_axe then
				no_canoe_axe = nil
			end
			return no_canoe_axe == nil
		end,
	},
	{
		kinds = { "transports", "agility_shortcuts" },
		build = function(t: Transport): Route?
			if not both_ends(t) then
				return nil
			end
			if string.match(t.menu, "^Use .- %-> ") ~= nil then
				return {
					kind = "item_on",
					transport = t,
					id = `{ends_id("item_on", t)} {t.menu}`,
					group = "passages",
					setting = if t.kind == "agility_shortcuts" then "shortcuts" else nil,
					name = t.name,
					slack = Transports.PASSAGE_SLACK_TICKS,
					spell = "",
				}
			end
			if string.sub(t.menu, 1, 8) ~= "Pay-toll" then
				-- too far for the planner: a tunnel, a cart, a ladder to another part of the map
				return {
					kind = "ride",
					transport = t,
					id = `{ends_id("ride", t)} {t.menu}`,
					group = "passages",
					name = t.name,
					slack = Transports.PASSAGE_SLACK_TICKS,
					spell = "",
				}
			end
			return {
				kind = "link",
				transport = t,
				id = ends_id("link", t),
				group = "gates",
				name = "gates",
				slack = Transports.LINK_SLACK_TICKS,
				spell = "",
			}
		end,
		usable = function(route: Route, c: Check): boolean
			local t = route.transport
			if route.kind == "item_on" then
				-- the item is in the menu, and not always in the row's items
				local item = string.match(t.menu, "^Use (.-) %-> ") or ""
				local ids = ids_of(item)
				if ids == nil then
					return false
				end
				local have = 0
				for _, id in ipairs(ids) do
					have += held(c)[id] or 0
				end
				return have > 0 and safe(t, c) and row_ok(t, c) and note_ok(t, c)
			end
			if route.kind == "ride" then
				return safe(t, c) and row_ok(t, c) and note_ok(t, c)
			end
			return Transports.skills_met(t, c.levels) and Transports.quests_done(t, c.quests) and gate_open(t, c)
		end,
	},
	{
		kinds = { "teleportation_levers" },
		build = function(t: Transport): Route?
			if not both_ends(t) then
				return nil
			end
			return {
				kind = "lever",
				transport = t,
				id = ends_id("lever", t),
				group = "levers",
				name = "levers",
				slack = Transports.LEVER_SLACK_TICKS,
				spell = "",
			}
		end,
		usable = function(route: Route, c: Check): boolean
			local t = route.transport
			-- the wilderness levers have no level cap: they have to be pullable from there
			return wild_allowed(t.origin, t.destination :: Host.TransportTile, c) and row_ok(t, c)
		end,
	},
}

local function routes_of(family: Family): { Route }
	if family.routes then
		return family.routes
	end
	local found: { Route } = {}
	for _, kind in ipairs(family.kinds) do
		for _, t in ipairs(rows_of(kind)) do
			local route = family.build(t)
			if route then
				table.insert(found, route)
			end
		end
	end
	if #found > 0 then
		family.routes = found
	end
	return found
end

-- A network whose data lists the starts and the ends apart: every start goes to every end not within `radius` of it. Paired while planning: the fairy rings alone would be 3,000 trips.
type Hub = {
	kind: string,
	module: string,
	radius: number,
	-- ticks added to the data's duration for opening the interface and choosing
	slack: number,
	-- the destination's name for the interface, from the end's `Display info` (nil: not a destination to pick)
	label: (name: string) -> string?,
	-- a start that is an object whose current form must offer the click (a spirit tree in a farming patch)
	object_start: boolean?,
	-- whether the network can be used at all now, and why not
	gate: (() -> (boolean, string?))?,
	-- whether a destination can be gone to now, beyond what its row asks (a balloon's log, which may be in storage)
	end_usable: ((m: any, label: string) -> boolean)?,
	-- the kind of `House.FURNITURE` that makes the house a stop of this network; a network without it leaves the house out
	furniture: string?,
	-- chooses the destination in the interface: false and why when it didn't work, and true third when trying again is pointless. `at` is the object to use when it isn't standing beside the player (a house's)
	go: (m: any, label: string, at: Loc?) -> (boolean, string?, boolean?),
}

-- Whether to take the quicker of two ways to the same place (a minimenu's submenu over a dialogue, "Last-destination" over a map): most of the time, how often depends on the account's biometrics.
local function prefers_quick(): boolean
	local Biometrics = lib("@lib/main/antiban/biometrics")
	local p = Transports.ITEM_SUBMENU_BASE
		+ (1 - Transports.ITEM_SUBMENU_BASE) * Biometrics.get_probability(Biometrics.CHOOSEOPTION)
	return Random.chance(p)
end

local function numbered_name(name: string): string?
	local label = string.match(name, "^%d+:%s*(.+)$") or string.match(name, "^%a:%s*(.+)$") or name
	return if label ~= "" then label else nil
end

-- An interface that lists destinations: open it and select by name.
local function pick_from_list(m: any, label: string): (boolean, string?)
	if not m.open(nil, false) then
		return false, "the list didn't open"
	end
	if m.select(label) == nil then
		m.close()
		return false, `{label} isn't in the list`
	end
	return true, nil
end

local HUBS: { Hub } = {
	{
		kind = "quetzals",
		module = "@lib/main/interfaces/mainscreen/quetzal",
		radius = 5,
		slack = 8,
		label = numbered_name,
		go = function(m: any, label: string): (boolean, string?)
			if m.is_last(label) and prefers_quick() then
				return m.fly_last(nil, false), "couldn't take Last-destination"
			end
			if not m.open(nil, false) then
				return false, "the map didn't open"
			end
			if not m.select(label) then
				m.close()
				return false, `{label} isn't on the map`
			end
			return true, nil
		end,
	},
	{
		kind = "spirit_trees",
		module = "@lib/main/interfaces/mainscreen/spirittree",
		object_start = true,
		furniture = "spirit_tree",
		radius = 5,
		slack = 8,
		label = numbered_name,
		go = function(m: any, label: string, at: Loc?): (boolean, string?)
			if not m.open(at, at ~= nil) then
				return false, "the list didn't open"
			end
			local place = m.find(label)
			-- a place that isn't unlocked is drawn grey, and still offers to continue: the list is the only place to tell
			if place == nil or not place.available then
				m.close()
				return false, `{label} isn't unlocked`
			end
			if m.select(label) == nil then
				m.close()
				return false, `{label} couldn't be chosen`
			end
			return true, nil
		end,
	},
	{
		kind = "minecarts",
		module = "@lib/main/interfaces/mainscreen/minecart",
		radius = 5,
		slack = 8,
		label = numbered_name,
		go = pick_from_list,
	},
	{
		kind = "wilderness_obelisks",
		module = "@lib/main/interfaces/mainscreen/obelisk",
		radius = 6,
		slack = 12,
		label = numbered_name,
		-- without the diary the landing is random
		gate = function(): (boolean, string?)
			local ok = lib("@lib/main/diaries").tier("wilderness", "hard") == true
			return ok, if ok then nil else "the obelisks need the Wilderness hard diary to set a destination"
		end,
		go = function(m: any, label: string): (boolean, string?)
			if not m.open() then
				return false, "the list didn't open"
			end
			if not m.select(label) then
				m.close()
				return false, `{label} couldn't be chosen`
			end
			if not m.teleport() then
				return false, "couldn't start the teleport from the grid"
			end
			return true, nil
		end,
	},
	{
		kind = "magic_mushtrees",
		module = "@lib/main/interfaces/mainscreen/mushtree",
		radius = 5,
		slack = 4,
		-- "3. Sticky Swamp"
		label = function(name: string): string?
			return string.match(name, "^%d+%.%s*(.+)$")
		end,
		-- the data names no quest for them
		gate = function(): (boolean, string?)
			local ok = lib("@lib/main/interfaces/gametabs/journal").is_quest_complete("Bone Voyage")
			return ok, if ok then nil else "the mushtrees need Bone Voyage"
		end,
		go = pick_from_list,
	},
	{
		kind = "hot_air_balloons",
		module = "@lib/main/interfaces/mainscreen/balloon",
		radius = 7,
		slack = 6,
		label = numbered_name,
		end_usable = function(m: any, label: string): boolean
			return if Transports.BALLOON_STORAGE then m.has_log(label) else m.holds_log(label)
		end,
		go = function(m: any, label: string): (boolean, string?, boolean?)
			local opened, why = m.open(nil, false)
			if not opened then
				return false, why or "the map didn't open"
			end
			local flown, not_flown = m.select(label)
			if not flown then
				m.close()
				return false, not_flown, true
			end
			return true, nil
		end,
	},
	{
		kind = "gnome_gliders",
		module = "@lib/main/interfaces/mainscreen/gnomeglider",
		radius = 6,
		slack = 8,
		label = numbered_name,
		go = function(m: any, label: string): (boolean, string?)
			local opened, why = m.open(nil, false)
			if not opened then
				return false, why or "the map didn't open"
			end
			if not m.select(label) then
				m.close()
				return false, `{label} isn't on the map`
			end
			return true, nil
		end,
	},
	{
		kind = "fairy_rings",
		module = "@lib/main/interfaces/mainscreen/fairyring",
		furniture = "fairy_ring",
		radius = 6,
		slack = 12,
		-- "A I Q" is the code AIQ, "ZANARIS" the ring's own option; a chain of several codes isn't one trip
		label = function(name: string): string?
			if string.match(name, "^%u %u %u$") ~= nil then
				return (string.gsub(name, " ", ""))
			end
			return if name == "ZANARIS" then "zanaris" else nil
		end,
		gate = function(): (boolean, string?)
			return lib("@lib/main/interfaces/mainscreen/fairyring").can_use()
		end,
		-- travel raises when the rings can't be used, and returns the way it went or nil when nothing happened
		go = function(m: any, label: string, at: Loc?): (boolean, string?)
			local ok, way = pcall(m.travel, label, nil, at)
			if not ok then
				return false, tostring(way)
			end
			return way ~= nil, if way == nil then "nothing happened" else nil
		end,
	},
}

local HUB_BY_KIND: { [string]: Hub } = {}
for _, h in ipairs(HUBS) do
	HUB_BY_KIND[h.kind] = h
end

type HubStart = {
	rep: Host.TransportTile,
	menu: string,
	-- every row of the structure: the same start can be listed with different requirements
	members: { Transport },
	option: string,
}
type HubEnd = { tile: Host.TransportTile, label: string, name: string, duration: number, row: Transport }
type HubData = { starts: { HubStart }, ends: { HubEnd } }

local hub_data: { [string]: HubData } = {}

-- The starts of a network, one per structure (rows within 4 tiles with the same click), and its ends. The player's house is an instance, not where the data puts it: only a network with `furniture` keeps it.
local function load_hub(h: Hub): HubData
	local kept = hub_data[h.kind]
	if kept ~= nil then
		return kept
	end
	local house: { [number]: boolean } = {}
	for _, kind in { "teleportation_spells", "teleportation_items" } do
		for _, t in ipairs(rows_of(kind)) do
			local d = t.destination
			if d ~= nil and string.sub(t.name, 1, 17) == "Teleport to House" then
				house[tile_key(d.x, d.y, d.plane)] = true
			end
		end
	end
	local function in_house(tile: Host.TransportTile): boolean
		return h.furniture == nil and house[tile_key(tile.x, tile.y, tile.plane)] == true
	end
	local rows: { Transport } = {}
	local ends: { HubEnd } = {}
	for _, t in ipairs(rows_of(h.kind)) do
		if t.origin ~= nil and t.destination == nil then
			if not in_house(t.origin) then
				table.insert(rows, t)
			end
		elseif t.origin == nil and t.destination ~= nil and not in_house(t.destination) then
			local label = h.label(t.name)
			if label ~= nil then
				table.insert(
					ends,
					{ tile = t.destination, label = label, name = t.name, duration = t.duration, row = t }
				)
			end
		end
	end
	local group: { number } = {}
	for i = 1, #rows do
		group[i] = i
	end
	local function root_of(i: number): number
		while group[i] ~= i do
			group[i] = group[group[i]]
			i = group[i]
		end
		return i
	end
	for i = 1, #rows do
		for j = i + 1, #rows do
			local a, b = rows[i].origin :: Host.TransportTile, rows[j].origin :: Host.TransportTile
			if rows[i].menu == rows[j].menu and a.plane == b.plane and gap(a, b) <= 4 then
				group[root_of(j)] = root_of(i)
			end
		end
	end
	local members: { [number]: { Transport } } = {}
	for i = 1, #rows do
		local root = root_of(i)
		members[root] = members[root] or {}
		table.insert(members[root], rows[i])
	end
	local starts: { HubStart } = {}
	for root, list in pairs(members) do
		local row = rows[root]
		table.insert(starts, {
			rep = row.origin :: Host.TransportTile,
			menu = row.menu,
			members = list,
			-- "Travel Spirit Tree 8355": the option, the object's name, its id
			option = string.match(row.menu, "^(%S+)") or "",
		})
	end
	local made = { starts = starts, ends = ends }
	hub_data[h.kind] = made
	return made
end

local function hub_id(kind: string, rep: Host.TransportTile, label: string): string
	return `{kind} {rep.x},{rep.y} {label}`
end

-- What is placed around a start never changes in a session; what it looks like does (a patch that grows).
local placed_ids: { [HubStart]: { number } } = {}
local grown_now: { [HubStart]: { offers: boolean?, at: number } } = {}

-- Whether the object placed beside a spirit tree start offers its click in the form it has now, or nil when that can't be told. The data's id is the grown form, so the placed objects are asked.
local function offers_now(start: HubStart): boolean?
	local kept = grown_now[start]
	if kept ~= nil and time() - kept.at < Transports.VALID_FOR_MS then
		return kept.offers
	end
	local rep = start.rep
	local ids = placed_ids[start]
	if ids == nil then
		local placed = Host.cache_locs(
			{ x1 = rep.x - 5, y1 = rep.y - 5, x2 = rep.x + 5, y2 = rep.y + 5 },
			{ plane = rep.plane }
		)
		if placed ~= nil then
			local list: { number } = {}
			local seen: { [number]: boolean } = {}
			for _, loc in ipairs(placed) do
				if not seen[loc.id] then
					seen[loc.id] = true
					table.insert(list, loc.id)
				end
			end
			ids = list
			placed_ids[start] = list
		end
	end
	local views = if ids ~= nil then Host.loc_shown(ids) else nil
	local offers: boolean? = nil
	if views ~= nil then
		offers = false
		local wanted = string.lower(start.option)
		for _, view in ipairs(views) do
			if string.find(string.lower(view.name), "spirit tree", 1, true) ~= nil then
				for _, action in ipairs(view.actions) do
					if string.lower(action) == wanted then
						offers = true
					end
				end
			end
		end
	end
	if offers ~= true and (kept == nil or kept.offers ~= offers) then
		Log.log(
			"Transports",
			`no spirit tree to use at {rep.x}, {rep.y} now ({if offers == nil then "can't tell" else "not grown"})`
		)
	end
	grown_now[start] = { offers = offers, at = time() }
	return offers
end

----------------------------------------------------------------------------------------------------
-- The route
----------------------------------------------------------------------------------------------------

type Node = { x: number, y: number, plane: number, folded_y: number, under: boolean, mass: number }

-- A way from one point to another: a route, or a trip of a network.
type Edge = {
	to: number,
	cost: number,
	route: Route?,
	hub: Hub?,
	start: HubStart?,
	finish: HubEnd?,
}

-- Whether a network can be used at all, kept for `VALID_FOR_MS`: its gate can read a lot (the fairy rings' diary).
local gate_results: { [string]: { ok: boolean, at: number } } = {}
local function gate_open_now(hub: Hub): boolean
	if hub.gate == nil then
		return true
	end
	local kept = gate_results[hub.kind]
	if kept ~= nil and time() - kept.at < Transports.VALID_FOR_MS then
		return kept.ok
	end
	local ok, why = (hub.gate :: () -> (boolean, string?))()
	if not ok and (kept == nil or kept.ok) then
		Log.log("Transports", `{hub.kind} can't be used: {why or "no reason given"}`)
	end
	gate_results[hub.kind] = { ok = ok, at = time() }
	return ok
end

-- Adds the trips of the networks the player can use now.
local function add_hub_edges(
	off: { [string]: boolean },
	opts: Options,
	c: Check,
	node: (p: Host.TransportTile) -> number,
	add: (from: number?, edge: Edge) -> ()
)
	local any_failed = next(failed) ~= nil
	local House = lib("@lib/main/house")
	for _, hub in ipairs(HUBS) do
		if (opts.exclude and opts.exclude[hub.kind]) or off[hub.kind] then
			continue
		end
		local data = load_hub(hub)
		if #data.starts == 0 then
			continue
		end
		if not gate_open_now(hub) then
			continue
		end
		local starts: { HubStart } = {}
		-- starts whose object hasn't grown: the data puts the end beside its start, so those ends are out too
		local blocked: { HubStart } = {}
		-- a house's stop only counts once a visit has shown it
		local in_house = hub.furniture ~= nil and House.seen(hub.furniture) == true
		for _, start in ipairs(data.starts) do
			if House.is_tile(start.rep) then
				if not in_house then
					continue
				end
			elseif hub.object_start and offers_now(start) == false then
				table.insert(blocked, start)
				continue
			end
			for _, t in ipairs(start.members) do
				if row_ok(t, c) then
					table.insert(starts, start)
					break
				end
			end
		end
		if #starts == 0 then
			continue
		end
		local ends: { HubEnd } = {}
		for _, finish in ipairs(data.ends) do
			local usable = holds(finish.row, c)
				and Transports.skills_met(finish.row, c.levels)
				and Transports.quests_done(finish.row, c.quests)
				and (hub.end_usable == nil or hub.end_usable(lib(hub.module), finish.label))
				and (in_house or not House.is_tile(finish.tile))
			if usable then
				for _, start in ipairs(blocked) do
					if start.rep.plane == finish.tile.plane and gap(start.rep, finish.tile) <= 8 then
						usable = false
						break
					end
				end
			end
			if usable then
				table.insert(ends, finish)
			end
		end
		for _, start in ipairs(starts) do
			local from = node(start.rep)
			local slack = hub.slack + (if House.is_tile(start.rep) then Transports.HOUSE_SLACK_TICKS else 0)
			for _, finish in ipairs(ends) do
				local same_place = finish.tile.plane == start.rep.plane and gap(finish.tile, start.rep) < hub.radius
				if
					not same_place
					and wild_allowed(start.rep, finish.tile, c)
					and (not any_failed or not_failed(hub_id(hub.kind, start.rep, finish.label)))
				then
					add(from, {
						to = node(finish.tile),
						cost = finish.duration + slack,
						hub = hub,
						start = start,
						finish = finish,
					})
				end
			end
		end
	end
end

-- Whether the planner can walk it after all: landmasses don't see every way through.
-- Whether the world map says the goal can be walked to, climbs and one-way doors included. Nothing can be said about an instance, which counts as yes.
local function foot_route(from: Tile, goal: Tile, opts: Options): boolean
	local a = { x = from.x, y = from.y, plane = from.plane or 0 }
	local b = { x = goal.x, y = goal.y, plane = goal.plane or from.plane or 0 }
	local route = Host.world_route(a, b, gated(opts.shortcuts).keys)
	return route == nil or route.reachable
end

local function planner_reaches(from: Tile, goal: Tile, opts: Options): boolean
	local plan = Host.nav_plan(
		{ x = from.x, y = from.y, plane = from.plane or 0 },
		{ x = goal.x, y = goal.y, plane = goal.plane or from.plane or 0 },
		{
			near = Transports.CONFIRM_WALK_NEAR,
			allow_climbs = gated(opts.shortcuts).keys,
			shortcut_saving = Transports.SHORTCUT_MIN_SAVING_TILES,
		}
	)
	return plan ~= nil and plan.reached == true
end

-- Whether `goal` can be walked to from `from`, climbing as needed. When it can't be known (an instance, say) the answer is yes. The collision comes from the cache, so a close goal that looks cut off is also asked of the planner.
function Transports.walkable(from: Tile, goal: Tile, options: Options?): boolean
	local opts = options or {}
	if foot_route(from, goal, opts) then
		return true
	end
	return gap(from, goal) <= Transports.CONFIRM_WALK_TILES and planner_reaches(from, goal, opts)
end

-- The first transport on the best way from `from` to `goal`, or nil to walk. A shortest path over the start, the goal and every usable transport's ends: see the docs.
function Transports.choose(from: Tile, goal: Tile, options: Options?): Choice?
	local opts = options or {}
	-- inside the house you are where the data's rows start, except for a goal inside it too
	local House = lib("@lib/main/house")
	if House.inside() then
		House.survey()
		if gap(from, goal) <= House.SIZE then
			return nil
		end
		from = House.TILE
	end
	local plane = goal.plane or from.plane or 0
	local into_wild = if opts.wilderness ~= nil then opts.wilderness else Transports.WILDERNESS
	local check = new_check(from, into_wild)
	check.goal_in_ferox = Transports.in_ferox(goal.x, goal.y)
	local off = turned_off()

	local nodes: { Node } = {}
	local at: { [number]: number } = {}
	local function node(p: Host.TransportTile): number
		local key = tile_key(p.x, p.y, p.plane)
		local n = at[key]
		if n == nil then
			n = #nodes + 1
			nodes[n] = { x = p.x, y = p.y, plane = p.plane, folded_y = p.y, under = false, mass = 0 }
			at[key] = n
		end
		return n
	end
	-- the start and the goal are 1 and 2, even when they share a tile
	nodes[1] = { x = from.x, y = from.y, plane = from.plane or plane, folded_y = from.y, under = false, mass = 0 }
	nodes[2] = { x = goal.x, y = goal.y, plane = plane, folded_y = goal.y, under = false, mass = 0 }

	-- edges by the node they leave from; one that leaves from anywhere is cheapest from the start
	local out: { [number]: { Edge } } = { [1] = {} }
	local function add(from_node: number?, edge: Edge)
		local list = out[from_node or 1]
		if list == nil then
			list = {}
			out[from_node or 1] = list
		end
		table.insert(list, edge)
	end
	for _, family in ipairs(FAMILIES) do
		for _, route in ipairs(routes_of(family)) do
			local excluded = opts.exclude and (opts.exclude[route.group] or opts.exclude[route.name])
			if
				not excluded
				and not off[route.setting or route.group]
				and not_failed(route.id)
				and family.usable(route, check)
			then
				local t = route.transport
				add(if t.origin ~= nil then node(t.origin) else nil, {
					to = node(t.destination :: Host.TransportTile),
					cost = t.duration + route.slack,
					route = route,
				})
			end
		end
	end
	add_hub_edges(off, opts, check, node, add)

	-- the landmass of each node, with those joined by a way across the player can use
	local ways = gated(opts.shortcuts).across
	local points: { Tile } = table.clone(nodes) :: any
	for _, t in ipairs(ways) do
		table.insert(points, t.origin :: Tile)
		table.insert(points, t.destination :: Tile)
	end
	learn_landmasses(points)
	local merged: { [number]: number } = {}
	local function root_of(mass: number): number
		while merged[mass] ~= nil do
			mass = merged[mass]
		end
		return mass
	end
	for _, t in ipairs(ways) do
		local a, b = landmass(t.origin :: Tile), landmass(t.destination :: Tile)
		if a ~= 0 and b ~= 0 and root_of(a) ~= root_of(b) then
			merged[root_of(a)] = root_of(b)
		end
	end
	for _, n in ipairs(nodes) do
		n.under = n.y >= Transports.UNDERGROUND
		n.folded_y = if n.under then n.y - Transports.UNDERGROUND else n.y
		n.mass = root_of(landmass(n))
	end
	local per_tile = Transports.WALK_TICKS_PER_TILE
	local climb = Transports.PLANE_CHANGE_TICKS
	-- landmasses join both ways, and a door that only asks on the way in doesn't join them: the way out is still a walk
	local origin, target = nodes[1], nodes[2]
	local on_foot = origin.mass ~= 0
		and target.mass ~= 0
		and origin.mass ~= target.mass
		and foot_route(from, goal, opts)
	local function walk_cost(a: Node, b: Node): number
		-- the data's tile for the house is nowhere you can walk to or from
		if (a.x == House.TILE.x and a.y == House.TILE.y) ~= (b.x == House.TILE.x and b.y == House.TILE.y) then
			return math.huge
		end
		if a.mass ~= 0 and b.mass ~= 0 and a.mass ~= b.mass and not (on_foot and a == origin and b == target) then
			return math.huge
		end
		local ticks = math.max(math.abs(a.x - b.x), math.abs(a.folded_y - b.folded_y)) * per_tile
		return if a.under ~= b.under or a.plane ~= b.plane then ticks + climb else ticks
	end

	-- Dijkstra, every node joined to every other by walking
	local count = #nodes
	local dist: { number } = table.create(count, math.huge)
	local back: { number } = table.create(count, 0)
	local via: { Edge | false } = table.create(count, false)
	local done: { boolean } = table.create(count, false)
	dist[1] = 0
	for _ = 1, count do
		local u, best = 0, math.huge
		for i = 1, count do
			if not done[i] and dist[i] < best then
				u, best = i, dist[i]
			end
		end
		if u == 0 then
			break
		end
		done[u] = true
		local a = nodes[u]
		for v = 1, count do
			if not done[v] then
				local cost = best + walk_cost(a, nodes[v])
				if cost < dist[v] then
					dist[v], back[v], via[v] = cost, u, false
				end
			end
		end
		for _, edge in ipairs(out[u] or {}) do
			local cost = best + edge.cost
			if cost < dist[edge.to] then
				dist[edge.to], back[edge.to], via[edge.to] = cost, u, edge
			end
		end
	end

	if dist[2] == math.huge then
		return nil
	end
	-- the way back from the goal: the first transport on it is what to use now
	local first: Edge? = nil
	local rides_carpet = false
	local v = 2
	while v ~= 1 do
		local edge = via[v]
		if edge then
			first = edge
			if edge.route ~= nil and edge.route.transport.kind == "magic_carpets" then
				rides_carpet = true
			end
		end
		v = back[v]
	end
	if first == nil then
		return nil
	end
	-- carpets are preferred over walking: a way with one has only to be no slower
	local needed = opts.min_saving_ticks or (if rides_carpet then 0 else Transports.MIN_SAVING_TICKS)
	local direct = walk_cost(nodes[1], nodes[2])
	if direct ~= math.huge and direct - dist[2] < needed then
		return nil
	end
	if
		direct == math.huge
		and gap(from, goal) <= Transports.CONFIRM_WALK_TILES
		and planner_reaches(from, goal, opts)
	then
		return nil
	end
	local saved = if direct == math.huge then 1e9 else direct - dist[2]
	local route = first.route
	if route ~= nil then
		return {
			kind = route.kind,
			transport = route.transport,
			id = route.id,
			spell = route.spell,
			option = route.option,
			ticks = dist[2],
			saved = saved,
		}
	end
	-- a trip of a network: a transport made of its start and its end
	local start, finish, hub = first.start :: HubStart, first.finish :: HubEnd, first.hub :: Hub
	local trip = {
		kind = hub.kind,
		origin = start.rep,
		destination = finish.tile,
		name = finish.name,
		label = finish.label,
		menu = start.menu,
		duration = finish.duration,
	}
	return {
		kind = hub.kind,
		transport = trip :: any,
		id = hub_id(hub.kind, start.rep, finish.label),
		spell = "",
		option = nil,
		ticks = dist[2],
		saved = saved,
	}
end

----------------------------------------------------------------------------------------------------
-- Carrying a choice out
----------------------------------------------------------------------------------------------------

-- Waits for the new scene to load after a trip.
function Transports.settle()
	local deadline = time() + Transports.SETTLE_TIMEOUT_MS
	while time() < deadline do
		if Host.game_state().game_state == GameState.LOGGED_IN then
			return
		end
		sleep(200)
	end
end

-- Walks to a tile unless we are near it already, looking for no transport on the way.
local function walk_near(tile: Host.TransportTile, near: number): boolean
	local here = lib("@lib/main/player").position()
	if here ~= nil and here.plane == tile.plane and gap(here, tile) <= near then
		return true
	end
	return lib("@lib/main/walker").walk(tile, { near = near, transports = false, plane = tile.plane })
end

-- Waits for a trip that was just started to land: a jump walking can't make, a change of plane, or standing at the destination. False at the timeout.
local function wait_to_land(name: string, to: Host.TransportTile, timeout_ms: number): boolean
	-- into the house it lands outside for a moment first, and the jump alone says nothing
	if is_house(to) then
		local House = lib("@lib/main/house")
		local deadline = time() + timeout_ms
		while not House.inside() do
			if time() >= deadline then
				return false
			end
			sleep(100)
		end
		Transports.settle()
		return true
	end
	local Player = lib("@lib/main/player")
	local last = Player.position()
	local deadline = time() + timeout_ms
	while time() < deadline do
		local now = Player.position()
		if now ~= nil then
			last = last or now
			local arrived = now.plane == to.plane and gap(now, to) <= Transports.ARRIVED_NEAR
			if arrived or now.plane ~= last.plane or gap(now, last) >= Transports.LAND_DISTANCE then
				if gap(now, to) > 10 then
					Log.log("Transports", `{name} landed at {now.x}, {now.y}, not near {to.x}, {to.y}`)
				end
				Transports.settle()
				return true
			end
			last = now
		end
		sleep(100)
	end
	return false
end

-- Waits to stand within `near` of a tile on its plane.
local function wait_near(to: Host.TransportTile, near: number, timeout_ms: number): boolean
	local Player = lib("@lib/main/player")
	local deadline = time() + timeout_ms
	while time() < deadline do
		local now = Player.position()
		if now ~= nil and now.plane == to.plane and gap(now, to) <= near then
			return true
		end
		sleep(150)
	end
	return false
end

-- Casts the chosen teleport and waits to land.
-- Waits for a cast that was just clicked to land. The second result is true when a slow one never started.
local function wait_for_cast(t: Transport): (boolean, boolean?)
	local Player = lib("@lib/main/player")
	local timeout = Transports.LAND_TIMEOUT_MS
	local takes = (t.duration or 0) * 600 + Transports.SLOW_CAST_SLACK_MS
	if takes > timeout then
		timeout = takes
		-- the game refuses such a cast with a message (in combat, say): don't wait out the whole of it
		local deadline = time() + Transports.SLOW_CAST_START_MS
		while not Player.is_animating() do
			if time() >= deadline then
				fail(t.name, "the cast didn't start")
				return false, true
			end
			sleep(50)
		end
	end
	if wait_to_land(t.name, t.destination :: Host.TransportTile, timeout) then
		return true
	end
	return fail(t.name, "didn't work")
end

function Transports.cast(choice: Choice): (boolean, boolean?)
	local Magic = lib("@lib/main/interfaces/gametabs/magic")
	local t = choice.transport
	Log.log("Transports", `casting {t.name}: saves about {math.floor(choice.saved)} ticks`)
	-- not Magic.cast: its check that the spell was cast only knows the "Cast" option, and a teleport lands by itself
	local ok = (Magic.is_open() or Magic.open()) and Magic.interact(choice.spell, choice.option or "Cast")
	if not ok then
		return fail(t.name, "didn't work")
	end
	return wait_for_cast(t)
end

-- Takes a minigame teleport, by the spell's list or the Grouping view: `choice.spell` is the activity and `choice.option` the rat pit. The second result is true when the cast never started.
function Transports.minigame(choice: Choice): (boolean, boolean?)
	local t = choice.transport
	Log.log("Transports", `{t.name}: saves about {math.floor(choice.saved)} ticks`)
	local ok, why = lib("@lib/main/interfaces/mainscreen/minigames").teleport(choice.spell, choice.option)
	if not ok then
		return fail(t.name, why or "couldn't start it")
	end
	return wait_for_cast(t)
end

-- Gets off a boat: crosses the gangplank onto the dock at `to` and waits for the scene to settle.
function Transports.disembark(to: Tile): boolean
	local Player = lib("@lib/main/player")
	local Objects = lib("@lib/main/entities/objects")
	local plane = to.plane or 0
	local function arrived(): boolean
		local now = Player.position()
		return now ~= nil and now.plane == plane and gap(now, to) <= Transports.ARRIVED_NEAR
	end
	local crossing = time() + Transports.CROSS_TIMEOUT_MS
	while not arrived() and time() < crossing do
		local now = Player.position()
		local plank = if now then Objects.nearest(Transports.GANGPLANK, { x = now.x, y = now.y }) else nil
		if plank ~= nil and Objects.interact(plank, "Cross") then
			local waited = time() + 5000
			while not arrived() and time() < waited do
				sleep(150)
			end
		else
			sleep(300)
		end
	end
	if not arrived() then
		return false
	end
	Transports.settle()
	return true
end

-- Takes a trip of a network: walks to the start, has the interface choose the destination by its name, and waits to land.
function Transports.hub(choice: Choice): (boolean, boolean?)
	local t = choice.transport :: any
	local hub = HUB_BY_KIND[choice.kind]
	local from, to = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local label = t.label :: string
	local id = choice.id or hub_id(choice.kind, from, label)
	Log.log("Transports", `{choice.kind} to {label}: saves about {math.floor(choice.saved)} ticks`)
	local at: Loc? = nil
	if is_house(from) then
		local House = lib("@lib/main/house")
		if not House.inside() then
			return fail(id, "not in the house")
		end
		at = House.reach(House.FURNITURE[hub.furniture :: string])
		if at == nil then
			fail(id, "can't get to it in this house")
			return false, true
		end
	elseif not walk_near(from, Transports.DOCK_NEAR) then
		return fail(id, "couldn't walk to the start")
	end
	local ok, went, why, final = pcall(hub.go, lib(hub.module), label, at)
	if not ok then
		return fail(id, tostring(went))
	end
	if not went then
		fail(id, why or "didn't work")
		return false, final
	end
	if not wait_to_land(id, to, Transports.HUB_TIMEOUT_MS) then
		return fail(id, "the trip didn't happen")
	end
	return true
end

-- The option of a dialogue to pick for a ride: the one that names where it goes, else a yes. `hints` are lowercase pieces of the destination's name.
local AFFIRMATIVE = { "yes", "ok", "okay", "sure", "pay", "go", "travel", "take", "accept", "board" }

function Transports.dialogue_pick(options: { { text: string } }, hints: { string }): string?
	for _, option in ipairs(options) do
		local text = string.lower(option.text)
		for _, hint in ipairs(hints) do
			if #hint >= 4 and string.find(text, hint, 1, true) ~= nil then
				return option.text
			end
		end
	end
	for _, option in ipairs(options) do
		local text = string.lower(option.text)
		for _, word in ipairs(AFFIRMATIVE) do
			if string.sub(text, 1, #word) == word then
				return option.text
			end
		end
	end
	return nil
end

-- Buys the ticket a cart asks for ("You must purchase a ticket to Keldagrim before you can ride the mine cart"): talks to the conductor standing by, takes "I'd like to buy a ticket" and then
-- "Buy" (or, when a menu of routes comes first, the one that names the fare the data gives, like 150 for "COINS=150"). False when there is no conductor or the talk goes some other way.
local function buy_ticket(fare: string): boolean
	local Player = lib("@lib/main/player")
	local Npcs = lib("@lib/main/entities/npcs")
	local ChatOptions = lib("@lib/main/interfaces/chatbox/chat_options")
	local me = Player.position()
	if me == nil then
		return false
	end
	local conductor = nil
	for _, npc in ipairs(Npcs.find() or {}) do
		if string.find(string.lower(npc.name or ""), "conductor", 1, true) ~= nil then
			if conductor == nil or Npcs.distance(npc, me) < Npcs.distance(conductor, me) then
				conductor = npc
			end
		end
	end
	if conductor == nil or Npcs.distance(conductor, me) > Transports.RIDE_NPC_RANGE then
		Log.log("Transports", "the cart wants a ticket and no conductor is near")
		return false
	end
	if not Npcs.interact(conductor, "Talk-to") then
		Log.log("Transports", "couldn't talk to the conductor")
		return false
	end
	local deadline = time() + Transports.TICKET_TIMEOUT_MS
	local bought_at: number? = nil
	local idle_since = time()
	while time() < deadline do
		local choices = ChatOptions.get()
		if choices ~= nil and #choices > 0 then
			idle_since = time()
			local pick: string? = nil
			for _, option in ipairs(choices) do
				local text = string.lower(option.text)
				if pick == nil and string.find(text, "ticket", 1, true) ~= nil then
					pick = option.text
				elseif pick == nil and fare ~= "" and string.find(text, fare, 1, true) ~= nil then
					pick = option.text
				elseif pick == nil and string.sub(text, 1, 3) == "buy" then
					pick = option.text
					bought_at = time()
				end
			end
			if pick == nil then
				Log.log(
					"Transports",
					`the conductor offers {ChatOptions.to_string(choices) or "?"}: no ticket among them`
				)
				return false
			end
			ChatOptions.select(pick)
		elseif ChatOptions.contains_continue() then
			idle_since = time()
			ChatOptions.continue_chat()
		elseif bought_at ~= nil and time() - bought_at > Transports.TICKET_DONE_MS then
			return true
		elseif time() - idle_since > Transports.TICKET_IDLE_MS then
			return bought_at ~= nil
		end
		sleep(Transports.RIDE_POLL_MS)
	end
	return bought_at ~= nil
end

-- Takes a ride (a boat, ferry, train cart or magic carpet): walks to the tile it is boarded from, clicks the NPC or object the data names (by its id, with the menu option the data starts its menu with),
-- follows the dialogue (the option that names the destination, else a yes, and "continue"), and waits to land. False when it didn't work, and that trip is then left alone for a while.
function Transports.ride(choice: Choice): (boolean, boolean?)
	local t = choice.transport
	local from, to = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local id = choice.id or ends_id("ride", t)
	-- "Musa Point Captain Tobias 14979": the id is last; what comes before is the menu option followed by the name, and where one ends isn't marked, so every beginning is tried, longest first
	local words: { string } = {}
	for word in string.gmatch(t.menu, "%S+") do
		table.insert(words, word)
	end
	local target = tonumber(words[#words])
	if target == nil or #words < 2 then
		return fail(id, "can't read the menu in the data")
	end
	table.remove(words)
	local options: { string } = {}
	for n = #words - 1, 1, -1 do
		table.insert(options, table.concat(words, " ", 1, n))
	end
	local hints: { string } = {}
	if t.name ~= "" then
		-- "3: Pollnivneach": the number is where the dialogue lists it, which can change
		table.insert(hints, string.lower(numbered_name(t.name) or t.name))
	end
	for _, option in ipairs(options) do
		table.insert(hints, string.lower(option))
	end
	local Player = lib("@lib/main/player")
	local Npcs = lib("@lib/main/entities/npcs")
	local Objects = lib("@lib/main/entities/objects")
	local ChatOptions = lib("@lib/main/interfaces/chatbox/chat_options")
	local before = Player.position()
	if before == nil then
		return false
	end
	Log.log("Transports", `boarding {t.menu}: saves about {math.floor(choice.saved)} ticks`)
	-- a retry after the crossing happened but getting off didn't: we are by the destination already, so only getting off is left
	local by_destination = gap(before, to) <= Transports.ABOARD_NEAR and gap(before, from) > Transports.ABOARD_NEAR
	if by_destination then
		if before.plane ~= to.plane and not Transports.disembark(to) then
			return fail(id, "couldn't get off the boat")
		end
		return true
	end
	if not walk_near(from, Transports.DOCK_NEAR) then
		return fail(id, "couldn't walk to the boarding tile")
	end
	-- the NPC with that id, else the object
	local npc = Npcs.nearest(target, from)
	local loc = if npc == nil then Objects.nearest(target, from) else nil
	-- The data's ids and names are not always the game's: an NPC id can be the form an NPC shows after a quest or varbit has changed it (the game's list has the placed one), and names
	-- change (the sailor the data calls Veos is Cabin Boy Herbert). The options hold: so the NPC is found by asking which of the ones near offers an option the menu starts with, by its
	-- right-click menu, and the option is picked from that menu.
	local picked = false
	if npc == nil and loc == nil then
		local Minimenu = lib("@lib/main/interfaces/minimenu")
		local Camera = lib("@lib/main/camera")
		local near = {}
		for _, candidate in ipairs(Npcs.find() or {}) do
			local gap = gap(candidate, from)
			if gap <= Transports.RIDE_NPC_RANGE then
				table.insert(near, { npc = candidate, gap = gap })
			end
		end
		table.sort(near, function(a, b)
			return a.gap < b.gap
		end)
		for i = 1, math.min(#near, Transports.RIDE_NPC_LOOKS) do
			local candidate = near[i].npc
			-- an NPC can only be right-clicked where the camera shows it, and one that walks about can slip from under the mouse: look twice
			for _ = 1, 2 do
				if picked then
					break
				end
				Camera.face({ x = candidate.x, y = candidate.y }, true)
				if Npcs.click(candidate, "right") then
					sleep(250)
					local offered: string? = nil
					for _, entry in ipairs(Minimenu.entries() or {}) do
						for _, option in ipairs(options) do
							if offered == nil and string.lower(entry.option) == string.lower(option) then
								offered = entry.option
							end
						end
					end
					if offered ~= nil and Minimenu.select(offered) then
						npc, picked = candidate, true
					else
						Minimenu.close()
					end
				end
			end
			if picked then
				break
			end
		end
	end
	if npc == nil and loc == nil then
		return fail(id, `nothing with id {target} or offering {table.concat(options, " / ")} is near`)
	end
	local start = Player.position() or before
	local clicked = picked
	local function click_target(): boolean
		for _, option in ipairs(options) do
			local done = false
			if npc ~= nil then
				done = Npcs.interact(npc, option)
			else
				done = Objects.interact(loc, option)
			end
			if done then
				return true
			end
		end
		return false
	end
	-- what the game says after the click is read from here on: a cart that wants a ticket says so
	local Chat = lib("@lib/main/interfaces/chatbox/chat")
	local seen = (Chat.last_message() or { uid = 0 }).uid
	if not clicked then
		clicked = click_target()
	end
	if not clicked then
		return fail(id, `none of the options {table.concat(options, " / ")} could be clicked`)
	end
	local ticket_tried = false
	-- the dialogue and the trip
	local deadline = time() + Transports.RIDE_TIMEOUT_MS
	local underground = start.y >= 6400
	-- what was said last, and when anything last happened: a conversation that ends without a trip (the monk who won't take weapons to Entrana) is over soon after, not when the time is up
	local last_said: string? = nil
	local quiet_since = time()
	local clicked_at = time()
	-- a dialogue with only options says nothing, and the trip it starts can take a while to show
	local answered = false
	while time() < deadline do
		local now = Player.position()
		if now ~= nil then
			local moved = gap(now, start)
			local near_destination = gap(now, to) <= Transports.ARRIVED_NEAR + 10
			-- the click can make the player walk to the NPC or the cart, up a gangplank: that is not the trip. The trip is a jump (a voyage, a ride, a teleport), or being at the destination
			if
				moved >= Transports.RIDE_LAND_DISTANCE
				or (near_destination and moved >= Transports.LAND_DISTANCE)
				or (now.y >= 6400) ~= underground
			then
				if is_house(to) then
					if not wait_to_land(id, to, Transports.RIDE_VOYAGE_MS) then
						return fail(id, "the house didn't load")
					end
					return true
				end
				-- a voyage can be an instance (the squire's boat at Port Sarim) that ends at the destination some seconds later: wait for it
				local voyage = time() + Transports.RIDE_VOYAGE_MS
				while time() < voyage and gap(now, to) > Transports.ARRIVED_NEAR + 10 do
					sleep(Transports.RIDE_POLL_MS)
					now = Player.position() or now
				end
				Transports.settle()
				-- a magic carpet glides the whole way, hovers a moment after it stops, and the player then walks off it: a click before that is over does nothing
				if t.kind == "magic_carpets" then
					local off = time() + Transports.RIDE_VOYAGE_MS
					while time() < off and Player.pose() == Transports.CARPET_POSE do
						sleep(Transports.RIDE_POLL_MS)
					end
					Player.wait_server_still(Transports.RIDE_VOYAGE_MS)
				end
				now = Player.position() or now
				-- a boat can put you aboard, a plane above the dock the data names: the gangplank leads onto it
				if now.plane ~= to.plane then
					Random.sleep(Transports.RIDE_DOCK_PAUSE_MS[1], Transports.RIDE_DOCK_PAUSE_MS[2])
				end
				if now.plane ~= to.plane and not Transports.disembark(to) then
					local after = Player.position() :: Tile
					local plank = Objects.nearest(Transports.GANGPLANK, after)
					return fail(
						id,
						`couldn't get off the boat: landed at {now.x}, {now.y} on plane {now.plane}, now at {after.x}, {after.y} plane {after.plane}; gangplank {if plank
							then `{plank.id} at {plank.x}, {plank.y} plane {plank.plane}`
							else "none loaded"}`
					)
				end
				now = Player.position() or now
				if gap(now, to) > Transports.ARRIVED_NEAR + 10 then
					Log.log("Transports", `{id}: landed at {now.x}, {now.y}, not near {to.x}, {to.y}`)
				end
				return true
			end
		end
		for _, message in ipairs(Chat.new_messages(seen) or {}) do
			seen = math.max(seen, message.uid)
			if not ticket_tried and string.find(string.lower(message.text), "purchase a ticket", 1, true) ~= nil then
				ticket_tried = true
				local fare = string.match(t.items, "COINS=(%d+)") or ""
				Log.log("Transports", `{id}: the cart wants a ticket ({fare} coins)`)
				if not buy_ticket(fare) then
					return fail(id, "couldn't buy the ticket")
				end
				-- the ticket is bought: click the cart again
				seen = (Chat.last_message() or { uid = seen }).uid
				if not click_target() then
					return fail(id, "couldn't click the cart again after buying the ticket")
				end
				clicked_at, quiet_since, last_said = time(), time(), nil
			end
		end
		local speech = ChatOptions.speech()
		if speech ~= nil then
			last_said = `{speech.name}: {speech.text}`
		end
		local choices = ChatOptions.get()
		if (choices ~= nil and #choices > 0) or ChatOptions.contains_continue() then
			quiet_since = time()
			answered = true
		end
		local silent_ms = if t.kind == "magic_carpets" then Transports.CARPET_SILENT_MS else Transports.RIDE_SILENT_MS
		if last_said == nil and not answered and time() - clicked_at > silent_ms then
			return fail(id, "nothing was said and nothing happened")
		end
		if last_said ~= nil and time() - quiet_since > Transports.RIDE_QUIET_MS then
			-- the conversation is over and the trip did not start: this is a no, and asking again gets the same
			Log.log("Transports", `{id}: the conversation ended and nothing happened; last said "{last_said}"`)
			return false, true
		end
		if choices ~= nil and #choices > 0 then
			local pick = Transports.dialogue_pick(choices, hints)
			if pick == nil then
				Log.log("Transports", `{id}: no option to pick among {ChatOptions.to_string(choices) or "?"}`)
				return false
			end
			-- the key doesn't always take: then the line is clicked
			if not ChatOptions.select(pick) and ChatOptions.find(pick) ~= nil then
				ChatOptions.select(pick, nil, 0)
			end
		elseif ChatOptions.contains_continue() then
			ChatOptions.continue_chat()
		end
		sleep(Transports.RIDE_POLL_MS)
	end
	return fail(id, "the trip didn't happen")
end

-- Takes the chosen charter ship: walks to the dock, talks to the trader, picks the destination by name, waits for the boat and crosses the gangplank.
function Transports.sail(choice: Choice): boolean
	local t = choice.transport
	local dock, to = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local label = string.match(t.name, "^%w+:%s*(.+)$")
	local id = choice.id or t.name
	if label == nil then
		return fail(id, "no destination name in the data")
	end
	-- what to say to the trader: the first word of "Charter Trader Crewmember 1330"
	local option = string.match(t.menu, "^(%S+)")
	if option == nil then
		return fail(id, "the data doesn't say what to say to the trader")
	end
	local before = lib("@lib/main/player").position()
	if before == nil then
		return false
	end
	Log.log("Transports", `sailing to {label}: saves about {math.floor(choice.saved)} ticks`)
	-- a retry after the boat came but the gangplank didn't work: only the crossing is left
	if gap(before, to) > Transports.ABOARD_NEAR then
		if not walk_near(dock, Transports.DOCK_NEAR) then
			return fail(id, "couldn't walk to the dock")
		end
		local opened, why = Chartering.open(option, dock)
		if not opened then
			return fail(id, why or "the destination list didn't open")
		end
		-- by name, never by key letter: the letters differ by port
		if Chartering.select(label :: any) == nil then
			return fail(id, `{label} isn't in the list`)
		end
		if not wait_to_land(id, to, Transports.CHARTER_SAIL_TIMEOUT_MS) then
			return fail(id, "the boat didn't come")
		end
	end
	if not Transports.disembark(to) then
		return fail(id, "couldn't get off the boat")
	end
	return true
end

-- Goes through the chosen gate: walks to the tile before it, clicks the object between the tiles by name (its id changes with quest progress) and waits to be on the other side.
function Transports.pass(choice: Choice): boolean
	local t = choice.transport
	local o, d = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local id = choice.id or ends_id("link", t)
	-- "Pay-toll(2-Ecto) Energy Barrier 16105": the option, the object's name, its id
	local option, target = string.match(t.menu, "^(%S+)%s+(.-)%s+%d+%s*$")
	if option == nil or target == nil then
		return fail(id, "the data doesn't say what to click")
	end
	Log.log("Transports", `going through the {target} at {o.x}, {o.y}`)
	if not walk_near(o, Transports.LINK_ARRIVED_NEAR) then
		return fail(id, "couldn't walk to it")
	end
	local Objects = lib("@lib/main/entities/objects")
	local gate = Objects.nearest(target, { x = (o.x + d.x) // 2, y = (o.y + d.y) // 2 })
	if gate == nil then
		return fail(id, `no {target} in sight`)
	end
	if not Objects.interact(gate, { "Pass", option }) then
		return fail(id, "couldn't click it")
	end
	if not wait_near(d, Transports.LINK_ARRIVED_NEAR, Transports.LINK_TIMEOUT_MS) then
		return fail(id, "didn't get through")
	end
	return true
end

-- Uses the item in the row's menu on the object: "Use Rope -> Boulder 5842". True once standing where the row lands.
function Transports.use_on(choice: Choice): boolean
	local t = choice.transport
	local o, d = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local id = choice.id or ends_id("item_on", t)
	local item, target, loc_id = string.match(t.menu, "^Use (.-) %-> (.-)%s+(%d+)%s*$")
	if item == nil or target == nil then
		return fail(id, "the data doesn't say what to use on what")
	end
	local ids = ids_of(item)
	if ids == nil then
		return fail(id, `can't tell what a {item} is`)
	end
	if not walk_near(o, Transports.LINK_ARRIVED_NEAR) then
		return fail(id, "couldn't walk to it")
	end
	local Inventory = lib("@lib/main/interfaces/gametabs/inventory")
	local Objects = lib("@lib/main/entities/objects")
	local loc = Objects.nearest(tonumber(loc_id) :: number, o) or Objects.nearest(target, o)
	if loc == nil then
		return fail(id, `no {target} in sight`)
	end
	if not Inventory.select(ids) then
		return fail(id, `couldn't pick up the {item}`)
	end
	if not Objects.interact(loc, "Use") then
		Inventory.deselect()
		return fail(id, "couldn't click it")
	end
	if not wait_near(d, Transports.LINK_ARRIVED_NEAR, Transports.LINK_TIMEOUT_MS) then
		return fail(id, "didn't get across")
	end
	return true
end

-- Pulls the chosen lever: walks beside it, clicks the option the row names on the object it names ("Pull Lever 1814") and waits to land on the row's destination.
function Transports.pull(choice: Choice): boolean
	local t = choice.transport
	local o, d = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local id = choice.id or ends_id("lever", t)
	local option, target, object = string.match(t.menu, "^(%S+)%s+(.-)%s+(%d+)%s*$")
	if option == nil or target == nil or object == nil then
		return fail(id, "the data doesn't say what to click")
	end
	Log.log("Transports", `pulling the {target} at {o.x}, {o.y}`)
	if not walk_near(o, 1) then
		return fail(id, "couldn't walk to it")
	end
	local Objects = lib("@lib/main/entities/objects")
	local lever = Objects.nearest(tonumber(object) :: number, o) or Objects.nearest(target, o)
	if lever == nil then
		return fail(id, `no {target} in sight`)
	end
	if Objects.distance(lever, o) > Transports.LEVER_OBJECT_NEAR then
		return fail(id, `no {target} close enough to {o.x}, {o.y}`)
	end
	if not Objects.interact(lever, { option }) then
		return fail(id, "couldn't click it")
	end
	if not wait_near(d, Transports.LEVER_ARRIVED_NEAR, Transports.LEVER_TIMEOUT_MS) then
		return fail(id, "didn't get across")
	end
	Transports.settle(d)
	return true
end

-- Lowercase text without colour tags, a leading "1. ", apostrophes and trailing dots, to compare a destination with a menu row or a dialogue line.
local function plain(text: string): string
	local t = string.lower((string.gsub(text, "<[^>]*>", "")))
	t = string.gsub(t, "['`]", "")
	t = string.gsub(t, "\u{2019}", "")
	t = string.gsub(t, "^%s*%d+[%.:]%s*", "")
	t = string.gsub(t, "[%.%s]+$", "")
	return t
end

-- The line that names `label`: the same text first, else one that contains it.
local function best_line(lines: { string }, label: string): string?
	local want = plain(label)
	for _, line in ipairs(lines) do
		if plain(line) == want then
			return line
		end
	end
	for _, line in ipairs(lines) do
		if want ~= "" and string.find(plain(line), want, 1, true) ~= nil then
			return line
		end
	end
	return nil
end

-- A destination reached through several menus is written "Fishing Teleports: Fishing Guild": its parts, outermost first.
local function label_parts(label: string): { string }
	local parts: { string } = {}
	for part in string.gmatch(label .. ": ", "(.-): ") do
		table.insert(parts, part)
	end
	return parts
end

local function in_list(list: { string }, option: string): boolean
	for _, x in ipairs(list) do
		if string.lower(x) == string.lower(option) then
			return true
		end
	end
	return false
end

-- The inventory (or worn) slot that holds one of `ids`, with the module that clicks it.
local function find_held(ids: { number }): (any?, number?)
	local wanted: { [number]: boolean } = {}
	for _, id in ipairs(ids) do
		wanted[id] = true
	end
	local modules = {
		{ Transports.INVENTORY, "@lib/main/interfaces/gametabs/inventory" },
		{ Transports.WORN, "@lib/main/interfaces/gametabs/wornitems" },
	}
	for _, m in ipairs(modules) do
		for _, item in ipairs(Host.item_container(m[1] :: number) or {}) do
			if wanted[item.id] then
				return lib(m[2]), item.slot
			end
		end
	end
	return nil, nil
end

-- The options the menu of an item shows when it is hovered.
local function item_options(module: any, slot: number): { string }
	local Minimenu = lib("@lib/main/interfaces/minimenu")
	module.hover_slot(slot)
	local waited = 0
	while waited <= 800 do
		local entries = Minimenu.entries()
		if entries ~= nil and #entries > 1 then
			local options: { string } = {}
			for _, e in ipairs(entries) do
				table.insert(options, e.option)
			end
			return options
		end
		sleep(50)
		waited += 50
	end
	return {}
end

-- The option of the item's menu that names the destination itself (a crystal's "Lletya"), else, for an item with one destination, its first option that isn't a plain one ("Teleport", "Weiss").
local function direct_option(options: { string }, label: string?): string?
	local direct: { string } = {}
	for _, option in ipairs(options) do
		if not in_list(Transports.ITEM_NOT_TELEPORT, option) and not in_list(Transports.ITEM_OPENERS, option) then
			table.insert(direct, option)
		end
	end
	if label ~= nil then
		local parts = label_parts(label)
		return best_line(direct, parts[#parts])
	end
	for _, option in ipairs(options) do
		if in_list(Transports.ITEM_OPENERS, option) then
			return option
		end
	end
	return direct[1]
end

-- Closes a dialogue of options left open (Escape) and waits for it to go; false when it stays.
local function close_dialogue(): boolean
	local ChatOptions = lib("@lib/main/interfaces/chatbox/chat_options")
	local Keyboard = lib("@lib/utils/input/keyboard")
	for _ = 1, 3 do
		local lines = ChatOptions.get()
		if lines == nil or #lines == 0 then
			return true
		end
		Keyboard.key_press(Keyboard.keys.ESCAPE)
		sleep(600)
	end
	local lines = ChatOptions.get()
	return lines == nil or #lines == 0
end

-- Looks through the submenus of the item's menu (opened by a right click) for the destination: the option that has it listed and the line to pick. The menu is left open when found, else closed.
local function find_in_submenus(module: any, slot: number, label: string): (string?, string?)
	local Minimenu = lib("@lib/main/interfaces/minimenu")
	module.hover_slot(slot)
	if not Minimenu.open() then
		return nil, nil
	end
	local parts = label_parts(label)
	local parents: { string } = {}
	for _, e in ipairs(Minimenu.entries() or {}) do
		if e.submenu then
			table.insert(parents, e.option)
		end
	end
	for _, parent in ipairs(parents) do
		if Minimenu.open_submenu(parent) then
			local lines: { string } = {}
			for _, e in ipairs(Minimenu.submenu_entries(parent) or {}) do
				table.insert(lines, e.option)
			end
			local line = best_line(lines, parts[#parts])
			if line ~= nil then
				return parent, line
			end
		end
	end
	Minimenu.close()
	return nil, nil
end

-- Uses a teleport item: picks the destination in the submenu of its option or in the dialogue the option opens, and waits to land.
-- The second result is true when trying again would be pointless (the item or the destination isn't offered).
function Transports.use_item(choice: Choice): (boolean, boolean?)
	local Player = lib("@lib/main/player")
	local ChatOptions = lib("@lib/main/interfaces/chatbox/chat_options")
	local Interact = lib("@lib/main/interact")
	local t = choice.transport
	local to = t.destination :: Host.TransportTile
	local label = choice.option
	local ids: { number } = {}
	for id in string.gmatch(t.items, "(%d+)=%d+") do
		table.insert(ids, tonumber(id) :: number)
	end
	local module, slot = find_held(ids)
	local before = Player.position()
	if module == nil or slot == nil or before == nil then
		Log.log("Transports", `{t.name}: the item isn't held`)
		return false, true
	end
	close_dialogue()
	local clicked = false
	-- the option clicked to open a dialogue, kept in case it opens none (the max cape's list is a submenu and nothing else)
	local dialogue_parent: string? = nil
	local clicked_at = 0
	local Minimenu = lib("@lib/main/interfaces/minimenu")
	local direct = direct_option(item_options(module, slot), label)
	if direct ~= nil and label ~= nil then
		Log.log("Transports", `{t.name}: "{direct}", saves about {math.floor(choice.saved)} ticks`)
		clicked = module.interact_slot(slot, direct)
	else
		local parent, line = nil, nil
		if label ~= nil then
			parent, line = find_in_submenus(module, slot, label)
		end
		if parent ~= nil and line ~= nil then
			if prefers_quick() then
				Log.log("Transports", `{t.name}: "{parent}" > "{line}", saves about {math.floor(choice.saved)} ticks`)
				local before_click = Minimenu.clicked()
				clicked = Minimenu.select_submenu(line, nil, parent)
					and (before_click == nil or Minimenu.wait_click(before_click) ~= nil)
			else
				Log.log(
					"Transports",
					`{t.name}: "{parent}" and the dialogue, saves about {math.floor(choice.saved)} ticks`
				)
				local _, ok = Interact.open_menu({ parent }, nil, false)
				clicked = ok == true
				dialogue_parent = parent
			end
			if not clicked then
				Minimenu.close()
			end
		elseif direct ~= nil then
			Log.log("Transports", `{t.name}: "{direct}", saves about {math.floor(choice.saved)} ticks`)
			clicked = module.interact_slot(slot, direct)
		else
			-- no submenu lists it: the option that opens a dialogue of destinations, if the item has one
			local opener: string? = nil
			for _, name in ipairs(Transports.ITEM_OPENERS) do
				for _, option in ipairs(item_options(module, slot)) do
					if opener == nil and string.lower(option) == string.lower(name) then
						opener = option
					end
				end
			end
			if opener == nil then
				Log.log("Transports", `{t.name}: no option of the item gives it`)
				return false, true
			end
			Log.log("Transports", `{t.name}: "{opener}" and the dialogue`)
			clicked = module.interact_slot(slot, opener)
		end
	end
	if not clicked then
		return false
	end
	clicked_at = time()
	local last = Player.position() or before
	local seen_dialogue = false
	local parts = if label ~= nil then label_parts(label) else {}
	local step = 1
	local seen = ""
	local deadline = time() + Transports.ITEM_TIMEOUT_MS
	while time() < deadline do
		local now = Player.position()
		if now ~= nil then
			if now.plane ~= last.plane or gap(now, last) >= Transports.LAND_DISTANCE then
				if is_house(to) then
					return wait_to_land(t.name, to, Transports.ITEM_TIMEOUT_MS)
				end
				if gap(now, to) > 10 then
					Log.log("Transports", `{t.name} landed at {now.x}, {now.y}, not near {to.x}, {to.y}`)
				end
				Transports.settle()
				return true
			end
			last = now
		end
		local lines = ChatOptions.get()
		local shown = ChatOptions.to_string(lines) or ""
		if lines ~= nil and #lines > 0 then
			seen_dialogue = true
		elseif dialogue_parent ~= nil and not seen_dialogue and time() - clicked_at > Transports.ITEM_DIALOGUE_MS then
			-- no dialogue came: the option only lists its destinations in the submenu
			dialogue_parent = nil
			local parent, line = find_in_submenus(module, slot, label :: string)
			if parent ~= nil and line ~= nil then
				Log.log("Transports", `{t.name}: no dialogue, "{parent}" > "{line}" instead`)
				Minimenu.select_submenu(line, nil, parent)
			end
		end
		if lines ~= nil and #lines > 0 and shown ~= seen then
			seen = shown
			local texts: { string } = {}
			for _, line in ipairs(lines) do
				table.insert(texts, line.text)
			end
			-- the next part of the destination that this dialogue names (a flat list names only the last)
			local text: string? = nil
			for i = step, #parts do
				text = best_line(texts, parts[i])
				if text ~= nil then
					step = i + 1
					break
				end
			end
			-- the key for a line doesn't always take (the slayer ring's list): then the line is clicked
			local picked = text ~= nil and ChatOptions.select(text)
			if text ~= nil and not picked and ChatOptions.find(text) ~= nil then
				picked = ChatOptions.select(text, nil, 0)
			end
			if picked then
				seen = ""
			else
				Log.log("Transports", `{t.name}: the dialogue ({shown}) has no "{label or "?"}"`)
				close_dialogue()
				return false, true
			end
		end
		sleep(100)
	end
	Log.log("Transports", `{t.name} didn't work`)
	return false
end

-- Whether a choice failed in the last `RETRY_AFTER_MS`, and so isn't chosen.
function Transports.failed_lately(choice: Choice): boolean
	return not not_failed(choice.id or choice.transport.name)
end

-- Takes a trip with a quetzal whistle: "Last-destination" when that is the site, else its map. The second result is true when the whistle refused, so trying again is pointless.
function Transports.whistle(choice: Choice): (boolean, boolean?)
	local Quetzal = lib("@lib/main/interfaces/mainscreen/quetzal")
	local t = choice.transport
	local label = choice.option :: string
	local to = t.destination :: Host.TransportTile
	Log.log("Transports", `{t.name}: saves about {math.floor(choice.saved)} ticks`)
	if Quetzal.is_last(label) and prefers_quick() then
		if not Quetzal.signal_last() then
			return false
		end
		if wait_to_land(t.name, to, Transports.ITEM_TIMEOUT_MS) then
			return true
		end
		Log.log("Transports", `{t.name}: nothing happened (no charges?)`)
		return false, true
	end
	local opened, why = Quetzal.signal()
	if not opened then
		Log.log("Transports", `{t.name}: {why or "the map didn't open"}`)
		return false, true
	end
	if not Quetzal.select(label) then
		Quetzal.close()
		return false
	end
	return wait_to_land(t.name, to, Transports.ITEM_TIMEOUT_MS)
end

-- Puts on what a climb from one tile to another by this menu option has to be used with (`WORN_GROUPS`), from the inventory. True when nothing more has to be put on.
function Transports.wear_for_climb(from: Host.NavTile, to: Host.NavTile, option: string): boolean
	local t: Transport? = nil
	for _, row in ipairs(gated().by_ends[`{from.x},{from.y},{from.plane}>{to.x},{to.y},{to.plane}`] or {}) do
		if string.sub(row.menu, 1, #option + 1) == `{option} ` then
			t = row
		end
	end
	if t == nil then
		return true
	end
	local Inventory = lib("@lib/main/interfaces/gametabs/inventory")
	for _, group in ipairs(Transports.WORN_GROUPS) do
		if string.find(t.items, group, 1, true) ~= nil then
			local wanted: { [number]: boolean } = {}
			for _, id in ipairs(ids_of(group) or {}) do
				wanted[id] = true
			end
			local function find(container: number): number?
				for _, item in ipairs(Host.item_container(container) or {}) do
					if wanted[item.id] then
						return item.slot
					end
				end
				return nil
			end
			if find(Transports.WORN) == nil then
				local slot = find(Transports.INVENTORY)
				if slot == nil then
					return fail(group, "not held")
				end
				local wear: string? = nil
				for _, offered in ipairs(item_options(Inventory, slot)) do
					if table.find(Transports.WEAR_OPTIONS, offered) ~= nil then
						wear = offered
						break
					end
				end
				if wear == nil or not Inventory.interact_slot(slot, wear) then
					return fail(group, "couldn't put it on")
				end
				local deadline = time() + Transports.WEAR_TIMEOUT_MS
				while find(Transports.WORN) == nil do
					if time() >= deadline then
						return fail(group, "didn't go on")
					end
					sleep(50)
				end
			end
		end
	end
	return true
end

-- Takes a trip from inside the house: finds the furniture (the Nexus, the jewellery box or something mounted), wherever it is, and picks the place. What turns out not to be there is left out for the run, and the walk plans again.
function Transports.house(choice: Choice): (boolean, boolean?)
	local House = lib("@lib/main/house")
	local t = choice.transport
	local furniture, label = choice.spell, choice.option :: string
	local id = choice.id or ends_id("house", t)
	if not House.inside() then
		return fail(id, "not in the house")
	end
	Log.log("Transports", `house {furniture} to {label}: saves about {math.floor(choice.saved)} ticks`)
	if furniture ~= "box" and furniture ~= "nexus" then
		local went, why, missing = lib("@lib/main/interfaces/mainscreen/mounted").teleport(furniture, label)
		if went then
			return wait_to_land(id, t.destination :: Host.TransportTile, Transports.HUB_TIMEOUT_MS)
		end
		if missing then
			house_missing[id] = true
			fail(id, why or "it isn't there")
			return false, true
		end
		return fail(id, why or "couldn't use it")
	end
	local module = lib(
		if furniture == "box"
			then "@lib/main/interfaces/mainscreen/jewellerybox"
			else "@lib/main/interfaces/mainscreen/nexus"
	)
	local opened, why
	if furniture == "box" then
		local box = House.reach(module.OBJECT)
		if box == nil then
			why = "no jewellery box in this house"
		else
			opened, why = module.open(box)
		end
	else
		opened, why = module.open()
	end
	if not opened then
		house_missing[furniture] = true
		fail(id, why or "couldn't open it")
		return false, true
	end
	if module.find(label) == nil then
		house_missing[id] = true
		module.close()
		fail(id, `{label} isn't there`)
		return false, true
	end
	if furniture == "box" and module.select(label) == nil or furniture ~= "box" and not module.select(label) then
		module.close()
		return fail(id, `{label} couldn't be chosen`)
	end
	return wait_to_land(id, t.destination :: Host.TransportTile, Transports.HUB_TIMEOUT_MS)
end

-- Leaves the house by its portal, wherever that is.
function Transports.house_exit(choice: Choice): boolean
	Log.log("Transports", "leaving the house")
	if not lib("@lib/main/house").leave() then
		return fail(choice.id or "house exit", "couldn't leave")
	end
	Transports.settle()
	return true
end

-- Takes a canoe from the station at the row's start, making the smallest canoe that reaches the row's end. The second result is true when trying again is pointless.
function Transports.canoe(choice: Choice): (boolean, boolean?)
	local Canoe = lib("@lib/main/interfaces/mainscreen/canoe")
	local t = choice.transport
	local from = t.origin :: Host.TransportTile
	Log.log("Transports", `canoe to {t.name}: saves about {math.floor(choice.saved)} ticks`)
	if not walk_near(from, Transports.DOCK_NEAR) then
		return false
	end
	local level = if t.skills[1] ~= nil then t.skills[1].level else nil
	local ok, why = Canoe.travel(t.name, Canoe.kind_for_level(level))
	if ok then
		Transports.settle()
		return true
	end
	Log.log("Transports", `canoe to {t.name}: {why or "failed"}`)
	if why == Canoe.NO_AXE then
		no_canoe_axe = axes_held(held_counts())
		return false, true
	end
	return false, why == Canoe.CANT_REACH
end

-- Takes a trip with a scroll from the master scroll book. The second result is true when the book can't be used, so trying again is pointless.
function Transports.scroll_book(choice: Choice): (boolean, boolean?)
	local Scrollbook = lib("@lib/main/interfaces/mainscreen/scrollbook")
	local t = choice.transport
	Log.log("Transports", `{t.name}: saves about {math.floor(choice.saved)} ticks`)
	local opened, why = Scrollbook.open()
	if not opened then
		Log.log("Transports", `{t.name}: {why or "the book didn't open"}`)
		return false, true
	end
	if not Scrollbook.select(choice.option) then
		Scrollbook.close()
		return false
	end
	return wait_to_land(t.name, t.destination :: Host.TransportTile, Transports.ITEM_TIMEOUT_MS)
end

-- How each kind of choice is carried out (a table, so that a test can stand in for the game).
Transports.runners = {
	minigame = function(choice: Choice): (boolean, boolean?)
		return Transports.minigame(choice)
	end,
	scroll_book = function(choice: Choice): (boolean, boolean?)
		return Transports.scroll_book(choice)
	end,
	quetzal_whistle = function(choice: Choice): (boolean, boolean?)
		return Transports.whistle(choice)
	end,
	spell = function(choice: Choice): (boolean, boolean?)
		return Transports.cast(choice)
	end,
	item = function(choice: Choice): (boolean, boolean?)
		return Transports.use_item(choice)
	end,
	charter = function(choice: Choice): boolean
		return Transports.sail(choice)
	end,
	link = function(choice: Choice): boolean
		return Transports.pass(choice)
	end,
	lever = function(choice: Choice): boolean
		return Transports.pull(choice)
	end,
	ride = function(choice: Choice): (boolean, boolean?)
		return Transports.ride(choice)
	end,
	house = function(choice: Choice): (boolean, boolean?)
		return Transports.house(choice)
	end,
	house_exit = function(choice: Choice): boolean
		return Transports.house_exit(choice)
	end,
	item_on = function(choice: Choice): boolean
		return Transports.use_on(choice)
	end,
	canoe = function(choice: Choice): (boolean, boolean?)
		return Transports.canoe(choice)
	end,
} :: { [string]: (Choice) -> (boolean, boolean?) }
for _, hub in ipairs(HUBS) do
	Transports.runners[hub.kind] = function(choice: Choice): (boolean, boolean?)
		return Transports.hub(choice)
	end
end

-- Whether a slow trip has landed after all: trying again would spend it twice.
local function already_there(choice: Choice): boolean
	local to = choice.transport.destination
	if to == nil then
		return false
	end
	local now = lib("@lib/main/player").position()
	return now ~= nil and now.plane == to.plane and gap(now, to) <= Transports.ARRIVED_NEAR
end

-- Uses the chosen transport: up to `ATTEMPTS` tries. If they all fail, or a runner says trying again is pointless, it is left out for `RETRY_AFTER_MS`. True when one worked.
function Transports.use(choice: Choice): boolean
	local run = Transports.runners[choice.kind]
	if run == nil then
		return false
	end
	local id = choice.id or choice.transport.name
	for attempt = 1, Transports.ATTEMPTS do
		local ok, final = run(choice)
		if ok then
			return true
		end
		if final then
			failed[id] = time()
			Log.log("Transports", `{id}: refused, left out for a while`)
			return false
		end
		Log.log("Transports", `{id}: attempt {attempt} of {Transports.ATTEMPTS} failed`)
		if attempt < Transports.ATTEMPTS then
			sleep(Transports.RETRY_PAUSE_MS)
			if already_there(choice) then
				return true
			end
		end
	end
	failed[id] = time()
	Log.log("Transports", `{id}: failed {Transports.ATTEMPTS} times, left out for a while`)
	return false
end

-- Takes the best transport toward `goal`, if one is worth it. Returns whether one was used and whether one failed all its attempts: the caller then plans again from where it is.
function Transports.travel(from: Tile, goal: Tile, options: Options?): (boolean, boolean)
	if not Transports.ENABLED then
		return false, false
	end
	local choice = Transports.choose(from, goal, options)
	if choice == nil then
		return false, false
	end
	if Transports.use(choice) then
		return true, false
	end
	return false, true
end

return Transports
