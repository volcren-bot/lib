--!strict
local Host = require("@lib/host")
local sleep = Host.sleep
local time = Host.time
local Chartering = require("@lib/main/interfaces/mainscreen/chartering")
local Ferox = require("@lib/main/ferox")
local GameState = require("@lib/main/game_state")
local Log = require("@lib/utils/log")
local Random = require("@lib/utils/math/random")
local Widgets = require("@lib/main/interfaces/widgets")

type Transport = Host.Transport
type Loc = Host.Loc
type Tile = { x: number, y: number, plane: number? }

local Transports = {}

Transports.ENABLED = true
Transports.MIN_SAVING_TICKS = 30
Transports.WALK_TICKS_PER_TILE = 0.6
Transports.CAST_SLACK_TICKS = 3
Transports.LAND_TIMEOUT_MS = 8000
Transports.SLOW_CAST_SLACK_MS = 3000
Transports.SLOW_CAST_START_MS = 3000
Transports.LAND_DISTANCE = 6
Transports.SETTLE_TIMEOUT_MS = 10000
Transports.RETRY_AFTER_MS = 5 * 60 * 1000
Transports.CHARTER_SLACK_TICKS = 6
Transports.CHARTER_SAIL_TIMEOUT_MS = 15000
Transports.GANGPLANK = "Gangplank"
Transports.CROSS_TIMEOUT_MS = 20000
Transports.ARRIVED_NEAR = 4
Transports.LINK_SLACK_TICKS = 2
Transports.LINK_TIMEOUT_MS = 8000
Transports.LINK_ARRIVED_NEAR = 1
Transports.PASSAGE_SLACK_TICKS = 3
Transports.LEVER_SLACK_TICKS = 3
Transports.LEVER_TIMEOUT_MS = 12000
Transports.LEVER_ARRIVED_NEAR = 2
Transports.LEVER_OBJECT_NEAR = 3
Transports.BALLOON_STORAGE = false
Transports.WILDERNESS = false
Transports.UNLOCKS = {
	UNLOCK_KARAMJA_ELITE = { varbit = 4566, at_least = 1 },
	UNLOCK_MOR_UL_REK = { varbit = 5646, at_least = 1 },
	UNLOCK_DRAGONTOOTH = true,
	UNLOCK_XERICS_HONOUR = true,
} :: { [string]: { varbit: number, at_least: number } | boolean }
Transports.WORN_GROUPS = { "CROSSBOW", "MITH_GRAPPLE", "CLIMBING_BOOTS" }
Transports.WEAR_OPTIONS = { "Wield", "Wear", "Equip" }
Transports.WEAR_TIMEOUT_MS = 2500
Transports.HOUSE_SLACK_TICKS = 12
Transports.CANOE_SLACK_TICKS = 20
Transports.ATTEMPTS = 3
Transports.RETRY_PAUSE_MS = 1500
Transports.ABOARD_NEAR = 15
Transports.HUB_TIMEOUT_MS = 20000
Transports.RIDE_SLACK_TICKS = 8
Transports.RIDE_TIMEOUT_MS = 45000
Transports.RIDE_POLL_MS = 200
Transports.RIDE_QUIET_MS = 8000
Transports.RIDE_VOYAGE_MS = 40000
Transports.RIDE_LAND_DISTANCE = 25
Transports.CARPET_POSE = 6936
Transports.CARPET_SILENT_MS = 8000
Transports.CARPET_BONUS_TICKS = 15
Transports.RIDE_SILENT_MS = 25000
Transports.TICKET_TIMEOUT_MS = 40000
Transports.TICKET_DONE_MS = 2500
Transports.TICKET_IDLE_MS = 8000
Transports.RIDE_DOCK_PAUSE_MS = { 2500, 4000 }
Transports.RIDE_NPC_RANGE = 12
Transports.RIDE_NPC_LOOKS = 8
Transports.SHORTCUTS = true
Transports.SHORTCUT_MIN_SAVING_TILES = 10
Transports.VALID_FOR_MS = 20 * 1000
Transports.PLANE_CHANGE_TICKS = 10
Transports.CONFIRM_WALK_TILES = 64
Transports.CONFIRM_WALK_NEAR = 2
Transports.INVENTORY = 93
Transports.WORN = 94
Transports.DOCK_NEAR = 3
Transports.ITEMS = true
Transports.ITEM_SLACK_TICKS = 3
Transports.ITEM_CHARGE_TICKS = 40
Transports.ITEM_TIMEOUT_MS = 12000
Transports.ITEM_DIALOGUE_MS = 2500
Transports.ITEM_SUBMENU_BASE = 0.7
Transports.ITEM_OPENERS = { "Rub", "Teleport", "Teleports", "Commune", "Break", "Operate" }
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
Transports.UNDERGROUND = 6400

