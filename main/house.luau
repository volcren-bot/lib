--!strict
-- The player's house: an instance whose layout each player chooses and can change, so nothing here knows a room or a tile. Furniture is found by name in the scene of this visit, on any floor.
-- The transport data calls the whole house one tile (`House.TILE`), and the planner does too: every way in arrives there and every way out leaves from there.
local Host = require("@lib/host")
local locs = Host.locs
local sleep = Host.sleep
local time = Host.time
type Loc = Host.Loc
local Log = require("@lib/utils/log")
local Objects = require("@lib/main/entities/objects")
local Player = require("@lib/main/player")

local House = {}

-- the cache's config index and its archive of structs
local CONFIG_STRUCTS = { 2, 34 }

-- the interface modules need this one, so they are loaded when used
local function lib(path: string): any
	return (require :: any)(path)
end

-- The data's stand-in for anywhere in the house.
House.TILE = { x = 1858, y = 7051, plane = 0 }
-- The way out: the name of the object, its id, and the option.
House.EXIT_PORTAL = 4525
House.EXIT_OPTION = "Enter"
House.STAIRS = "Staircase"
House.CLIMB_UP = "Climb-up"
House.CLIMB_DOWN = "Climb-down"
House.PLANES = 4
-- How big a house can be, in tiles: a goal this close to you is inside it.
House.SIZE = 104
House.POLL_MS = 100
House.STAIRS_TIMEOUT_MS = 10000
House.LEAVE_TIMEOUT_MS = 15000
House.TELEPORT_TIMEOUT_MS = 10000
House.RESTORE_TIMEOUT_MS = 8000
-- Where the house is (varbit 2187), by the game's number.
House.LOCATION_VARBIT = 2187
House.LOCATIONS = {
	[1] = "Rimmington",
	[2] = "Taverley",
	[3] = "Pollnivneach",
	[4] = "Rellekka",
	[5] = "Brimhaven",
	[6] = "Yanille",
	[8] = "Hosidius",
	[9] = "Prifddinas",
	[13] = "Aldarin",
} :: { [number]: string }
-- The Portal Nexus's slots in list order (`poh_nexus_tele_1` to 30), each holding a teleport's key or 0, and its left-click teleport.
House.NEXUS_SLOT_VARBITS = {
	6654,
	6655,
	6656,
	6657,
	6658,
	6659,
	6660,
	6661,
	6662,
	6663,
	6664,
	6665,
	6666,
	6667,
	6668,
	6554,
	6555,
	6556,
	10080,
	10081,
	10082,
	10083,
	10084,
	10085,
	10086,
	10087,
	10088,
	10089,
	10090,
	10091,
}
House.NEXUS_LEFT_CLICK_VARBIT = 6653
-- The cache's list of Nexus teleports (enum 1377, key to struct) and the struct param that names one.
House.NEXUS_ENUM = 1377
House.NEXUS_NAME_PARAM = 660
-- A teleport's other place, listed right after it once the diary that unlocks it is done: its key, and that diary's varbit.
House.NEXUS_ALTERNATES = {
	[1] = { key = 151, unlocked_by = 4480 }, -- Varrock: Grand Exchange, Varrock medium
	[4] = { key = 154, unlocked_by = 4477 }, -- Camelot: Seers' Village, Kandarin hard
	[6] = { key = 156, unlocked_by = 4460 }, -- Watchtower: Yanille, Ardougne hard
} :: { [number]: { key: number, unlocked_by: number } }
-- The jewellery box's size (`poh_jewellerybox_multi`: 0 basic, 1 fancy, 2 ornate); 0 is also what a house without a box reads.
House.BOX_VARBIT = 2308
export type BoxTier = "basic" | "fancy" | "ornate"
House.BOX_TIERS = { "basic", "fancy", "ornate" } :: { BoxTier }
-- The places each size of box adds to the one below it, as the box names them.
House.BOX_PLACES = {
	basic = {
		"Emir's Arena",
		"Castle Wars",
		"Ferox Enclave",
		"Fortis Colosseum",
		"Burthorpe",
		"Barbarian Outpost",
		"Corporeal Beast",
		"Tears of Guthix",
		"Wintertodt Camp",
	},
	fancy = {
		"Warriors' Guild",
		"Champions' Guild",
		"Monastery",
		"Ranging Guild",
		"Fishing Guild",
		"Mining Guild",
		"Crafting Guild",
		"Cooking Guild",
		"Woodcutting Guild",
		"Farming Guild",
	},
	ornate = {
		"Miscellania",
		"Grand Exchange",
		"Falador Park",
		"Dondakan's Rock",
		"Edgeville",
		"Karamja",
		"Draynor Village",
		"Al Kharid",
	},
} :: { [BoxTier]: { string } }
-- The places of what can be mounted on the walls.
House.MOUNTED_PLACES = {
	glory = { "Edgeville", "Karamja", "Draynor Village", "Al Kharid" },
	cape = { "Myths' Guild" },
	talisman = { "Lookout", "Glade", "Inferno", "Heart", "Honour" },
	digsite = { "Digsite", "Fossil Island", "Lithkren" },
} :: { [string]: { string } }
House.POOL_OPTION = "Drink"
-- What each kind of furniture is called: part of any of these names, in any case. The Spiritual Fairy Tree is both a ring and a tree.
House.FURNITURE = {
	nexus = { "Portal Nexus" },
	box = { "Jewellery Box" },
	glory = { "Amulet of Glory" },
	cape = { "Mythical cape" },
	talisman = { "Xeric's Talisman" },
	digsite = { "Digsite Pendant" },
	fairy_ring = { "Fairy ring", "Spiritual Fairy Tree" },
	spirit_tree = { "Spirit tree", "Spiritual Fairy Tree" },
	pool = { "Pool of" },
	occult_altar = { "Altar of the Occult" },
}

