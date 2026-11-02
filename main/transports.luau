--!strict
-- Transports the walker can use, from the data the loader downloaded (`Host.transports`): teleport spells, charter ships, gates and the magic mushtrees.
-- `Transports.choose` weighs walking against each of them; `Transports.travel` uses the best one. The walker calls `travel` before it walks.
local Host = require("@lib/host")
local sleep = Host.sleep
local time = Host.time
local Chartering = require("@lib/main/interfaces/mainscreen/chartering")
local Log = require("@lib/utils/log")
local Random = require("@lib/utils/math/random")

type Transport = Host.Transport
type Tile = { x: number, y: number, plane: number? }

local Transports = {}

-- Teleports are used by the walker unless this is false (or a walk passes `transports = false`).
Transports.ENABLED = true
-- A teleport is only worth the runes if it saves this many game ticks.
Transports.MIN_SAVING_TICKS = 30
-- Walking at a run, with a detour, for the tiles apart.
Transports.WALK_TICKS_PER_TILE = 0.6
-- The cast and the wait before the spell takes effect, besides the spell's own duration.
Transports.CAST_SLACK_TICKS = 3
-- How long after the cast we wait to land.
Transports.LAND_TIMEOUT_MS = 8000
-- A teleport has landed when it moved us at least this far.
Transports.LAND_DISTANCE = 6
-- How long after landing we wait for the scene to load.
Transports.SETTLE_TIMEOUT_MS = 10000
-- A spell that failed isn't tried again for this long.
Transports.RETRY_AFTER_MS = 5 * 60 * 1000
-- A charter trip: the wait for the trader's menu and the boat, besides the trip's own duration.
Transports.CHARTER_SLACK_TICKS = 6
-- How long to wait for the charter interface (see `@lib/main/interfaces/mainscreen/chartering`) to open, and for the boat to arrive after a destination is chosen.
Transports.CHARTER_OPEN_TIMEOUT_MS = 8000
Transports.CHARTER_SAIL_TIMEOUT_MS = 15000
-- Leaving the boat: the gangplank's name, how long to try, and how near the dock's tile counts as arrived.
Transports.GANGPLANK = "Gangplank"
Transports.CROSS_TIMEOUT_MS = 20000
Transports.ARRIVED_NEAR = 4
-- A hop through a gate (a toll barrier): the wait for the object, and for the step through.
Transports.LINK_SLACK_TICKS = 2
Transports.LINK_TIMEOUT_MS = 8000
Transports.LINK_ARRIVED_NEAR = 1
-- Every kind of transport is tried this many times (with a pause between) before it counts as failed, and a failed one is left alone for `RETRY_AFTER_MS`.
Transports.ATTEMPTS = 3
Transports.RETRY_PAUSE_MS = 1500
-- A charter retried from this close to its destination is taken to be aboard the boat already.
Transports.ABOARD_NEAR = 15
-- A ride on the magic mushtrees: the wait for the list to open and for the trip, and the ticks added for the click and the list.
Transports.MUSHTREE_SLACK_TICKS = 4
Transports.MUSHTREE_TIMEOUT_MS = 10000
-- A trip of a network of separate starts and ends (quetzals, spirit trees, gnome gliders, fairy rings): the wait for it to land, and how near the start tile is walked to.
Transports.HUB_TIMEOUT_MS = 20000
-- A boat, ferry or train cart (whole trips from a tile to a tile, made by clicking an NPC or an object and following the dialogue): ticks added to the data's duration, how long the
-- dialogue and the trip may take, and the pause between looks.
Transports.BOAT_SLACK_TICKS = 8
Transports.BOAT_TIMEOUT_MS = 45000
Transports.BOAT_POLL_MS = 200
-- How long after a conversation has ended without a trip before it counts as refused.
Transports.BOAT_QUIET_MS = 8000
-- How long a voyage that has begun may take to bring the player to the destination.
Transports.BOAT_VOYAGE_MS = 40000
-- How far (tiles) from where it was clicked the player has to be for a boat or cart to have taken them: walking to the NPC is not that.
Transports.BOAT_LAND_DISTANCE = 25
-- How long after the click with nothing said and no trip before the click counts as having done nothing.
Transports.BOAT_SILENT_MS = 25000
-- Buying a cart ticket from the conductor: how long it may take, how long after "Buy" the talk is over, and how long a quiet talk before it counts as gone nowhere.
Transports.TICKET_TIMEOUT_MS = 40000
Transports.TICKET_DONE_MS = 2500
Transports.TICKET_IDLE_MS = 8000
-- A pause (min, max in ms) after a boat lands before the gangplank is crossed: the gangplank doesn't take the click in the first moments after the boat arrives.
Transports.BOAT_DOCK_PAUSE_MS = { 2500, 4000 }
-- Finding the NPC of a boat by asking (see `Transports.board`): how far from the boarding tile to look, and at how many of the nearest to look.
Transports.BOAT_NPC_RANGE = 12
Transports.BOAT_NPC_LOOKS = 8
-- The quests a kind of transport needs besides those its data rows name (the mushtree file names none): Bone Voyage opens Fossil Island and its trees.
Transports.EXTRA_QUESTS = { magic_mushtrees = { "Bone Voyage" } } :: { [string]: { string } }
-- Agility shortcuts (hops over obstacles; the data's `agility_shortcuts`) are used by the walker unless this is false (or a walk passes `shortcuts = false`).
Transports.SHORTCUTS = true
-- A shortcut has to save at least this many tiles over walking round, or it isn't taken.
Transports.SHORTCUT_MIN_SAVING_TILES = 10
-- A route is planned over these many hops at most: spell or ship, walk, spell or ship, ...
Transports.MAX_HOPS = 4
-- How long what the planner found out about a transport (its requirements) is kept, so a walk with several hops doesn't check them again.
Transports.VALID_FOR_MS = 20 * 1000
-- Ticks added for a walk that changes plane (a ladder or stairs on the way).
Transports.PLANE_CHANGE_TICKS = 10
-- The inventory's item container, and how far from the dock (in tiles) the walk to the trader may stop.
Transports.INVENTORY = 93
Transports.DOCK_NEAR = 3

export type Options = {
	-- spell names (as in the data, like "Varrock Teleport") never to use
	exclude: { [string]: boolean }?,
	-- overrides `MIN_SAVING_TICKS`
	min_saving_ticks: number?,
	-- whether agility shortcuts join landmasses for the walk (default `Transports.SHORTCUTS`)
	shortcuts: boolean?,
}

export type Choice = {
	-- "spell", "charter", "link" or "mushtree"
	kind: string,
	transport: Transport,
	-- a spell's name in the game and the menu option to cast it with (nil: the default one); empty for a charter
	spell: string,
	option: string?,
	-- ticks the teleport and the walk after it are expected to take, and ticks saved against walking
	ticks: number,
	saved: number,
}

type Spell = {
	transport: Transport,
	spell: string,
	option: string?,
}

type Trip = {
	transport: Transport,
	-- the key the interface shows before the destination ("1" in "1: Brimhaven"), and the destination's name
	key: string,
	label: string,
}

-- A ride from one mushtree to another, with the destination's name as the list shows it ("Sticky Swamp").
type Ride = {
	transport: Transport,
	label: string,
}

local rides: { Ride }? = nil
local spells: { Spell }? = nil
local trips: { Trip }? = nil
local links: { Transport }? = nil
local failed: { [string]: number } = {}

-- "Varrock Teleport: Grand Exchange" is the spell "Varrock Teleport" cast with the option "Grand Exchange", and "Teleport to House (Inside)" the option "Inside".
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

local function load_spells(): { Spell }
	if spells then
		return spells
	end
	local data = Host.transports()
	local found: { Spell } = {}
	for _, t in ipairs(data.transports) do
		if string.sub(t.kind, 1, 20) == "teleportation_spells" and t.origin == nil and t.destination ~= nil then
			local spell, option = Transports.split(t.name)
			table.insert(found, { transport = t, spell = spell, option = option })
		end
	end
	if #found > 0 then
		spells = found
	end
	local names: { [string]: boolean } = {}
	local distinct = 0
	for _, s in ipairs(found) do
		if not names[s.spell] then
			names[s.spell] = true
			distinct += 1
		end
	end
	Log.log("Transports", `{distinct} teleport spells in {#found} data rows (data: {data.source})`)
	return found
end

-- The charter ship trips: fixed dock to fixed dock, with the destination's key and name from the `Display info` ("1: Brimhaven").
local function load_trips(): { Trip }
	if trips then
		return trips
	end
	local found: { Trip } = {}
	for _, t in ipairs(Host.transports().transports) do
		if t.kind == "charter_ships" and t.origin ~= nil and t.destination ~= nil then
			local key, label = string.match(t.name, "^(%w+):%s*(.+)$")
			if key ~= nil and label ~= nil then
				table.insert(found, { transport = t, key = key, label = label })
			end
		end
	end
	if #found > 0 then
		trips = found
	end
	Log.log("Transports", `{#found} charter trips`)
	return found
end

-- The gates and barriers the loader kept (`kind` "transports"): a short hop from a tile on one side to a tile on the other.
local function load_links(): { Transport }
	if links then
		return links
	end
	local found: { Transport } = {}
	for _, t in ipairs(Host.transports().transports) do
		if t.kind == "transports" and t.origin ~= nil and t.destination ~= nil then
			table.insert(found, t)
		end
	end
	if #found > 0 then
		links = found
	end
	Log.log("Transports", `{#found} gates and barriers`)
	return found
end

-- The wilderness level of a tile, 0 outside it.
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

local warned_clock = false
-- varbit and varp reads of the plan being made (each is an IPC round trip, and many rows test the same few)
local memo: { [string]: number | boolean }? = nil

local function read_var(kind: string, id: number): number?
	local key = kind .. id
	if memo ~= nil then
		local known = memo[key]
		if known ~= nil then
			return if known == false then nil else known :: number
		end
	end
	local value = if kind == "varbit" then Host.varbit(id) else Host.varp(id)
	if memo ~= nil then
		memo[key] = if value == nil then false else value
	end
	return value
end

-- Whether the varbit and varp tests of a row hold. They pick the row that applies (the spellbook, the diary, the house's place).
local function holds(t: Transport): boolean
	for _, list in { t.varbits, t.varps } do
		for _, c in ipairs(list) do
			if c.op == "@" then
				-- a wall-clock countdown (the home teleport): the clock the varp counts from isn't known yet
				if not warned_clock then
					warned_clock = true
					Log.log(
						"Transports",
						"cooldown tests (id@minutes) aren't supported yet: those transports are skipped"
					)
				end
				return false
			end
			local value = read_var(if list == t.varbits then "varbit" else "varp", c.id)
			if value == nil then
				return false
			end
			local ok = if c.op == "="
				then value == c.value
				elseif c.op == ">" then value > c.value
				elseif c.op == "<" then value < c.value
				elseif c.op == "&" then bit32.band(value, c.value) == c.value
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

local item_ids: { [string]: { number } }? = nil

-- The ids of a named item group (`COINS`), from the data's `item-variations.tsv`; a number names itself.
local function ids_of(name: string): { number }?
	local number = tonumber(name)
	if number ~= nil then
		return { number }
	end
	if item_ids == nil then
		local map: { [string]: { number } } = {}
		for _, group in ipairs(Host.transports().items) do
			map[string.upper(group.name)] = group.ids
		end
		item_ids = map
	end
	return (item_ids :: { [string]: { number } })[string.upper(name)]
end

local warned_items: { [string]: boolean } = {}

-- How many of the items in `counts` (item id -> amount) a token like `COINS=2500` or `1359=1` asks for are held, or nil when the token isn't one we can count
-- (a named group we don't know, an equipment slot such as `HEADSLOT=0`, an unlock such as `UNLOCK_XERICS_HONOUR=1`).
local function token_met(token: string, counts: { [number]: number }): boolean?
	local name, quantity = string.match(token, "^([%w_]+)=(%d+)$")
	if name == nil or quantity == nil then
		return nil
	end
	local ids = if string.sub(name, 1, 7) == "UNLOCK_" or string.sub(name, -4) == "SLOT" then nil else ids_of(name)
	if ids == nil then
		return nil
	end
	local have = 0
	for _, id in ipairs(ids) do
		have += counts[id] or 0
	end
	return have >= tonumber(quantity) :: number
end

-- Whether the items a transport needs are held in the inventory: `Items` is any-of groups (`|`) of all-of items (`&`), `AND` binding tighter.
-- `counts` is the inventory's amounts by item id unless given. A token we can't count (unlocks, equipment slots) makes its group not met, and is logged once.
function Transports.items_met(t: Transport, counts: { [number]: number }?): boolean
	local text = string.upper(string.gsub(t.items, "%s", ""))
	if text == "" then
		return true
	end
	local have = counts
	if have == nil then
		local inventory = Host.item_container(Transports.INVENTORY)
		if inventory == nil then
			return false
		end
		have = {}
		for _, item in ipairs(inventory) do
			if item.id > 0 then
				have[item.id] = (have[item.id] or 0) + item.quantity
			end
		end
	end
	text = string.gsub(string.gsub(text, "&&", "&"), "||", "|")
	for alternative in string.gmatch(text .. "|", "([^|]*)|") do
		local all = alternative ~= ""
		for token in string.gmatch(alternative, "[^&]+") do
			local met = token_met(token, have :: { [number]: number })
			if met == nil and not warned_items[token] then
				warned_items[token] = true
				Log.log("Transports", `can't check the item "{token}": transports that need it are skipped`)
			end
			if not met then
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

-- Whether the quests a transport needs are done, from the quests' own progress variables (`Quests`; the quest list is the fallback). Asked last.
function Transports.quests_done(t: Transport): boolean
	if #t.quests == 0 then
		return true
	end
	local Journal = (require :: any)("@lib/main/interfaces/gametabs/journal")
	for _, name in ipairs(t.quests) do
		if not Journal.is_quest_complete(name) then
			return false
		end
	end
	return true
end

-- Game ticks to walk between two tiles: the longer axis, a detour and running.
function Transports.walk_ticks(a: Tile, b: Tile): number
	return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) * Transports.WALK_TICKS_PER_TILE
end

-- Whether a transport hasn't failed lately.
-- The mushtree rides: every tree's start tile to every other tree, which the loader worked out from the file's separate starts and ends ("3. Sticky Swamp" is a destination's name).
local function load_rides(): { Ride }
	if rides then
		return rides
	end
	local found: { Ride } = {}
	for _, t in ipairs(Host.transports().transports) do
		if t.kind == "magic_mushtrees" and t.origin ~= nil and t.destination ~= nil then
			local label = string.match(t.name, "^%d+%.%s*(.+)$")
			if label ~= nil then
				table.insert(found, { transport = t, label = label })
			end
		end
	end
	if #found > 0 then
		rides = found
	end
	Log.log("Transports", `{#found} mushtree rides`)
	return found
end

local function not_failed(id: string): boolean
	local at = failed[id]
	return at == nil or time() - at > Transports.RETRY_AFTER_MS
end

-- A charter trip's key in the list of failures: its dock and destination.
local function charter_id(t: Transport): string
	local o = t.origin :: Host.TransportTile
	return `charter {o.x},{o.y} {string.match(t.name, "^%w+:%s*(.+)$") or t.name}`
end

-- A mushtree ride's key in the list of failures: its start tile and destination.
local function ride_id(t: Transport): string
	local o = t.origin :: Host.TransportTile
	return `mushtree {o.x},{o.y} {string.match(t.name, "^%d+%.%s*(.+)$") or t.name}`
end

-- The landmass numbers of tiles (`Host.landmasses`), kept: they only change with a game update. 0 or nil: unknown, so walking is allowed.
local landmass_of: { [string]: number } = {}

local function landmasses(points: { Tile })
	local missing: { { x: number, y: number, plane: number } } = {}
	local keys: { string } = {}
	for _, p in ipairs(points) do
		local key = `{p.x},{p.y},{p.plane or 0}`
		if landmass_of[key] == nil then
			landmass_of[key] = 0
			table.insert(missing, { x = p.x, y = p.y, plane = p.plane or 0 })
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
	return landmass_of[`{p.x},{p.y},{p.plane or 0}`] or 0
end

-- Landmasses joined by a way across the player can use (see `usable_links`), for the route being chosen: a landmass number to the one it was joined into.
local merged: { [number]: number } = {}

local function find(landmass_number: number): number
	local root = landmass_number
	while merged[root] ~= nil do
		root = merged[root]
	end
	return root
end

-- The ways across the player can use now that ask for something, as rows from the data that `allowed_climbs` lets through: the agility shortcuts (unless turned off), and the links on one
-- plane (a stile, a tree to chop, a door that is an object) of 2 to `MAX_LINK_HOP` tiles. The links that ask for nothing are joined in the landmasses already. Kept for `VALID_FOR_MS`.
Transports.MAX_LINK_HOP = 15
local link_rows: { [string]: { rows: { Transport }, at: number } } = {}
local function usable_links(shortcuts: boolean?): { Transport }
	local on = if shortcuts ~= nil then shortcuts else Transports.SHORTCUTS
	local cache_key = if on then "with" else "without"
	local kept = link_rows[cache_key]
	if kept ~= nil and time() - kept.at < Transports.VALID_FOR_MS then
		return kept.rows
	end
	local allowed_keys: { [string]: boolean } = {}
	for _, key in ipairs(Transports.allowed_climbs({ shortcuts = on })) do
		allowed_keys[key] = true
	end
	local rows: { Transport } = {}
	for _, t in ipairs(Host.transports().transports) do
		if t.origin ~= nil and t.destination ~= nil then
			local o, d = t.origin, t.destination
			local hop = math.max(math.abs(o.x - d.x), math.abs(o.y - d.y))
			local across = t.kind == "shortcut_gated"
				or (
					t.kind == "climb_gated"
					and o.plane == d.plane
					and (o.y >= Transports.UNDERGROUND) == (d.y >= Transports.UNDERGROUND)
					and hop >= 2
					and hop <= Transports.MAX_LINK_HOP
				)
			if across and allowed_keys[`{o.x},{o.y},{o.plane}>{d.x},{d.y},{d.plane}`] then
				table.insert(rows, t)
			end
		end
	end
	link_rows[cache_key] = { rows = rows, at = time() }
	return rows
end

-- The underground (dungeons) is the same map 6,400 tiles north, entered by ladders, stairs and caves.
Transports.UNDERGROUND = 6400

-- Ticks to walk from `a` to `b`: the straight-line estimate when they are on the same landmass (or one isn't known), and infinite when they are on different ones.
-- Between the surface and the underground it is the distance on the folded map (the underground's tiles taken 6,400 south) with the cost of a climb: the way in is a ladder,
-- stairs or cave the planner finds, so landmasses don't apply.
local function walk_cost(a: Tile, b: Tile): number
	local under_a, under_b = a.y >= Transports.UNDERGROUND, b.y >= Transports.UNDERGROUND
	if under_a ~= under_b then
		local fa = if under_a then { x = a.x, y = a.y - Transports.UNDERGROUND, plane = a.plane } else a
		local fb = if under_b then { x = b.x, y = b.y - Transports.UNDERGROUND, plane = b.plane } else b
		return Transports.walk_ticks(fa, fb) + Transports.PLANE_CHANGE_TICKS
	end
	local la, lb = landmass(a), landmass(b)
	if la ~= 0 and lb ~= 0 and find(la) ~= find(lb) then
		return math.huge
	end
	local extra = if (a.plane or 0) ~= (b.plane or 0) then Transports.PLANE_CHANGE_TICKS else 0
	return Transports.walk_ticks(a, b) + extra
end

-- Whether a transport is usable now, apart from where it goes: its requirements. A spell also has to be castable (the game's own check covers its runes).
type Check = { levels: { [string]: number }?, here_wild: number, checked: { [string]: boolean } }

local function spell_ok(s: Spell, c: Check, Magic: any): boolean
	local t = s.transport
	local to = t.destination :: Host.TransportTile
	if
		not not_failed(t.name)
		or Transports.wilderness_level(to.x, to.y) ~= 0
		or c.here_wild > (t.wilderness or 20)
		or not holds(t)
		or not Transports.skills_met(t, c.levels)
	then
		return false
	end
	-- castability is a property of the spell, shared by its rows
	local known = c.checked[s.spell]
	if known == nil then
		local spell = Magic.spell(s.spell)
		known = spell ~= nil and Magic.can_cast(spell)
		c.checked[s.spell] = known
	end
	return known and Transports.quests_done(t)
end

local function trip_ok(trip: Trip, c: Check): boolean
	local t = trip.transport
	local to = t.destination :: Host.TransportTile
	return not_failed(charter_id(t))
		and Transports.wilderness_level(to.x, to.y) == 0
		and c.here_wild <= (t.wilderness or 20)
		and holds(t)
		and Transports.skills_met(t, c.levels)
		and Transports.quests_done(t)
		and Transports.items_met(t)
end

-- Whether a mushtree ride can be taken now: the usual requirements and the quests the kind needs besides (see `EXTRA_QUESTS`). Whether the destination tree is grown is seen in the list, at the ride.
local function ride_ok(ride: Ride, c: Check): boolean
	local t = ride.transport
	if
		not (not_failed(ride_id(t)) and holds(t) and Transports.skills_met(t, c.levels) and Transports.quests_done(t))
	then
		return false
	end
	local Journal = (require :: any)("@lib/main/interfaces/gametabs/journal")
	for _, name in ipairs(Transports.EXTRA_QUESTS[t.kind] or {}) do
		if not Journal.is_quest_complete(name) then
			return false
		end
	end
	return true
end

-- A link's key in the list of failures: its two tiles.
local function link_id(t: Transport): string
	local o, d = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	return `link {o.x},{o.y} {d.x},{d.y}`
end

local warned_notes: { [string]: boolean } = {}

-- Whether a gate can be passed now. The rows have no requirement columns, but the comment above them can say one: `(varbit:217=7?ECTO_TOKEN=2)` means the gate is free
-- once the quest that keeps its progress in varbit 217 is complete (a barrier's object turns into a free "Pass" one then), and otherwise needs the items after the `?`.
-- A gate without such a note counts as passable only if its row asks for nothing.
local function link_ok(t: Transport, c: Check): boolean
	if not not_failed(link_id(t)) or not Transports.skills_met(t, c.levels) or not Transports.quests_done(t) then
		return false
	end
	local note = t.note or ""
	local varbit, value, items = string.match(note, "varbit:(%d+)=(%d+)%?([%w_=&|]+)")
	if varbit == nil then
		if note ~= "" and string.find(note, "%?") and not warned_notes[note] then
			warned_notes[note] = true
			Log.log("Transports", `can't read the gate's requirement "{note}": those gates are skipped`)
		end
		return t.items == "" or Transports.items_met(t)
	end
	local Quests = (require :: any)("@lib/main/quests")
	local free = Quests.complete_by_varbit(tonumber(varbit) :: number)
	if free == nil then
		-- no quest keeps its progress there: the note's own value
		local now = read_var("varbit", tonumber(varbit) :: number)
		free = now ~= nil and now >= (tonumber(value) :: number)
	end
	return free or Transports.items_met({ items = items } :: any)
end

type Node = { x: number, y: number, plane: number }
-- The networks whose data lists the starts and the ends apart (the quetzals, spirit trees, gnome gliders and fairy rings): every start goes to every end that is not within `radius` tiles
-- of it. They are paired here as the route is chosen, not expanded in the data (the fairy rings alone would be 3,000 trips). A start is the tile to stand on beside a tree, ring or pilot;
-- the rows around one structure are one start. An end is a name in the interface (a place, a landing site, a ring's code).
type Hub = {
	kind: string,
	-- the interface module, required when the network is used
	module: string,
	-- starts and ends closer than this are the same place
	radius: number,
	-- ticks added to the data's duration for opening the interface and choosing
	slack: number,
	-- the destination's name for the interface, from the end's `Display info` (nil: not a destination to pick)
	label: (name: string) -> string?,
	-- whether a start is an object whose current form must offer the click (a spirit tree planted in a farming patch is a patch until it has grown)
	object_start: boolean?,
	-- whether the network can be used at all now, and why not
	gate: (() -> (boolean, string?))?,
	-- chooses the destination in the interface, walking to nothing (we stand beside it): false and why when it didn't work
	go: (m: any, label: string) -> (boolean, string?),
}

local function trip_name(name: string): string?
	local label = string.match(name, "^%d+:%s*(.+)$") or name
	return if label ~= "" then label else nil
end

local HUBS: { Hub } = {
	{
		kind = "quetzals",
		module = "@lib/main/interfaces/mainscreen/quetzal",
		radius = 5,
		slack = 8,
		label = trip_name,
		go = function(m: any, label: string): (boolean, string?)
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
		radius = 5,
		slack = 8,
		label = trip_name,
		go = function(m: any, label: string): (boolean, string?)
			if not m.open(nil, false) then
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
		label = trip_name,
		go = function(m: any, label: string): (boolean, string?)
			if not m.open(nil, false) then
				return false, "the list didn't open"
			end
			if m.select(label) == nil then
				m.close()
				return false, `{label} isn't in the list`
			end
			return true, nil
		end,
	},
	{
		kind = "gnome_gliders",
		module = "@lib/main/interfaces/mainscreen/gnomeglider",
		radius = 6,
		slack = 8,
		label = trip_name,
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
		radius = 6,
		slack = 12,
		-- "A I Q" is the code AIQ; "ZANARIS" the ring's own option; the data also has a chain of several codes, which isn't a single trip
		label = function(name: string): string?
			local code = string.match(name, "^(%u) (%u) (%u)$")
			if code ~= nil then
				return (string.gsub(name, " ", ""))
			end
			return if name == "ZANARIS" then "zanaris" else nil
		end,
		gate = function(): (boolean, string?)
			local m = (require :: any)("@lib/main/interfaces/mainscreen/fairyring")
			return m.can_use()
		end,
		go = function(m: any, label: string): (boolean, string?)
			-- travel raises when the rings can't be used, and returns the way it went or nil when nothing happened
			local ok, way = pcall(m.travel, label)
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
	row: Transport,
	-- every row of the structure: the same start can be listed more than once with different requirements (a cart that costs coins until a quest and is free after it)
	members: { Transport },
	option: string,
	object: number?,
}
type HubEnd = { tile: Host.TransportTile, label: string, name: string, duration: number, row: Transport }
type HubData = { starts: { HubStart }, ends: { HubEnd } }

local hub_data: { [string]: HubData } = {}

-- The starts of a network, one for each structure (the rows within 4 tiles of each other with the same click are one), and its ends. Read once.
local function load_hub(h: Hub): HubData
	local kept = hub_data[h.kind]
	if kept ~= nil then
		return kept
	end
	local rows: { Transport } = {}
	local ends: { HubEnd } = {}
	-- the player's house: the data puts it where the "Teleport to House" spell lands, a stand-in for an instance that is somewhere else and laid out by the player; what the data says
	-- is in the house (a ring, a spirit tree) is neither known to be built nor where it stands, so it isn't a place to go to
	local house: { [string]: boolean } = {}
	for _, t in ipairs(Host.transports().transports) do
		if t.destination ~= nil and string.sub(t.name, 1, 17) == "Teleport to House" then
			house[`{t.destination.x},{t.destination.y},{t.destination.plane}`] = true
		end
	end
	local function in_house(tile: Host.TransportTile): boolean
		return house[`{tile.x},{tile.y},{tile.plane}`] == true
	end
	for _, t in ipairs(Host.transports().transports) do
		if t.kind == h.kind then
			if t.origin ~= nil and t.destination == nil then
				if not in_house(t.origin) then
					table.insert(rows, t)
				end
			elseif t.origin == nil and t.destination ~= nil and not in_house(t.destination) then
				local label = h.label(t.name)
				if label ~= nil then
					table.insert(ends, {
						tile = t.destination,
						label = label,
						name = t.name,
						duration = t.duration,
						row = t,
					})
				end
			end
		end
	end
	-- one start for each group of rows that are near each other with the same click: a union of neighbours
	local group: { number } = {}
	for i = 1, #rows do
		group[i] = i
	end
	local function find(i: number): number
		while group[i] ~= i do
			group[i] = group[group[i]]
			i = group[i]
		end
		return i
	end
	for i = 1, #rows do
		for j = i + 1, #rows do
			local a, b = rows[i].origin :: Host.TransportTile, rows[j].origin :: Host.TransportTile
			if
				rows[i].menu == rows[j].menu
				and a.plane == b.plane
				and math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) <= 4
			then
				group[find(j)] = find(i)
			end
		end
	end
	local starts: { HubStart } = {}
	local seen: { [number]: boolean } = {}
	local members: { [number]: { Transport } } = {}
	for i = 1, #rows do
		local root = find(i)
		members[root] = members[root] or {}
		table.insert(members[root], rows[i])
	end
	for i = 1, #rows do
		local root = find(i)
		if not seen[root] then
			seen[root] = true
			-- the first row of the group
			local row = rows[root]
			-- "Travel Spirit Tree 8355": the option, the object's name, its id
			local option = string.match(row.menu, "^(%S+)") or ""
			local object = tonumber(string.match(row.menu, "(%d+)%s*$"))
			table.insert(starts, {
				rep = row.origin :: Host.TransportTile,
				menu = row.menu,
				row = row,
				members = members[root],
				option = option,
				object = object,
			})
		end
	end
	local made = { starts = starts, ends = ends }
	hub_data[h.kind] = made
	Log.log("Transports", `{#starts} {h.kind} starts and {#ends} destinations (from {#rows} rows)`)
	return made
end

-- A trip of a network in the list of failures: where it starts and where it goes.
local function hub_id(kind: string, rep: Host.TransportTile, label: string): string
	return `{kind} {rep.x},{rep.y} {label}`
end

-- Whether a row of the data is usable by the player now, and if not why: its varbit and varp tests, skills, quests and items, and that it does not end in the Wilderness.
-- This is what the chooser asks of a row, as one call (for tests and tools).
function Transports.row_usable(t: Transport): (boolean, string?)
	if t.destination ~= nil and Transports.wilderness_level(t.destination.x, t.destination.y) ~= 0 then
		return false, "ends in the wilderness"
	end
	if not holds(t) then
		return false, "varbit or varp"
	end
	if not Transports.skills_met(t, Transports.levels()) then
		return false, "skills"
	end
	if not Transports.quests_done(t) then
		return false, `quests {table.concat(t.quests, ";")}`
	end
	if not Transports.items_met(t) then
		return false, `items {t.items}`
	end
	return true, nil
end

-- Boats, ferries and train carts: whole trips from a tile to a tile that are made by clicking an NPC or an object (the data's menu column: the option, the name, the id) and following
-- the dialogue. The `minecarts` file also holds the Lovakengj network, whose rows are starts and ends apart (see `HUBS`): only the rows with both ends are trips.
local BOAT_KINDS: { [string]: boolean } = { boats = true, ships = true, minecarts = true }

type Boat = { transport: Transport, label: string }

local boats: { Boat }? = nil

local function load_boats(): { Boat }
	if boats then
		return boats
	end
	local found: { Boat } = {}
	for _, t in ipairs(Host.transports().transports) do
		if BOAT_KINDS[t.kind] and t.origin ~= nil and t.destination ~= nil then
			-- the destination's name when the data gives it, else the menu without its id ("Musa Point Captain Tobias")
			local label = if t.name ~= "" then t.name else (string.gsub(t.menu, "%s*%d+%s*$", ""))
			table.insert(found, { transport = t, label = label })
		end
	end
	if #found > 0 then
		boats = found
	end
	Log.log("Transports", `{#found} boat, ship and cart trips`)
	return found
end

-- A boat trip in the list of failures: where it starts, where it goes and what is clicked.
local function boat_id(t: Transport): string
	local o, d = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	return `boat {o.x},{o.y} {d.x},{d.y} {t.menu}`
end

local function boat_ok(boat: Boat, c: Check): boolean
	local t = boat.transport
	local to = t.destination :: Host.TransportTile
	return not_failed(boat_id(t))
		and Transports.wilderness_level(to.x, to.y) == 0
		and c.here_wild <= (t.wilderness or 20)
		and holds(t)
		and Transports.skills_met(t, c.levels)
		and Transports.quests_done(t)
		and Transports.items_met(t)
end

-- Whether the object placed beside a start offers its click in the form it has now, or nil when that can't be told. A spirit tree planted in a farming patch is placed as the patch, which shows
-- the grown tree (with "Travel") only once the patch's varbit says it has grown; the object id in the data is the grown form, which always offers it, so the placed objects are asked: the cache
-- lists what is placed around the start, and `Host.loc_shown` says what each looks like now. Kept for `VALID_FOR_MS`.
local object_now: { [string]: { offers: boolean?, at: number } } = {}
local function offers_now(start: HubStart): boolean?
	local rep = start.rep
	local key = `{rep.x},{rep.y},{rep.plane}`
	local kept = object_now[key]
	if kept ~= nil and time() - kept.at < Transports.VALID_FOR_MS then
		return kept.offers
	end
	local offers: boolean? = nil
	local placed = Host.cache_locs(
		{ x1 = rep.x - 5, y1 = rep.y - 5, x2 = rep.x + 5, y2 = rep.y + 5 },
		{ plane = rep.plane }
	)
	if placed ~= nil then
		local ids: { number } = {}
		local seen: { [number]: boolean } = {}
		for _, loc in ipairs(placed) do
			if not seen[loc.id] then
				seen[loc.id] = true
				table.insert(ids, loc.id)
			end
		end
		local views = Host.loc_shown(ids)
		if views ~= nil then
			offers = false
			for _, view in ipairs(views) do
				if string.find(string.lower(view.name), "spirit tree", 1, true) ~= nil then
					for _, action in ipairs(view.actions) do
						if string.lower(action) == string.lower(start.option) then
							offers = true
						end
					end
				end
			end
		end
	end
	object_now[key] = { offers = offers, at = time() }
	if offers ~= true then
		Log.log(
			"Transports",
			`no spirit tree to use at {rep.x}, {rep.y} now ({if offers == nil then "can't tell" else "not grown"})`
		)
	end
	return offers
end

type Step = {
	kind: string,
	transport: Transport?,
	spell: Spell?,
	from: number,
	-- a trip of a network: its start and its end
	hub_start: HubStart?,
	hub_end: HubEnd?,
}

-- The best way from `from` to `goal`, found as a shortest path over the start, the goal and every transport's ends: walking joins two points only when they are
-- on the same landmass (so a goal across the water is reached only through a ship), a spell leaves from anywhere, and a ship from its dock.
-- Returns the first transport to use on that way (a spell now, or a ship after the walk to its dock) with the cost of the whole way, or nil to walk:
-- when walking is possible and no transport saves `min_saving_ticks`, when no transport is usable, or when the goal can't be reached at all.
function Transports.choose(from: Tile, goal: Tile, options: Options?): Choice?
	local opts = options or {}
	local plane = goal.plane or from.plane or 0
	memo = {}
	local needed = opts.min_saving_ticks or Transports.MIN_SAVING_TICKS
	local Magic = (require :: any)("@lib/main/interfaces/gametabs/magic")
	local check: Check = {
		levels = Transports.levels(),
		here_wild = Transports.wilderness_level(from.x, from.y),
		checked = {},
	}

	-- the nodes: 1 the start, 2 the goal, then the landing of every usable spell, and the docks and landings of every usable ship
	local nodes: { Node } = {
		{ x = from.x, y = from.y, plane = from.plane or plane },
		{ x = goal.x, y = goal.y, plane = plane },
	}
	local at: { [string]: number } = {}
	local function node(p: Host.TransportTile): number
		local key = `{p.x},{p.y},{p.plane}`
		local n = at[key]
		if n == nil then
			n = #nodes + 1
			nodes[n] = { x = p.x, y = p.y, plane = p.plane }
			at[key] = n
		end
		return n
	end
	local spells_: { { spell: Spell, to: number } } = {}
	for _, s in ipairs(load_spells()) do
		if not (opts.exclude and opts.exclude[s.spell]) and spell_ok(s, check, Magic) then
			table.insert(spells_, { spell = s, to = node(s.transport.destination :: Host.TransportTile) })
		end
	end
	local ships: { { trip: Trip, from: number, to: number } } = {}
	for _, trip in ipairs(load_trips()) do
		if not (opts.exclude and (opts.exclude[trip.label] or opts.exclude["charter"])) and trip_ok(trip, check) then
			local t = trip.transport
			table.insert(ships, {
				trip = trip,
				from = node(t.origin :: Host.TransportTile),
				to = node(t.destination :: Host.TransportTile),
			})
		end
	end
	local trees: { { ride: Ride, from: number, to: number } } = {}
	for _, ride in ipairs(load_rides()) do
		if not (opts.exclude and (opts.exclude[ride.label] or opts.exclude["mushtree"])) and ride_ok(ride, check) then
			local t = ride.transport
			table.insert(trees, {
				ride = ride,
				from = node(t.origin :: Host.TransportTile),
				to = node(t.destination :: Host.TransportTile),
			})
		end
	end
	-- the networks of separate starts and ends: the starts and ends the player can use now, as nodes (the pairs are formed in the search)
	local networks: { { hub: Hub, starts: { { start: HubStart, node: number } }, ends: { { finish: HubEnd, node: number } } } } =
		{}
	for _, hub in ipairs(HUBS) do
		if not (opts.exclude and opts.exclude[hub.kind]) then
			local data = load_hub(hub)
			local usable = true
			if hub.gate ~= nil and #data.starts > 0 then
				local ok, why = hub.gate()
				if not ok then
					usable = false
					Log.log("Transports", `{hub.kind} can't be used: {why or "no reason given"}`)
				end
			end
			local starts, finishes = {}, {}
			-- starts that are objects in more than one state (a spirit tree that is a farming patch until it has grown): the form the one placed there has now must offer the click
			local blocked: { HubStart } = {}
			local standing: { [HubStart]: boolean } = {}
			if usable and hub.object_start then
				for _, start in ipairs(data.starts) do
					local offers = offers_now(start)
					if offers ~= nil then
						standing[start] = offers
						if not offers then
							table.insert(blocked, start)
						end
					end
				end
			end
			if usable then
				for _, start in ipairs(data.starts) do
					local usable_member = false
					for _, t in ipairs(start.members) do
						if
							holds(t)
							and Transports.skills_met(t, check.levels)
							and Transports.quests_done(t)
							and Transports.items_met(t)
						then
							usable_member = true
							break
						end
					end
					if standing[start] ~= false and usable_member then
						table.insert(starts, { start = start, node = node(start.rep) })
					end
				end
				if #starts > 0 then
					for _, finish in ipairs(data.ends) do
						local t = finish.row
						-- a destination that is a planted tree is where one of the blocked starts stands: the data puts the end beside its start
						local planted_away = false
						for _, start in ipairs(blocked) do
							local spot = start.rep
							if
								spot.plane == finish.tile.plane
								and math.max(math.abs(spot.x - finish.tile.x), math.abs(spot.y - finish.tile.y))
									<= 8
							then
								planted_away = true
							end
						end
						if
							not planted_away
							and Transports.wilderness_level(finish.tile.x, finish.tile.y) == 0
							and holds(t)
							and Transports.skills_met(t, check.levels)
							and Transports.quests_done(t)
						then
							table.insert(finishes, { finish = finish, node = node(finish.tile) })
						end
					end
				end
			end
			if #starts > 0 and #finishes > 0 then
				table.insert(networks, { hub = hub, starts = starts, ends = finishes })
			end
		end
	end
	local rides_by_boat: { { boat: Boat, from: number, to: number } } = {}
	for _, boat in ipairs(load_boats()) do
		if not (opts.exclude and (opts.exclude[boat.label] or opts.exclude["boat"])) and boat_ok(boat, check) then
			local t = boat.transport
			table.insert(rides_by_boat, {
				boat = boat,
				from = node(t.origin :: Host.TransportTile),
				to = node(t.destination :: Host.TransportTile),
			})
		end
	end
	local gates: { { link: Transport, from: number, to: number } } = {}
	for _, link in ipairs(load_links()) do
		if not (opts.exclude and opts.exclude["gates"]) and link_ok(link, check) then
			gates[#gates + 1] = {
				link = link,
				from = node(link.origin :: Host.TransportTile),
				to = node(link.destination :: Host.TransportTile),
			}
		end
	end
	memo = nil
	landmasses(nodes)
	-- a way across the player can use (a shortcut, a link) joins the landmasses at its two ends: walking between them is possible (the collision map shows the obstacle as a wall)
	merged = {}
	local ends: { Tile } = {}
	local joins = usable_links(opts.shortcuts)
	for _, t in ipairs(joins) do
		table.insert(ends, t.origin :: Tile)
		table.insert(ends, t.destination :: Tile)
	end
	landmasses(ends)
	for _, t in ipairs(joins) do
		local la, lb = landmass(t.origin :: Tile), landmass(t.destination :: Tile)
		if la ~= 0 and lb ~= 0 and find(la) ~= find(lb) then
			merged[find(la)] = find(lb)
		end
	end

	-- Dijkstra over the nodes, every one joined to every other by walking
	local count = #nodes
	local dist: { number } = table.create(count, math.huge)
	local prev: { Step? } = table.create(count)
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
		local function relax(v: number, cost: number, step: Step)
			if best + cost < dist[v] then
				dist[v] = best + cost
				prev[v] = step
			end
		end
		for v = 1, count do
			if v ~= u and not done[v] then
				relax(v, walk_cost(nodes[u], nodes[v]), { kind = "walk", from = u })
			end
		end
		for _, s in ipairs(spells_) do
			if not done[s.to] then
				relax(
					s.to,
					s.spell.transport.duration + Transports.CAST_SLACK_TICKS,
					{ kind = "spell", spell = s.spell, from = u }
				)
			end
		end
		for _, gate in ipairs(gates) do
			if gate.from == u and not done[gate.to] then
				relax(
					gate.to,
					gate.link.duration + Transports.LINK_SLACK_TICKS,
					{ kind = "link", transport = gate.link, from = u }
				)
			end
		end
		for _, tree in ipairs(trees) do
			if tree.from == u and not done[tree.to] then
				relax(
					tree.to,
					tree.ride.transport.duration + Transports.MUSHTREE_SLACK_TICKS,
					{ kind = "mushtree", transport = tree.ride.transport, from = u }
				)
			end
		end
		for _, ride in ipairs(rides_by_boat) do
			if ride.from == u and not done[ride.to] then
				relax(
					ride.to,
					ride.boat.transport.duration + Transports.BOAT_SLACK_TICKS,
					{ kind = "boat", transport = ride.boat.transport, from = u }
				)
			end
		end
		for _, network in ipairs(networks) do
			local hub = network.hub
			for _, begin in ipairs(network.starts) do
				if begin.node == u then
					local rep = begin.start.rep
					for _, target in ipairs(network.ends) do
						local finish = target.finish
						local v = target.node
						if not done[v] then
							local cost = finish.duration + hub.slack
							-- an end within the radius of the start is the same place
							local near = finish.tile.plane == rep.plane
								and math.max(math.abs(finish.tile.x - rep.x), math.abs(finish.tile.y - rep.y))
									< hub.radius
							if
								not near
								and best + cost < dist[v]
								and not_failed(hub_id(hub.kind, rep, finish.label))
							then
								relax(v, cost, { kind = hub.kind, from = u, hub_start = begin.start, hub_end = finish })
							end
						end
					end
				end
			end
		end
		for _, ship in ipairs(ships) do
			if ship.from == u and not done[ship.to] then
				relax(
					ship.to,
					ship.trip.transport.duration + Transports.CHARTER_SLACK_TICKS,
					{ kind = "charter", transport = ship.trip.transport, from = u }
				)
			end
		end
	end

	if dist[2] == math.huge then
		return nil
	end
	-- the way back from the goal: the first transport on it is what to use now
	local first: Step? = nil
	local v = 2
	while v ~= 1 do
		local step = prev[v] :: Step
		if step.kind ~= "walk" then
			first = step
		end
		v = step.from
	end
	if first == nil then
		return nil
	end
	local direct = walk_cost(nodes[1], nodes[2])
	if direct ~= math.huge and direct - dist[2] < needed then
		return nil
	end
	local saved = if direct == math.huge then 1e9 else direct - dist[2]
	if first.kind == "spell" then
		local s = first.spell :: Spell
		return {
			kind = "spell",
			transport = s.transport,
			spell = s.spell,
			option = s.option,
			ticks = dist[2],
			saved = saved,
		}
	end
	if first.hub_start ~= nil and first.hub_end ~= nil then
		-- a trip of a network: a transport made of its start (where to stand, what to click) and its end (where it goes, what it is called)
		local start, finish = first.hub_start, first.hub_end
		local trip = {
			kind = first.kind,
			origin = start.rep,
			destination = finish.tile,
			name = finish.name,
			label = finish.label,
			menu = start.menu,
			duration = finish.duration,
		}
		return {
			kind = first.kind,
			transport = trip :: any,
			spell = "",
			option = nil,
			ticks = dist[2],
			saved = saved,
		}
	end
	return {
		kind = first.kind,
		transport = first.transport :: Transport,
		spell = "",
		option = nil,
		ticks = dist[2],
		saved = saved,
	}
end

-- The climbs (stairs, ladders, ropes, cave mouths) and agility shortcuts that ask for something and that the player has what they ask for, as the names the planner knows them by
-- ("x,y,plane>x,y,plane"). The planner has every climb that asks for nothing already; for these it needs to be told (`allow_climbs` of `Host.nav_plan`). Kept for `VALID_FOR_MS`.
-- A shortcut is judged on the real (unboosted) levels, because a boost can run out on the way, and is left out when it starts or ends in the Wilderness. `options.shortcuts` false leaves them all out.
local allowed: { [string]: { keys: { string }, at: number } } = {}
function Transports.allowed_climbs(options: { shortcuts: boolean? }?): { string }
	local shortcuts = if options ~= nil and options.shortcuts ~= nil then options.shortcuts else Transports.SHORTCUTS
	local cache_key = if shortcuts then "with" else "without"
	local kept = allowed[cache_key]
	if kept ~= nil and time() - kept.at < Transports.VALID_FOR_MS then
		return kept.keys
	end
	local keys: { string } = {}
	memo = {}
	local levels = Transports.levels()
	local real = if shortcuts then Transports.levels(true) else nil
	for _, t in ipairs(Host.transports().transports) do
		if t.origin ~= nil and t.destination ~= nil then
			local o, d = t.origin, t.destination
			local usable = false
			if t.kind == "climb_gated" then
				usable = holds(t)
					and Transports.skills_met(t, levels)
					and Transports.quests_done(t)
					and Transports.items_met(t)
			elseif t.kind == "shortcut_gated" and shortcuts then
				usable = Transports.wilderness_level(o.x, o.y) == 0
					and Transports.wilderness_level(d.x, d.y) == 0
					and holds(t)
					and Transports.skills_met(t, real)
					and Transports.quests_done(t)
					and Transports.items_met(t)
			end
			if usable then
				table.insert(keys, `{o.x},{o.y},{o.plane}>{d.x},{d.y},{d.plane}`)
			end
		end
	end
	memo = nil
	allowed[cache_key] = { keys = keys, at = time() }
	return keys
end

-- Waits for the new scene to load after a teleport: until then planning a route fails with "not logged in".
function Transports.settle(at: Tile)
	local deadline = time() + Transports.SETTLE_TIMEOUT_MS
	while time() < deadline do
		local plan, err = Host.nav_plan(
			{ x = at.x, y = at.y, plane = at.plane or 0 },
			{ x = at.x + 1, y = at.y, plane = at.plane or 0 }
		)
		if plan ~= nil or err ~= "not logged in" then
			return
		end
		sleep(200)
	end
end

-- Casts the chosen teleport and waits to land. False when it didn't work, and that spell is left alone for a while.
function Transports.cast(choice: Choice): boolean
	local Magic = (require :: any)("@lib/main/interfaces/gametabs/magic")
	local Player = (require :: any)("@lib/main/player")
	local before = Player.position()
	if before == nil then
		return false
	end
	local t = choice.transport
	local to = t.destination :: Host.TransportTile
	Log.log("Transports", `casting {t.name}: saves about {math.floor(choice.saved)} ticks`)
	local ok = Magic.is_open() or Magic.open()
	-- not Magic.cast: its check that the spell was cast only knows the "Cast" option, and a teleport lands by itself
	ok = ok and Magic.interact(choice.spell, choice.option or "Cast")
	if ok then
		local deadline = time() + Transports.LAND_TIMEOUT_MS
		while time() < deadline do
			local now = Player.position()
			if now ~= nil then
				local moved = math.max(math.abs(now.x - before.x), math.abs(now.y - before.y))
				if moved >= Transports.LAND_DISTANCE or now.plane ~= before.plane then
					local off = math.max(math.abs(now.x - to.x), math.abs(now.y - to.y))
					if off > 10 then
						Log.log("Transports", `{t.name} landed at {now.x}, {now.y}, not near {to.x}, {to.y}`)
					end
					Transports.settle(now)
					return true
				end
			end
			sleep(100)
		end
	end
	Log.log("Transports", `{t.name} didn't work`)
	return false
end

-- Waits for a position change to settle after a trip; true when we have moved at least `LAND_DISTANCE` from `before`.
local function wait_to_land(before: { x: number, y: number, plane: number }, timeout_ms: number): boolean
	local Player = (require :: any)("@lib/main/player")
	local deadline = time() + timeout_ms
	while time() < deadline do
		local now = Player.position()
		if now ~= nil then
			local moved = math.max(math.abs(now.x - before.x), math.abs(now.y - before.y))
			if moved >= Transports.LAND_DISTANCE or now.plane ~= before.plane then
				Transports.settle(now)
				return true
			end
		end
		sleep(100)
	end
	return false
end

-- Gets off a charter boat: crosses the gangplank onto the dock at `to` (the destination tile the data names) and waits for the scene to settle. False when it didn't work in `CROSS_TIMEOUT_MS`.
function Transports.disembark(to: Tile): boolean
	local Player = (require :: any)("@lib/main/player")
	local Objects = (require :: any)("@lib/main/entities/objects")
	local plane = to.plane or 0
	local function arrived(): boolean
		local now = Player.position()
		return now ~= nil
			and now.plane == plane
			and math.max(math.abs(now.x - to.x), math.abs(now.y - to.y)) <= Transports.ARRIVED_NEAR
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
	Transports.settle(Player.position() :: Tile)
	return true
end

-- Rides the magic mushtrees: walks to the start tile, uses the tree, picks the destination in the list by its NAME (the list shows the trees that can be reached, so a tree that
-- isn't grown isn't there) and waits to land. False when it didn't work.
function Transports.ride(choice: Choice): boolean
	local t = choice.transport
	local from, to = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local id = ride_id(t)
	local fail = function(why: string): boolean
		Log.log("Transports", `{id}: {why}`)
		return false
	end
	local label = string.match(t.name, "^%d+%.%s*(.+)$")
	if label == nil then
		return fail("no destination name in the data")
	end
	local Walker = (require :: any)("@lib/main/walker")
	local Player = (require :: any)("@lib/main/player")
	local Mushtree = (require :: any)("@lib/main/interfaces/mainscreen/mushtree")
	local before = Player.position()
	if before == nil then
		return false
	end
	Log.log("Transports", `riding the mushtree to {label}: saves about {math.floor(choice.saved)} ticks`)
	if
		before.plane ~= from.plane
		or math.max(math.abs(before.x - from.x), math.abs(before.y - from.y)) > Transports.DOCK_NEAR
	then
		if not Walker.walk(from, { near = Transports.DOCK_NEAR, transports = false, plane = from.plane }) then
			return fail("couldn't walk to the tree")
		end
	end
	if not Mushtree.open() then
		return fail("the list didn't open")
	end
	local start = Player.position() or before
	if Mushtree.select(label :: any) == nil then
		Mushtree.close()
		return fail(`{label} isn't in the list`)
	end
	if not wait_to_land(start, Transports.MUSHTREE_TIMEOUT_MS) then
		return fail("the trip didn't happen")
	end
	local now = Player.position() :: Tile
	if math.max(math.abs(now.x - to.x), math.abs(now.y - to.y)) > Transports.ARRIVED_NEAR + 6 then
		Log.log("Transports", `{id}: landed at {now.x}, {now.y}, not near {to.x}, {to.y}`)
	end
	return true
end

-- Takes a trip of a network of separate starts and ends: walks to the start tile beside the tree, ring or pilot, has the interface choose the destination by its NAME (see `Hub.go`)
-- and waits to land. False when it didn't work, and that trip is then left alone for a while.
function Transports.hub(choice: Choice): boolean
	local t = choice.transport :: any
	local hub = HUB_BY_KIND[choice.kind]
	local from, to = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local label = t.label :: string
	local id = hub_id(choice.kind, from, label)
	local fail = function(why: string): boolean
		Log.log("Transports", `{id}: {why}`)
		return false
	end
	local Walker = (require :: any)("@lib/main/walker")
	local Player = (require :: any)("@lib/main/player")
	local before = Player.position()
	if before == nil then
		return false
	end
	Log.log("Transports", `{choice.kind} to {label}: saves about {math.floor(choice.saved)} ticks`)
	if
		before.plane ~= from.plane
		or math.max(math.abs(before.x - from.x), math.abs(before.y - from.y)) > Transports.DOCK_NEAR
	then
		if not Walker.walk(from, { near = Transports.DOCK_NEAR, transports = false, plane = from.plane }) then
			return fail("couldn't walk to the start")
		end
	end
	local start = Player.position() or before
	local m = (require :: any)(hub.module)
	local ok, went, why = pcall(hub.go, m, label)
	if not ok then
		return fail(tostring(went))
	end
	if not went then
		return fail(why or "didn't work")
	end
	if not wait_to_land(start, Transports.HUB_TIMEOUT_MS) then
		return fail("the trip didn't happen")
	end
	local now = Player.position() :: Tile
	if math.max(math.abs(now.x - to.x), math.abs(now.y - to.y)) > Transports.ARRIVED_NEAR + 10 then
		Log.log("Transports", `{id}: landed at {now.x}, {now.y}, not near {to.x}, {to.y}`)
	end
	return true
end

-- The option of a dialogue to pick for a boat: the one that names where it goes, else a yes. `hints` are lowercase pieces of the destination's name.
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
	local Player = (require :: any)("@lib/main/player")
	local Npcs = (require :: any)("@lib/main/entities/npcs")
	local ChatOptions = (require :: any)("@lib/main/interfaces/chatbox/chat_options")
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
	if conductor == nil or Npcs.distance(conductor, me) > Transports.BOAT_NPC_RANGE then
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
		sleep(Transports.BOAT_POLL_MS)
	end
	return bought_at ~= nil
end

-- Takes a boat, ferry or train cart: walks to the tile it is boarded from, clicks the NPC or object the data names (by its id, with the menu option the data starts its menu with),
-- follows the dialogue (the option that names the destination, else a yes, and "continue"), and waits to land. False when it didn't work, and that trip is then left alone for a while.
function Transports.board(choice: Choice): (boolean, boolean?)
	local t = choice.transport
	local from, to = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local id = boat_id(t)
	local fail = function(why: string): boolean
		Log.log("Transports", `{id}: {why}`)
		return false
	end
	-- "Musa Point Captain Tobias 14979": the id is last; what comes before is the menu option followed by the name, and where one ends isn't marked, so every beginning is tried, longest first
	local words: { string } = {}
	for word in string.gmatch(t.menu, "%S+") do
		table.insert(words, word)
	end
	local target = tonumber(words[#words])
	if target == nil or #words < 2 then
		return fail("can't read the menu in the data")
	end
	table.remove(words)
	local options: { string } = {}
	for n = #words - 1, 1, -1 do
		table.insert(options, table.concat(words, " ", 1, n))
	end
	local hints: { string } = {}
	if t.name ~= "" then
		table.insert(hints, string.lower(t.name))
	end
	for _, option in ipairs(options) do
		table.insert(hints, string.lower(option))
	end
	local Walker = (require :: any)("@lib/main/walker")
	local Player = (require :: any)("@lib/main/player")
	local Npcs = (require :: any)("@lib/main/entities/npcs")
	local Objects = (require :: any)("@lib/main/entities/objects")
	local ChatOptions = (require :: any)("@lib/main/interfaces/chatbox/chat_options")
	local before = Player.position()
	if before == nil then
		return false
	end
	Log.log("Transports", `boarding {t.menu}: saves about {math.floor(choice.saved)} ticks`)
	-- a retry after the crossing happened but getting off didn't: we are by the destination already, so only getting off is left
	local by_destination = math.max(math.abs(before.x - to.x), math.abs(before.y - to.y)) <= Transports.ABOARD_NEAR
		and math.max(math.abs(before.x - from.x), math.abs(before.y - from.y)) > Transports.ABOARD_NEAR
	if by_destination then
		if before.plane ~= to.plane and not Transports.disembark(to) then
			return fail("couldn't get off the boat")
		end
		return true
	end
	if
		before.plane ~= from.plane
		or math.max(math.abs(before.x - from.x), math.abs(before.y - from.y)) > Transports.DOCK_NEAR
	then
		if not Walker.walk(from, { near = Transports.DOCK_NEAR, transports = false, plane = from.plane }) then
			return fail("couldn't walk to the boarding tile")
		end
	end
	-- the NPC with that id, else the object
	local npc = Npcs.nearest(target, from)
	local loc = if npc == nil then Objects.nearest(target, from) else nil
	-- The data's ids and names are not always the game's: an NPC id can be the form an NPC shows after a quest or varbit has changed it (the game's list has the placed one), and names
	-- change (the sailor the data calls Veos is Cabin Boy Herbert). The options hold: so the NPC is found by asking which of the ones near offers an option the menu starts with, by its
	-- right-click menu, and the option is picked from that menu.
	local picked = false
	if npc == nil and loc == nil then
		local Minimenu = (require :: any)("@lib/main/interfaces/minimenu")
		local Camera = (require :: any)("@lib/main/camera")
		local near = {}
		for _, candidate in ipairs(Npcs.find() or {}) do
			local gap = math.max(math.abs(candidate.x - from.x), math.abs(candidate.y - from.y))
			if gap <= Transports.BOAT_NPC_RANGE then
				table.insert(near, { npc = candidate, gap = gap })
			end
		end
		table.sort(near, function(a, b)
			return a.gap < b.gap
		end)
		for i = 1, math.min(#near, Transports.BOAT_NPC_LOOKS) do
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
		return fail(`nothing with id {target} or offering {table.concat(options, " / ")} is near`)
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
	local Chat = (require :: any)("@lib/main/interfaces/chatbox/chat")
	local seen = (Chat.last_message() or { uid = 0 }).uid
	if not clicked then
		clicked = click_target()
	end
	if not clicked then
		return fail(`none of the options {table.concat(options, " / ")} could be clicked`)
	end
	local ticket_tried = false
	-- the dialogue and the trip
	local deadline = time() + Transports.BOAT_TIMEOUT_MS
	local underground = start.y >= 6400
	-- what was said last, and when anything last happened: a conversation that ends without a trip (the monk who won't take weapons to Entrana) is over soon after, not when the time is up
	local last_said: string? = nil
	local quiet_since = time()
	local clicked_at = time()
	while time() < deadline do
		local now = Player.position()
		if now ~= nil then
			local moved = math.max(math.abs(now.x - start.x), math.abs(now.y - start.y))
			local near_destination = math.max(math.abs(now.x - to.x), math.abs(now.y - to.y))
				<= Transports.ARRIVED_NEAR + 10
			-- the click can make the player walk to the NPC or the cart, up a gangplank: that is not the trip. The trip is a jump (a voyage, a ride, a teleport), or being at the destination
			if
				moved >= Transports.BOAT_LAND_DISTANCE
				or (near_destination and moved >= Transports.LAND_DISTANCE)
				or (now.y >= 6400) ~= underground
			then
				-- a voyage can be an instance (the squire's boat at Port Sarim) that ends at the destination some seconds later: wait for it
				local voyage = time() + Transports.BOAT_VOYAGE_MS
				while
					time() < voyage
					and math.max(math.abs(now.x - to.x), math.abs(now.y - to.y)) > Transports.ARRIVED_NEAR + 10
				do
					sleep(Transports.BOAT_POLL_MS)
					now = Player.position() or now
				end
				Transports.settle(now)
				-- a boat can put you aboard, a plane above the dock the data names: the gangplank leads onto it
				if now.plane ~= to.plane then
					Random.sleep(Transports.BOAT_DOCK_PAUSE_MS[1], Transports.BOAT_DOCK_PAUSE_MS[2])
				end
				if now.plane ~= to.plane and not Transports.disembark(to) then
					local after = Player.position() :: Tile
					local plank = Objects.nearest(Transports.GANGPLANK, after)
					return fail(
						`couldn't get off the boat: landed at {now.x}, {now.y} on plane {now.plane}, now at {after.x}, {after.y} plane {after.plane}; gangplank {if plank
							then `{plank.id} at {plank.x}, {plank.y} plane {plank.plane}`
							else "none loaded"}`
					)
				end
				now = Player.position() or now
				if math.max(math.abs(now.x - to.x), math.abs(now.y - to.y)) > Transports.ARRIVED_NEAR + 10 then
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
					return fail("couldn't buy the ticket")
				end
				-- the ticket is bought: click the cart again
				seen = (Chat.last_message() or { uid = seen }).uid
				if not click_target() then
					return fail("couldn't click the cart again after buying the ticket")
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
		end
		if last_said == nil and time() - clicked_at > Transports.BOAT_SILENT_MS then
			return fail("nothing was said and nothing happened")
		end
		if last_said ~= nil and time() - quiet_since > Transports.BOAT_QUIET_MS then
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
			ChatOptions.select(pick)
		elseif ChatOptions.contains_continue() then
			ChatOptions.continue_chat()
		end
		sleep(Transports.BOAT_POLL_MS)
	end
	return fail("the trip didn't happen")
end

-- Takes the chosen charter ship: walks to the dock, talks to the trader ("Charter"), picks the destination in the list and waits for the boat. False when it didn't work.
function Transports.sail(choice: Choice): boolean
	local t = choice.transport
	local dock, to = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local _, label = string.match(t.name, "^(%w+):%s*(.+)$")
	local id = charter_id(t)
	local fail = function(why: string): boolean
		Log.log("Transports", `{id}: {why}`)
		return false
	end
	if label == nil then
		return fail("no destination name in the data")
	end
	-- what to say to the trader: the first word of "Charter Trader Crewmember 1330"
	local option = string.match(t.menu, "^(%S+)")
	if option == nil then
		return fail("the data doesn't say what to say to the trader")
	end
	local Walker = (require :: any)("@lib/main/walker")
	local Player = (require :: any)("@lib/main/player")
	local before = Player.position()
	if before == nil then
		return false
	end
	Log.log("Transports", `sailing to {label}: saves about {math.floor(choice.saved)} ticks`)
	-- a retry after the boat came but the gangplank didn't work: we are already at the destination, aboard, so only the crossing is left
	local aboard = math.max(math.abs(before.x - to.x), math.abs(before.y - to.y)) <= Transports.ABOARD_NEAR
	if not aboard then
		-- to the dock (without looking for a transport again)
		if
			before.plane ~= dock.plane
			or math.max(math.abs(before.x - dock.x), math.abs(before.y - dock.y)) > Transports.DOCK_NEAR
		then
			if not Walker.walk(dock, { near = Transports.DOCK_NEAR, transports = false, plane = dock.plane }) then
				return fail("couldn't walk to the dock")
			end
		end
		-- the trader at the dock ("Charter"), talked to until the menu shows (see `Chartering.open`)
		local opened, why = Chartering.open(option, dock)
		if not opened then
			return fail(why or "the destination list didn't open")
		end
		-- the destinations: chosen by the destination's NAME, never by its key letter (the letters differ by port); nothing is chosen unless a name matches.
		-- By the keyboard, on the map or in the list, by chance (see `Chartering.select`).
		local start = Player.position()
		-- the label comes from the transport data, a name the game gives rather than one of `Chartering.Port`
		if Chartering.select(label :: any) == nil then
			return fail(`{label} isn't in the list`)
		end
		if not wait_to_land(start or before, Transports.CHARTER_SAIL_TIMEOUT_MS) then
			return fail("the boat didn't come")
		end
	end
	-- the boat brings you aboard at the destination: the gangplank leads onto the dock the data names
	if not Transports.disembark(to) then
		return fail("couldn't get off the boat")
	end
	Transports.settle(Player.position() :: Tile)
	return true
end

-- Goes through the chosen gate or barrier: walks to the tile before it, clicks the object between the tiles (by name, because it is a different object by quest progress:
-- "Pay-toll(2-Ecto)" before the quest, "Pass" after) and waits to be on the other side. False when it didn't work, and that gate is then left alone for a while.
function Transports.pass(choice: Choice): boolean
	local t = choice.transport
	local o, d = t.origin :: Host.TransportTile, t.destination :: Host.TransportTile
	local id = link_id(t)
	local fail = function(why: string): boolean
		Log.log("Transports", `{id}: {why}`)
		return false
	end
	-- "Pay-toll(2-Ecto) Energy Barrier 16105": the option, the object's name, its id
	local option, target = string.match(t.menu, "^(%S+)%s+(.-)%s+%d+%s*$")
	if option == nil or target == nil then
		return fail("the data doesn't say what to click")
	end
	local Walker = (require :: any)("@lib/main/walker")
	local Objects = (require :: any)("@lib/main/entities/objects")
	local Player = (require :: any)("@lib/main/player")
	local here = Player.position()
	if here == nil then
		return false
	end
	Log.log("Transports", `going through the {target} at {o.x}, {o.y}`)
	if
		here.plane ~= o.plane
		or math.max(math.abs(here.x - o.x), math.abs(here.y - o.y)) > Transports.LINK_ARRIVED_NEAR
	then
		if not Walker.walk(o, { near = 1, transports = false, plane = o.plane }) then
			return fail("couldn't walk to it")
		end
	end
	local middle = { x = (o.x + d.x) // 2, y = (o.y + d.y) // 2 }
	local gate = Objects.nearest(target, middle)
	if gate == nil then
		return fail(`no {target} in sight`)
	end
	if not Objects.interact(gate, { "Pass", option }) then
		return fail("couldn't click it")
	end
	local deadline = time() + Transports.LINK_TIMEOUT_MS
	while time() < deadline do
		local now = Player.position()
		if
			now ~= nil
			and now.plane == d.plane
			and math.max(math.abs(now.x - d.x), math.abs(now.y - d.y)) <= Transports.LINK_ARRIVED_NEAR
		then
			return true
		end
		sleep(150)
	end
	return fail("didn't get through")
end

-- What a choice is called in the list of failures.
local function failure_id(choice: Choice): string
	local t = choice.transport
	if choice.kind == "charter" then
		return charter_id(t)
	elseif choice.kind == "link" then
		return link_id(t)
	elseif choice.kind == "mushtree" then
		return ride_id(t)
	elseif choice.kind == "boat" then
		return boat_id(t)
	elseif HUB_BY_KIND[choice.kind] ~= nil then
		return hub_id(choice.kind, t.origin :: Host.TransportTile, (t :: any).label)
	end
	return t.name
end

-- Whether a choice failed in the last `RETRY_AFTER_MS`, and so isn't chosen.
function Transports.failed_lately(choice: Choice): boolean
	return not not_failed(failure_id(choice))
end

-- How each kind of choice is carried out (a table, so that a test can stand in for the game).
Transports.runners = {
	spell = function(choice: Choice): boolean
		return Transports.cast(choice)
	end,
	charter = function(choice: Choice): boolean
		return Transports.sail(choice)
	end,
	link = function(choice: Choice): boolean
		return Transports.pass(choice)
	end,
	mushtree = function(choice: Choice): boolean
		return Transports.ride(choice)
	end,
	boat = function(choice: Choice): (boolean, boolean?)
		return Transports.board(choice)
	end,
} :: { [string]: (Choice) -> (boolean, boolean?) }
for _, hub in ipairs(HUBS) do
	Transports.runners[hub.kind] = function(choice: Choice): boolean
		return Transports.hub(choice)
	end
end

-- Uses the chosen transport, whatever its kind: up to `ATTEMPTS` tries with a pause between. If every one fails, it is marked failed for `RETRY_AFTER_MS`
-- (the next plan leaves it out) and this returns false. True when one worked.
function Transports.use(choice: Choice): boolean
	local run = Transports.runners[choice.kind]
	if run == nil then
		return false
	end
	local id = failure_id(choice)
	for attempt = 1, Transports.ATTEMPTS do
		-- a runner can say its failure is final (a captain who refuses the account): trying again would only be refused again
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
		end
	end
	failed[id] = time()
	Log.log("Transports", `{id}: failed {Transports.ATTEMPTS} times, left out for a while`)
	return false
end

-- Takes the best transport toward `goal`, if one is worth it. Returns whether one was used and whether one failed (every attempt): a failed one is out of the next plan,
-- so the caller plans again from where it is.
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