export type Options = {
	exclude: { [string]: boolean }?,
	min_saving_ticks: number?,
	shortcuts: boolean?,
	wilderness: boolean?,
}

export type Choice = {
	kind: string,
	transport: Transport,
	id: string?,
	spell: string,
	option: string?,
	ticks: number,
	saved: number,
}

local function lib(path: string): any
	return (require :: any)(path)
end

local function gap(a: Tile, b: Tile): number
	return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

local function within(a: Tile?, b: Tile, near: number): boolean
	return a ~= nil and a.plane == b.plane and gap(a, b) <= near
end

local function log_saving(what: string, choice: Choice)
	Log.log("Transports", `{what}: saves about {math.floor(choice.saved)} ticks`)
end

local function fail(id: string, why: string): boolean
	Log.log("Transports", `{id}: {why}`)
	return false
end

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

type Check = {
	levels: { [string]: number }?,
	here_wild: number,
	into_wild: boolean,
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
	}
end

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
	local base = 0.25 * (r("defence") + r("hitpoints") + math.floor(r("prayer") / 2))
	local melee = 0.325 * (r("attack") + r("strength"))
	local ranged = 0.325 * math.floor(r("ranged") * 1.5)
	local magic = 0.325 * math.floor(r("magic") * 1.5)
	levels.combat = math.floor(base + math.max(melee, ranged, magic))
	return levels
end

local warned_skills: { [string]: boolean } = {}

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

local function row_ok(t: Transport, c: Check): boolean
	return holds(t, c)
		and Transports.skills_met(t, c.levels)
		and Transports.quests_done(t, c.quests)
		and Transports.items_met(t, held(c))
end

local failed: { [string]: number } = {}

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

local house_missing: { [string]: boolean } = {}

local function is_house(tile: { x: number, y: number }): boolean
	return lib("@lib/main/house").is_tile(tile)
end

local function not_failed(id: string): boolean
	local at = failed[id]
	return at == nil or time() - at > Transports.RETRY_AFTER_MS
end

type Gated = { keys: { string }, across: { Transport }, by_ends: { [string]: { Transport } }, at: number }
local gated_rows: { [boolean]: Gated } = {}

local function turned_off(): { [string]: boolean }
	local off: { [string]: boolean } = {}
	for _, name in ipairs(Host.transport_settings().off) do
		off[name] = true
	end
	return off
end

function Transports.is_enabled(name: string): boolean
	return not turned_off()[name]
end

function Transports.require_enabled(name: string)
	if not Transports.is_enabled(name) then
		error(`this script needs the transport type "{name}", which is turned off in the loader's Settings`)
	end
end

local note_ok: (t: Transport, c: Check) -> boolean

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
	local function allow(t: Transport)
		local o, d = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
		local ends = `{o.x},{o.y},{o.plane}>{d.x},{d.y},{d.plane}`
		by_ends[ends] = by_ends[ends] or {}
		table.insert(by_ends[ends], t)
		table.insert(across, t)
	end
	for _, kind in { "climb_gated", "link_gated" } do
		for _, t in ipairs(rows_of(kind)) do
			if row_ok(t, c) and note_ok(t, c) then
				allow(t)
			end
		end
	end
	if on then
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
				allow(t)
			end
		end
	end
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