-- What can take you somewhere from inside the house.
export type Furniture = "nexus" | "box" | "glory" | "cape" | "talisman" | "digsite"

export type NexusTeleport = {
	-- its key in the cache's list
	key: number,
	name: string,
	-- the slot it is in (1 to 30); an alternate shares its teleport's slot
	slot: number,
	-- the teleport whose other place it is ("Varrock" for "Grand Exchange")
	alternate_of: string?,
}

-- What the last look around a house found, by kind: the name of the piece. Nil until one has been inside this run.
local surveyed: { [string]: string }? = nil

local function scene_has_exit(): boolean
	for plane = 0, House.PLANES - 1 do
		for _, loc in ipairs(locs(plane) or {}) do
			if loc.id == House.EXIT_PORTAL then
				return true
			end
		end
	end
	return false
end

-- Whether the player is in a house, theirs or another's.
function House.inside(): boolean
	return Host.in_instance() == true and scene_has_exit()
end

-- Whether a tile is the data's stand-in for the house.
function House.is_tile(tile: { x: number, y: number }): boolean
	return tile.x == House.TILE.x and tile.y == House.TILE.y
end

-- Where the house is, by the game's number (1 is Rimmington).
function House.location(): number?
	return Host.varbit(House.LOCATION_VARBIT)
end

local function named(name: string?, wanted: { string }): boolean
	if name == nil then
		return false
	end
	local lower = string.lower(name)
	for _, part in ipairs(wanted) do
		if string.find(lower, string.lower(part), 1, true) ~= nil then
			return true
		end
	end
	return false
end

-- The nearest loc whose name contains `what` (or any of a list), ignoring case, or with this id: on the player's floor if there is one, else on another.
function House.find(what: string | number | { string }): Loc?
	local here = Player.position()
	if here == nil then
		return nil
	end
	local function matches(loc: Loc): boolean
		if type(what) == "number" then
			return loc.id == what
		end
		return named(loc.name, if type(what) == "string" then { what } else what)
	end
	local best: Loc? = nil
	local best_distance = math.huge
	for plane = 0, House.PLANES - 1 do
		for _, loc in ipairs(locs(plane) or {}) do
			if loc.clickable and matches(loc) then
				-- another floor counts as farther than anything on this one
				local d = Objects.distance(loc, here) + (if plane == here.plane then 0 else House.SIZE)
				if d < best_distance then
					best, best_distance = loc, d
				end
			end
		end
	end
	return best
