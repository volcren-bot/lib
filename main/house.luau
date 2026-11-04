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
-- Varbits that say something is built, readable from anywhere. The first of the Portal Nexus's teleports, and the jewellery box's.
House.NEXUS_VARBIT = 6654
House.BOX_VARBIT = 2308
House.LOCATION_VARBIT = 2187
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
}

-- What the last look around a house found, by kind. Nil until one has been inside this run.
local surveyed: { [string]: boolean }? = nil

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
	local found: { [string]: boolean } = {}
	for plane = 0, House.PLANES - 1 do
		for _, loc in ipairs(locs(plane) or {}) do
			if loc.clickable then
				for kind, names in pairs(House.FURNITURE) do
					if not found[kind] and named(loc.name, names) then
						found[kind] = true
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
	return surveyed[kind] == true
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