function Transports.allowed_climbs(options: { shortcuts: boolean? }?): { string }
	return gated(options and options.shortcuts).keys
end

local function tile_key(x: number, y: number, plane: number): number
	return x * 65536 + y * 4 + plane
end

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

type Route = {
	kind: string,
	transport: Transport,
	id: string,
	group: string,
	name: string,
	slack: number,
	spell: string,
	option: string?,
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

local function menu_id(prefix: string, t: Transport): string
	return `{ends_id(prefix, t)} {t.menu}`
end

local function lands_only(t: Transport): boolean
	return t.origin == nil and t.destination ~= nil
end

local function wild_allowed(o: Host.TransportTile?, to: Host.TransportTile, c: Check): boolean
	if c.into_wild then
		return true
	end
	if c.goal_in_ferox and Ferox.contains(to.x, to.y) and (o == nil or Transports.wilderness_level(o.x, o.y) == 0) then
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

local function gate_open(t: Transport, c: Check): boolean
	local note = read_note(t.note or "")
	if note == nil then
		warn_note(t.note or "")
		return (t.note or "") == "" and Transports.items_met(t, held(c))
	end
	return note_passed(note) or Transports.items_met({ items = note.items } :: any, held(c))
end

local note_named: { [string]: boolean } = {}

local function some_row_names(note: Note): boolean
	local known = note_named[note.text]
	if known ~= nil then
		return known
	end
	local named = false
	for _, kind in { "climb_gated", "link_gated", "transports" } do
		for _, t in ipairs(rows_of(kind)) do
			if t.note == note.text and t.items == note.items then
				named = true
			end
		end
	end
	note_named[note.text] = named
	return named
end

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

local function safe_row(route: Route, c: Check): boolean
	return safe(route.transport, c) and row_ok(route.transport, c)
end

local FAMILIES: { Family } = {
	{
		kinds = { "teleportation_spells", "teleportation_spells_home" },
		build = function(t: Transport): Route?
			if not lands_only(t) then
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
			if not lands_only(t) then
				return nil
			end
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
		usable = safe_row,
	},
	{
		kinds = { "teleportation_items" },
		build = function(t: Transport): Route?
			if not lands_only(t) then
				return nil
			end
			local item, label = Transports.split(t.name)
			if string.find(t.items, "%d+=%d+") == nil then
				return nil
			end
			return {
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
			if not lands_only(t) then
				return nil
			end
			local item, label = Transports.split(t.name)
			return {
				kind = "quetzal_whistle",
				setting = "quetzal_whistle",
				transport = t,
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
		usable = safe_row,
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
				id = menu_id("ride", t),
				group = "ride",
				name = if t.name ~= "" then t.name else (string.gsub(t.menu, "%s*%d+%s*$", "")),
				slack = Transports.RIDE_SLACK_TICKS,
				spell = "",
			}
		end,
		usable = safe_row,
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
				id = menu_id("ride", t),
				group = "ride",
				setting = "magic_carpets",
				name = t.name,
				slack = -Transports.CARPET_BONUS_TICKS,
				spell = "",
			}
		end,
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
		build = function(t: Transport): Route?
			if not both_ends(t) or string.find(t.menu, "Free-for-all", 1, true) ~= nil then
				return nil
			end
			local home = string.sub(t.menu, 1, 5) == "Home "
			return {
				kind = if home and is_house(t.origin :: Host.TransportTile) then "house_exit" else "ride",
				transport = t,
				id = menu_id("ride", t),
				group = if home then "house" else "portals",
				name = t.name,
				slack = Transports.PASSAGE_SLACK_TICKS,
				spell = "",
			}
		end,
		usable = safe_row,
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
		usable = function(route: Route, c: Check): boolean
			local offered = false
			for _, by in ipairs(lib("@lib/main/house").offers(route.option :: string)) do
				offered = offered or by == route.spell
			end
			return offered and safe(route.transport, c) and row_ok(route.transport, c) and not house_missing[route.id]
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
					id = menu_id("item_on", t),
					group = "passages",
					setting = if t.kind == "agility_shortcuts" then "shortcuts" else nil,
					name = t.name,
					slack = Transports.PASSAGE_SLACK_TICKS,
					spell = "",
				}
			end
			if string.sub(t.menu, 1, 8) ~= "Pay-toll" then
				return {
					kind = "ride",
					transport = t,
					id = menu_id("ride", t),
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

type Hub = {
	kind: string,
	module: string,
	radius: number,
	slack: number,
	label: (name: string) -> string?,
	object_start: boolean?,
	gate: (() -> (boolean, string?))?,
	end_usable: ((m: any, label: string) -> boolean)?,
	furniture: string?,
	go: (m: any, label: string, at: Loc?) -> (boolean, string?, boolean?),
}

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
		label = function(name: string): string?
			return string.match(name, "^%d+%.%s*(.+)$")
		end,
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
		label = function(name: string): string?
			if string.match(name, "^%u %u %u$") ~= nil then
				return (string.gsub(name, " ", ""))
			end
			return if name == "ZANARIS" then "zanaris" else nil
		end,
		gate = function(): (boolean, string?)
			return lib("@lib/main/interfaces/mainscreen/fairyring").can_use()
		end,
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
	members: { Transport },
	option: string,
}
type HubEnd = { tile: Host.TransportTile, label: string, name: string, duration: number, row: Transport }
type HubData = { starts: { HubStart }, ends: { HubEnd } }

local hub_data: { [string]: HubData } = {}

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
			if rows[i].menu == rows[j].menu and within(a, b, 4) then
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

local placed_ids: { [HubStart]: { number } } = {}
local grown_now: { [HubStart]: { offers: boolean?, at: number } } = {}

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

type Node = { x: number, y: number, plane: number, folded_y: number, under: boolean, mass: number }

type Edge = {
	to: number,
	cost: number,
	route: Route?,
	hub: Hub?,
	start: HubStart?,
	finish: HubEnd?,
}

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
		local blocked: { HubStart } = {}
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
					if within(start.rep, finish.tile, 8) then
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

local function endpoints(from: Tile, goal: Tile)
	local a = { x = from.x, y = from.y, plane = from.plane or 0 }
	local b = { x = goal.x, y = goal.y, plane = goal.plane or from.plane or 0 }
	return a, b
end

local function foot_route(from: Tile, goal: Tile, opts: Options): boolean
	local a, b = endpoints(from, goal)
	local route = Host.world_route(a, b, gated(opts.shortcuts).keys)
	return route == nil or route.reachable
end

local function planner_reaches(from: Tile, goal: Tile, opts: Options): boolean
	if gap(from, goal) > Transports.CONFIRM_WALK_TILES then
		return false
	end
	local a, b = endpoints(from, goal)
	local plan = Host.nav_plan(a, b, {
		near = Transports.CONFIRM_WALK_NEAR,
		allow_climbs = gated(opts.shortcuts).keys,
		shortcut_saving = Transports.SHORTCUT_MIN_SAVING_TILES,
	})
	return plan ~= nil and plan.reached == true
end

function Transports.walkable(from: Tile, goal: Tile, options: Options?): boolean
	local opts = options or {}
	return foot_route(from, goal, opts) or planner_reaches(from, goal, opts)
end

function Transports.choose(from: Tile, goal: Tile, options: Options?): Choice?
	local opts = options or {}
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
	check.goal_in_ferox = Ferox.contains(goal.x, goal.y)
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
	nodes[1] = { x = from.x, y = from.y, plane = from.plane or plane, folded_y = from.y, under = false, mass = 0 }
	nodes[2] = { x = goal.x, y = goal.y, plane = plane, folded_y = goal.y, under = false, mass = 0 }

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
	local origin, target = nodes[1], nodes[2]
	local on_foot = origin.mass ~= 0
		and target.mass ~= 0
		and origin.mass ~= target.mass
		and foot_route(from, goal, opts)
	local function walk_cost(a: Node, b: Node): number
		if (a.x == House.TILE.x and a.y == House.TILE.y) ~= (b.x == House.TILE.x and b.y == House.TILE.y) then
			return math.huge
		end
		if a.mass ~= 0 and b.mass ~= 0 and a.mass ~= b.mass and not (on_foot and a == origin and b == target) then
			return math.huge
		end
		local ticks = math.max(math.abs(a.x - b.x), math.abs(a.folded_y - b.folded_y)) * per_tile
		return if a.under ~= b.under or a.plane ~= b.plane then ticks + climb else ticks
	end

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
	local needed = opts.min_saving_ticks or (if rides_carpet then 0 else Transports.MIN_SAVING_TICKS)
	local direct = walk_cost(nodes[1], nodes[2])
	if direct ~= math.huge and direct - dist[2] < needed then
		return nil
	end
	if direct == math.huge and planner_reaches(from, goal, opts) then
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

function Transports.settle()
	Widgets.wait_within(function(): boolean
		return Host.game_state().game_state == GameState.LOGGED_IN
	end, Transports.SETTLE_TIMEOUT_MS, 200)
end

local function walk_near(tile: Host.TransportTile, near: number): boolean
	local here = lib("@lib/main/player").position()
	if within(here, tile, near) then
		return true
	end
	return lib("@lib/main/walker").walk(tile, { near = near, transports = false, plane = tile.plane })
end

local function wait_to_land(name: string, to: Host.TransportTile, timeout_ms: number): boolean
	if is_house(to) then
		local House = lib("@lib/main/house")
		if not Widgets.wait_for(House.inside, timeout_ms, 100) then
			return false
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
			local arrived = within(now, to, Transports.ARRIVED_NEAR)
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

local function wait_near(to: Host.TransportTile, near: number, timeout_ms: number): boolean
	local Player = lib("@lib/main/player")
	return Widgets.wait_within(function(): boolean
		return within(Player.position(), to, near)
	end, timeout_ms, 150)
end

local function wait_for_cast(t: Transport): (boolean, boolean?)
	local Player = lib("@lib/main/player")
	local timeout = Transports.LAND_TIMEOUT_MS
	local takes = (t.duration or 0) * 600 + Transports.SLOW_CAST_SLACK_MS
	if takes > timeout then
		timeout = takes
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
	log_saving(`casting {t.name}`, choice)
	local ok = (Magic.is_open() or Magic.open()) and Magic.interact(choice.spell, choice.option or "Cast")
	if not ok then
		return fail(t.name, "didn't work")
	end
	return wait_for_cast(t)
end

function Transports.minigame(choice: Choice): (boolean, boolean?)
	local t = choice.transport
	log_saving(t.name, choice)
	local ok, why = lib("@lib/main/interfaces/mainscreen/minigames").teleport(choice.spell, choice.option)
	if not ok then
		return fail(t.name, why or "couldn't start it")
	end
	return wait_for_cast(t)
end

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
			Widgets.wait_for(arrived, 5000, 150)
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

function Transports.hub(choice: Choice): (boolean, boolean?)
	local t = choice.transport :: any
	local hub = HUB_BY_KIND[choice.kind]
	local from, to = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local label = t.label :: string
	local id = choice.id or hub_id(choice.kind, from, label)
	log_saving(`{choice.kind} to {label}`, choice)
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

function Transports.ride(choice: Choice): (boolean, boolean?)
	local t = choice.transport
	local from, to = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local id = choice.id or ends_id("ride", t)
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
	log_saving(`boarding {t.menu}`, choice)
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
	local npc = Npcs.nearest(target, from)
	local loc = if npc == nil then Objects.nearest(target, from) else nil
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
			local done = if npc ~= nil then Npcs.interact(npc, option) else Objects.interact(loc, option)
			if done then
				return true
			end
		end
		return false
	end
	local Chat = lib("@lib/main/interfaces/chatbox/chat")
	local seen = (Chat.last_message() or { uid = 0 }).uid
	if not clicked then
		clicked = click_target()
	end
	if not clicked then
		return fail(id, `none of the options {table.concat(options, " / ")} could be clicked`)
	end
	local ticket_tried = false
	local deadline = time() + Transports.RIDE_TIMEOUT_MS
	local underground = start.y >= 6400
	local last_said: string? = nil
	local quiet_since = time()
	local clicked_at = time()
	local answered = false
	while time() < deadline do
		local now = Player.position()
		if now ~= nil then
			local moved = gap(now, start)
			local near_destination = gap(now, to) <= Transports.ARRIVED_NEAR + 10
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
				local voyage = time() + Transports.RIDE_VOYAGE_MS
				while time() < voyage and gap(now, to) > Transports.ARRIVED_NEAR + 10 do
					sleep(Transports.RIDE_POLL_MS)
					now = Player.position() or now
				end
				Transports.settle()
				if t.kind == "magic_carpets" then
					Widgets.wait_within(function(): boolean
						return Player.pose() ~= Transports.CARPET_POSE
					end, Transports.RIDE_VOYAGE_MS, Transports.RIDE_POLL_MS)
					Player.wait_server_still(Transports.RIDE_VOYAGE_MS)
				end
				now = Player.position() or now
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
		local can_continue = ChatOptions.contains_continue()
		if (choices ~= nil and #choices > 0) or can_continue then
			quiet_since = time()
			answered = true
		end
		local silent_ms = if t.kind == "magic_carpets" then Transports.CARPET_SILENT_MS else Transports.RIDE_SILENT_MS
		if last_said == nil and not answered and time() - clicked_at > silent_ms then
			return fail(id, "nothing was said and nothing happened")
		end
		if last_said ~= nil and time() - quiet_since > Transports.RIDE_QUIET_MS then
			Log.log("Transports", `{id}: the conversation ended and nothing happened; last said "{last_said}"`)
			return false, true
		end
		if choices ~= nil and #choices > 0 then
			local pick = Transports.dialogue_pick(choices, hints)
			if pick == nil then
				Log.log("Transports", `{id}: no option to pick among {ChatOptions.to_string(choices) or "?"}`)
				return false
			end
			if not ChatOptions.select(pick) and ChatOptions.find(pick) ~= nil then
				ChatOptions.select(pick, nil, 0)
			end
		elseif can_continue then
			ChatOptions.continue_chat()
		end
		sleep(Transports.RIDE_POLL_MS)
	end
	return fail(id, "the trip didn't happen")
end

function Transports.sail(choice: Choice): boolean
	local t = choice.transport
	local dock, to = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local label = string.match(t.name, "^%w+:%s*(.+)$")
	local id = choice.id or t.name
	if label == nil then
		return fail(id, "no destination name in the data")
	end
	local option = string.match(t.menu, "^(%S+)")
	if option == nil then
		return fail(id, "the data doesn't say what to say to the trader")
	end
	local before = lib("@lib/main/player").position()
	if before == nil then
		return false
	end
	log_saving(`sailing to {label}`, choice)
	if gap(before, to) > Transports.ABOARD_NEAR then
		if not walk_near(dock, Transports.DOCK_NEAR) then
			return fail(id, "couldn't walk to the dock")
		end
		local opened, why = Chartering.open(option, dock)
		if not opened then
			return fail(id, why or "the destination list didn't open")
		end
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

function Transports.pass(choice: Choice): boolean
	local t = choice.transport
	local o, d = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local id = choice.id or ends_id("link", t)
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

local function plain(text: string): string
	local t = string.lower((string.gsub(text, "<[^>]*>", "")))
	t = string.gsub(t, "['`]", "")
	t = string.gsub(t, "\u{2019}", "")
	t = string.gsub(t, "^%s*%d+[%.:]%s*", "")
	t = string.gsub(t, "[%.%s]+$", "")
	return t
end

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

local function item_options(module: any, slot: number): { string }
	local Minimenu = lib("@lib/main/interfaces/minimenu")
	local held = module.item(slot)
	local name = if held then string.lower(Host.item_name(held.id) or "") else ""
	module.hover_slot(slot)
	local waited = 0
	while waited <= 800 do
		local entries = Minimenu.entries()
		local about = entries ~= nil
			and entries[1] ~= nil
			and (name == "" or string.find(string.lower(entries[1].target), name, 1, true) ~= nil)
		if entries ~= nil and #entries > 1 and about then
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
	local dialogue_parent: string? = nil
	local clicked_at = 0
	local Minimenu = lib("@lib/main/interfaces/minimenu")
	local direct = direct_option(item_options(module, slot), label)
	if direct ~= nil then
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
		else
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
			local text: string? = nil
			for i = step, #parts do
				text = best_line(texts, parts[i])
				if text ~= nil then
					step = i + 1
					break
				end
			end
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

function Transports.teleport_item(name: string): (boolean, boolean?)
	for _, t in ipairs(rows_of("teleportation_items")) do
		if t.name == name then
			local item, destination = Transports.split(t.name)
			return Transports.use_item({
				kind = "item",
				transport = t,
				id = t.name,
				spell = item,
				option = destination,
				ticks = t.duration,
				saved = 0,
			})
		end
	end
	Log.log("Transports", `no teleport item called {name} in the data`)
	return false, true
end

function Transports.failed_lately(choice: Choice): boolean
	return not not_failed(choice.id or choice.transport.name)
end

function Transports.whistle(choice: Choice): (boolean, boolean?)
	local Quetzal = lib("@lib/main/interfaces/mainscreen/quetzal")
	local t = choice.transport
	local label = choice.option :: string
	local to = t.destination :: Host.TransportTile
	log_saving(t.name, choice)
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

function Transports.house(choice: Choice): (boolean, boolean?)
	local House = lib("@lib/main/house")
	local t = choice.transport
	local furniture, label = choice.spell, choice.option :: string
	local id = choice.id or ends_id("house", t)
	if not House.inside() then
		return fail(id, "not in the house")
	end
	log_saving(`house {furniture} to {label}`, choice)
	local started, why, pointless = House.start_teleport(furniture, label)
	if started then
		return wait_to_land(id, t.destination :: Host.TransportTile, Transports.HUB_TIMEOUT_MS)
	end
	if pointless then
		house_missing[id] = true
		fail(id, why or "it isn't there")
		return false, true
	end
	return fail(id, why or "couldn't use it")
end

function Transports.house_exit(choice: Choice): boolean
	Log.log("Transports", "leaving the house")
	if not lib("@lib/main/house").leave() then
		return fail(choice.id or "house exit", "couldn't leave")
	end
	Transports.settle()
	return true
end

function Transports.canoe(choice: Choice): (boolean, boolean?)
	local Canoe = lib("@lib/main/interfaces/mainscreen/canoe")
	local t = choice.transport
	local from = t.origin :: Host.TransportTile
	log_saving(`canoe to {t.name}`, choice)
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

function Transports.scroll_book(choice: Choice): (boolean, boolean?)
	local Scrollbook = lib("@lib/main/interfaces/mainscreen/scrollbook")
	local t = choice.transport
	log_saving(t.name, choice)
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

local function runner(name: string): (Choice) -> (boolean, boolean?)
	return function(choice: Choice): (boolean, boolean?)
		return (Transports :: any)[name](choice)
	end
end

Transports.runners = {
	minigame = runner("minigame"),
	scroll_book = runner("scroll_book"),
	quetzal_whistle = runner("whistle"),
	spell = runner("cast"),
	item = runner("use_item"),
	charter = runner("sail"),
	link = runner("pass"),
	lever = runner("pull"),
	ride = runner("ride"),
	house = runner("house"),
	house_exit = runner("house_exit"),
	item_on = runner("use_on"),
	canoe = runner("canoe"),
} :: { [string]: (Choice) -> (boolean, boolean?) }
for _, hub in ipairs(HUBS) do
	Transports.runners[hub.kind] = runner("hub")
end

local function already_there(choice: Choice): boolean
	local to = choice.transport.destination
	if to == nil then
		return false
	end
	local now = lib("@lib/main/player").position()
	return within(now, to, Transports.ARRIVED_NEAR)
end

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