end

-- Goes to a floor by the nearest staircase, one flight at a time. True once on it.
function House.go_to_floor(plane: number): boolean
	for _ = 1, House.PLANES do
		local here = Player.position()
		if here == nil then
			return false
		end
		if here.plane == plane then
			return true
		end
		local stairs = House.find(House.STAIRS)
		if stairs == nil or stairs.plane ~= here.plane then
			Log.log("House", `no stairs on floor {here.plane}`)
			return false
		end
		local option = if plane > here.plane then House.CLIMB_UP else House.CLIMB_DOWN
		if not Objects.approach(stairs, option) then
			return false
		end
		local deadline = time() + House.STAIRS_TIMEOUT_MS
		while (Player.position() or here).plane == here.plane do
			if time() >= deadline then
				return false
			end
			sleep(House.POLL_MS)
		end
	end
	return false
end

-- Finds something built and gets on its floor. The loc to click, or nil when it isn't built or can't be reached.
function House.reach(what: string | number | { string }): Loc?
	local loc = House.find(what)
	if loc == nil then
		return nil
	end
	local here = Player.position()
	if here == nil then
		return nil
	end
	if here.plane == loc.plane then
		return loc
	end
	if not House.go_to_floor(loc.plane) then
		return nil
	end
	return House.find(what)
end

-- Looks around the house the player is in and remembers what is built, for `House.seen`.
function House.survey()
	local found: { [string]: string } = {}
	for plane = 0, House.PLANES - 1 do
		for _, loc in ipairs(locs(plane) or {}) do
			if loc.clickable then
				for kind, names in pairs(House.FURNITURE) do
					if not found[kind] and named(loc.name, names) then
						found[kind] = loc.name :: string
					end
				end
			end
		end
	end
	surveyed = found
end

-- Whether this kind of furniture (a key of `House.FURNITURE`) was built at the last look around, or nil when no look has been taken this run.
function House.seen(kind: string): boolean?
	if surveyed == nil then
		return nil
	end
	return surveyed[kind] ~= nil
end

-- The name of this kind of furniture at the last look around ("Ornate pool of Rejuvenation"), nil when none was seen or no look has been taken this run.
function House.furniture(kind: string): string?
	return if surveyed then surveyed[kind] else nil
end

-- Whether two names are the same place: word by word, where a shortened word ending in an apostrophe ("Fenken'") stands for any word it starts, and one name may be the start of the other ("Kourend" and "Kourend Castle").
function House.same_place(a: string, b: string): boolean
	local function words(text: string): { string }
		local out = {}
		for word in string.gmatch(string.lower(text), "%S+") do
			table.insert(out, word)
		end
		return out
	end
	local function plain(word: string): string
		return (string.gsub(word, "[^%w]", ""))
	end
	local wa, wb = words(a), words(b)
	for i = 1, math.min(#wa, #wb) do
		local x, y = wa[i], wb[i]
		if plain(x) ~= plain(y) then
			local short, long = x, y
			if string.sub(y, -1) == "'" then
				short, long = y, x
			end
			local head = plain(short)
			if string.sub(short, -1) ~= "'" or #head < 3 or string.sub(plain(long), 1, #head) ~= head then
				return false
			end
		end
	end
	return true
end

-- The house's town (`House.LOCATIONS`), nil when it can't be read.
function House.location_name(): string?
	local id = House.location()
	return if id then House.LOCATIONS[id] else nil
end

-- The names of the Nexus's teleports by key, read once from the cache.
local nexus_names: { [number]: string }? = nil

local function struct_string(bytes: string, param: number): string?
	-- a struct is opcodes; 249 holds its params: a count, then per param a string flag, a 3-byte key and a string or an int
	local i = 1
	while i <= #bytes do
		local op = string.byte(bytes, i)
		i += 1
		if op ~= 249 then
			return nil
		end
		local count = string.byte(bytes, i)
		i += 1
		for _ = 1, count do
			local is_string = string.byte(bytes, i) == 1
			local key = string.unpack(">I3", bytes, i + 1)
			i += 4
			if is_string then
				local stop = string.find(bytes, "\0", i, true)
				if stop == nil then
					return nil
				end
				if key == param then
					return string.sub(bytes, i, stop - 1)
				end
				i = stop + 1
			else
				i += 4
			end
		end
	end
	return nil
end

local function load_nexus_names(): { [number]: string }
	if nexus_names ~= nil then
		return nexus_names
	end
	local names: { [number]: string } = {}
	local list = Host.enum_def(House.NEXUS_ENUM)
	if list ~= nil then
		local wanted: { { number } } = {}
		for i, entry in ipairs(list.entries) do
			wanted[i] = { CONFIG_STRUCTS[2], entry.value :: number }
		end
		local files = Host.cache_files(CONFIG_STRUCTS[1], wanted) or {}
		for i, entry in ipairs(list.entries) do
			local bytes = files[i]
			local name = if type(bytes) == "string" then struct_string(bytes, House.NEXUS_NAME_PARAM) else nil
			if name ~= nil then
				names[entry.key] = name
			end
		end
	end
	if next(names) == nil then
		Log.log("House", "couldn't read the Nexus's teleport names")
		return names
	end
	nexus_names = names
	return names
end

-- The Portal Nexus's teleports in its list's order, read from the variables and the cache, without opening anything: empty when it has none (or there is no Nexus).
function House.nexus_teleports(): { NexusTeleport }
	local names = load_nexus_names()
	local out: { NexusTeleport } = {}
	for slot, varbit in ipairs(House.NEXUS_SLOT_VARBITS) do
		local key = Host.varbit(varbit) or 0
		local name = names[key]
		if key > 0 and name ~= nil then
			table.insert(out, { key = key, name = name, slot = slot })
			local alt = House.NEXUS_ALTERNATES[key]
			if alt ~= nil and names[alt.key] ~= nil and (Host.varbit(alt.unlocked_by) or 0) > 0 then
				table.insert(out, { key = alt.key, name = names[alt.key], slot = slot, alternate_of = name })
			end
		end
	end
	return out
end

-- The Nexus teleport to `name` (`House.same_place`), nil when the Nexus doesn't have it.
function House.nexus_teleport(name: string): NexusTeleport?
	local all = House.nexus_teleports()
	for _, t in ipairs(all) do
		if string.lower(t.name) == string.lower(name) then
			return t
		end
	end
	for _, t in ipairs(all) do
		if House.same_place(t.name, name) then
			return t
		end
	end
	return nil
end

-- The name of the Nexus's left-click teleport, nil when it has none.
function House.nexus_left_click(): string?
	local key = Host.varbit(House.NEXUS_LEFT_CLICK_VARBIT) or 0
	return if key > 0 then load_nexus_names()[key] else nil
end

-- The jewellery box's size: what the last look around saw, else the variable. Nil when neither says, as for a basic box (or none) before a visit.
function House.box_tier(): BoxTier?
	local seen = House.furniture("box")
	if seen ~= nil then
		for _, tier in ipairs(House.BOX_TIERS) do
			if string.find(string.lower(seen), tier, 1, true) == 1 then
				return tier
			end
		end
	end
	if surveyed ~= nil and seen == nil then
		return nil
	end
	local value = Host.varbit(House.BOX_VARBIT) or 0
	return if value > 0 then House.BOX_TIERS[value + 1] else nil
end

-- Every place a box of this size (default: the house's) offers, in its menu's order. Some may still be struck through for the account; only the box shows which.
function House.box_places(tier: BoxTier?): { string }
	local size = tier or House.box_tier()
	local out: { string } = {}
	for _, t in ipairs(House.BOX_TIERS) do
		if size == nil then
			break
		end
		for _, place in ipairs(House.BOX_PLACES[t]) do
			table.insert(out, place)
		end
		if t == size then
			break
		end
	end
	return out
end

local function listed(places: { string }, place: string): boolean
	for _, p in ipairs(places) do
		if House.same_place(p, place) then
			return true
		end
	end
	return false
end

-- What in the house can take you to `place`, in the order it is tried: the Nexus and the box from what the variables say (until a visit shows them missing), the mounted pieces once a visit has shown them.
function House.offers(place: string): { Furniture }
	local out: { Furniture } = {}
	if House.seen("nexus") ~= false and House.nexus_teleport(place) ~= nil then
		table.insert(out, "nexus")
	end
	if listed(House.box_places(), place) then
		table.insert(out, "box")
	end
	for _, kind in { "glory", "cape", "talisman", "digsite" } :: { Furniture } do
		if House.seen(kind) == true and listed(House.MOUNTED_PLACES[kind], place) then
			table.insert(out, kind)
		end
	end
	return out
end

-- Starts a teleport to `place` from inside the house by one piece of furniture, going to it first; the trip itself isn't waited for.
-- False with why when it didn't start, and true third when trying again is pointless (it isn't built, or doesn't offer the place).
function House.start_teleport(by: Furniture, place: string): (boolean, string?, boolean?)
	if not House.inside() then
		return false, "not in a house", false
	end
	if by == "nexus" or by == "box" then
		local module: any = lib(
			if by == "box"
				then "@lib/main/interfaces/mainscreen/jewellerybox"
				else "@lib/main/interfaces/mainscreen/nexus"
		)
		local opened, why
		if by == "box" then
			local box = House.reach(House.FURNITURE.box)
			if box == nil then
				return false, "no jewellery box in this house", true
			end
			opened, why = module.open(box)
		else
			opened, why = module.open()
		end
		if not opened then
			return false, why or "couldn't open it", House.find(House.FURNITURE[by]) == nil
		end
		local d = module.find(place)
		if d == nil then
			module.close()
			return false, `{place} isn't there`, true
		end
		local chosen = if by == "box" then module.select(d.name) ~= nil else module.select(d.name)
		if not chosen then
			module.close()
			return false, `{place} couldn't be chosen`, false
		end
		return true, nil, nil
	end
	return lib("@lib/main/interfaces/mainscreen/mounted").teleport(by, place)
end

-- Teleports to `place` from inside the house by whatever offers it (`House.offers`; the nearest when several do) and waits to leave the house. False and why.
function House.teleport(place: string): (boolean, string?)
	local options = House.offers(place)
	if #options == 0 then
		return false, `nothing in this house goes to {place}`
	end
	local here = Player.position()
	table.sort(options, function(a: Furniture, b: Furniture): boolean
		local la, lb = House.find(House.FURNITURE[a]), House.find(House.FURNITURE[b])
		local function d(loc: Loc?): number
			return if loc and here
				then Objects.distance(loc, here) + (if loc.plane == here.plane then 0 else House.SIZE)
				else math.huge
		end
		return d(la) < d(lb)
	end)
	local why: string? = nil
	for _, by in ipairs(options) do
		local started, reason = House.start_teleport(by, place)
		if started then
			local deadline = time() + House.TELEPORT_TIMEOUT_MS
			while House.inside() do
				if time() >= deadline then
					return false, `the {by} didn't take us to {place}`
				end
				sleep(House.POLL_MS)
			end
			return true, nil
		end
		why = reason
	end
	return false, why
end

-- Drinks from the house's pool and waits for it to take (`Player.restore_with`). False and why.
function House.restore(): (boolean, string?)
	local pool = House.reach(House.FURNITURE.pool)
	if pool == nil then
		return false, "no pool in this house"
	end
	return Player.restore_with(function(): boolean
		return Objects.approach(pool, House.POOL_OPTION)
	end, House.RESTORE_TIMEOUT_MS)
end

-- Leaves by the portal. True once outside.
function House.leave(): boolean
	local portal = House.reach(House.EXIT_PORTAL)
	if portal == nil or not Objects.approach(portal, House.EXIT_OPTION) then
		return false
	end
	local deadline = time() + House.LEAVE_TIMEOUT_MS
	while Host.in_instance() == true do
		if time() >= deadline then
			return false
		end
		sleep(House.POLL_MS)
	end
	return true
end

return House
