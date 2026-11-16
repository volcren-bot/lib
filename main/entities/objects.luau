--!strict
local Host = require("@lib/host")
local locs = Host.locs
local loc_model = Host.loc_model
local menu = Host.menu
type Loc = Host.Loc
type MenuEntry = Host.MenuEntry
type NpcModel = Host.NpcModel
type Tile = Host.Tile
local Geometry = require("@lib/utils/math/geometry")
type Point = Geometry.Point
local Clickbox = require("@lib/main/clickbox")
local Mouse = require("@lib/utils/input/mouse")
local Projection = require("@lib/main/projection/projection")
local SafeSpot = require("@lib/main/safespot")
local Walker = require("@lib/main/walker")
type Clickbox = Clickbox.Clickbox

local band, bor = bit32.band, bit32.bor

local Objects = {}

Objects.WALL = 0
Objects.WALL_DECORATION = 1
Objects.GAME_OBJECT = 2
Objects.GROUND_DECORATION = 3

local function matches(loc: Loc, what: string | number): boolean
	if type(what) == "number" then
		return loc.id == what
	end
	return loc.name ~= nil and string.lower((string.gsub(loc.name, "<[^>]*>", ""))) == what
end

local function label(loc: Loc): string
	return loc.name or tostring(loc.id)
end

local function centre(loc: Loc): (number, number)
	return loc.scene_x * Projection.TILE + loc.size_x * Projection.TILE / 2,
		loc.scene_y * Projection.TILE + loc.size_y * Projection.TILE / 2
end

function Objects.distance(loc: Loc, from: Tile): number
	local dx = math.max(loc.x - from.x, 0, from.x - (loc.x + loc.size_x - 1))
	local dy = math.max(loc.y - from.y, 0, from.y - (loc.y + loc.size_y - 1))
	return math.max(dx, dy)
end

function Objects.find(what: (string | number)?): { Loc }?
	local all = locs()
	if all == nil then
		return nil
	end
	local wanted = if type(what) == "string" then string.lower(what) else what
	local found: { Loc } = {}
	for _, loc in ipairs(all) do
		if loc.clickable and (wanted == nil or matches(loc, wanted)) then
			table.insert(found, loc)
		end
	end
	return found
end

function Objects.nearest(what: (string | number)?, from: Tile): Loc?
	local found = Objects.find(what)
	if found == nil then
		return nil
	end
	local best: Loc? = nil
	local best_distance = math.huge
	for _, loc in ipairs(found) do
		local d = Objects.distance(loc, from)
		if d < best_distance then
			best, best_distance = loc, d
		end
	end
	return best
end

function Objects.model(loc: Loc): NpcModel?
	return (loc_model(loc))
end

function Objects.clickbox(loc: Loc): Clickbox?
	local model = Objects.model(loc)
	if model == nil then
		return nil
	end
	return Clickbox.from_model(model, label(loc))
end

local MENU_LOC = 3

function Objects.owns(loc: Loc, entry: MenuEntry): boolean
	return entry.kind == MENU_LOC and entry.id == loc.id and entry.x == loc.x and entry.y == loc.y
end

function Objects.hovered(loc: Loc): boolean
	for _, entry in ipairs(menu() or {}) do
		if Objects.owns(loc, entry) then
			return true
		end
	end
	return false
end

function Objects.projected(loc: Loc, at: Tile): Clickbox?
	local centre_x, centre_y = centre(loc)
	local cuboid = Projection.cuboid(centre_x, centre_y, math.max(loc.size_x, loc.size_y), nil, at)
	if cuboid == nil then
		return nil
	end
	return Clickbox.from_cuboid(cuboid)
end

local function clickbox_of(loc: Loc): Clickbox.Aim
	local x, y = centre(loc)
	local anchor: Clickbox.Anchor = { x = x, y = y, size = math.max(loc.size_x, loc.size_y) }
	return Clickbox.walking(function()
		return Objects.clickbox(loc)
	end, function()
		return anchor
	end, label(loc))
end

local function hovered_by(loc: Loc): () -> boolean
	return function()
		return Objects.hovered(loc)
	end
end

local function owned_by(loc: Loc): (MenuEntry) -> boolean
	return function(entry)
		return Objects.owns(loc, entry)
	end
end

local function tile_of(loc: Loc): () -> Tile?
	local middle = { x = loc.x + (loc.size_x - 1) / 2, y = loc.y + (loc.size_y - 1) / 2 }
	return function()
		return middle
	end
end

function Objects.hover(loc: Loc): boolean
	return Clickbox.hover(clickbox_of(loc), hovered_by(loc), label(loc), tile_of(loc))
end

function Objects.hover_async(loc: Loc, at: Tile?): boolean
	local name = label(loc)
	if at == nil then
		return Clickbox.hover_async(clickbox_of(loc), name)
	end
	return Clickbox.hover_async(function()
		return Objects.projected(loc, at)
	end, name)
end

function Objects.click(loc: Loc, button: Mouse.Button?, spam: number?): boolean
	return Clickbox.click(clickbox_of(loc), hovered_by(loc), label(loc), button, tile_of(loc), spam)
end

local function act_of(loc: Loc): Clickbox.ActTarget
	return {
		model = { target = "loc", kind = loc.kind, scene_x = loc.scene_x, scene_y = loc.scene_y, id = loc.id },
		entry = { kind = MENU_LOC, id = loc.id, x = loc.x, y = loc.y },
	}
end

function Objects.interact(
	loc: Loc,
	option: string | { string },
	walk_timeout_ms: (number | false)?,
	face: boolean?,
	spam: number?,
	menu: boolean?
): boolean
	return Clickbox.interact(
		clickbox_of(loc),
		hovered_by(loc),
		label(loc),
		option,
		owned_by(loc),
		if face == false then nil else tile_of(loc),
		walk_timeout_ms,
		spam,
		menu,
		act_of(loc)
	)
end

function Objects.stand_tiles(loc: Loc): { Tile }?
	local me = Host.game_state().position
	local ground = loc.kind == Objects.GROUND_DECORATION
	if (loc.kind ~= Objects.GAME_OBJECT and not ground) or me == nil or (me.plane or 0) ~= loc.plane then
		return nil
	end
	local x1, y1 = loc.x, loc.y
	local x2, y2 = loc.x + loc.size_x - 1, loc.y + loc.size_y - 1
	local grid = SafeSpot.grid({ x1 = x1 - 1, y1 = y1 - 1, x2 = x2 + 1, y2 = y2 + 1 })
	if grid == nil then
		return nil
	end
	local F = SafeSpot.FLAG
	local tiles: { Tile } = {}
	local function side(x: number, y: number, edge_x: number, edge_y: number, outer: number, inner: number)
		local open = band(SafeSpot.flags(grid, x, y), bor(F.BLOCKED, outer)) == 0
		if open and band(SafeSpot.flags(grid, edge_x, edge_y), inner) == 0 then
			table.insert(tiles, { x = x, y = y })
		end
	end
	if ground then
		for x = x1, x2 do
			for y = y1, y2 do
				if band(SafeSpot.flags(grid, x, y), F.BLOCKED) == 0 then
					table.insert(tiles, { x = x, y = y })
				end
			end
		end
	end
	for x = x1, x2 do
		side(x, y1 - 1, x, y1, F.WALL_NORTH, F.WALL_SOUTH)
		side(x, y2 + 1, x, y2, F.WALL_SOUTH, F.WALL_NORTH)
	end
	for y = y1, y2 do
		side(x1 - 1, y, x1, y, F.WALL_EAST, F.WALL_WEST)
		side(x2 + 1, y, x2, y, F.WALL_WEST, F.WALL_EAST)
	end
	return tiles
end

function Objects.plain_walk(loc: Loc): boolean
	local stand = Objects.stand_tiles(loc)
	if stand == nil or #stand == 0 then
		return Walker.plain_walk({ x = loc.x, y = loc.y }, 1)
	end
	local me = Walker.position()
	if me == nil then
		return false
	end
	table.sort(stand, function(a: Tile, b: Tile): boolean
		return Walker.distance(me, a) < Walker.distance(me, b)
	end)
	for i = 1, math.min(#stand, Clickbox.STAND_CANDIDATES) do
		if Walker.plain_walk(stand[i], 0) then
			return true
		end
	end
	return false
end

function Objects.approach(loc: Loc, options: string | { string }, opts: Clickbox.Approach?): boolean
	local o: Clickbox.Approach = if opts then table.clone(opts) else {}
	if o.stand == nil then
		o.stand = Objects.stand_tiles(loc)
	end
	return Clickbox.approach(
		clickbox_of(loc),
		hovered_by(loc),
		label(loc),
		options,
		owned_by(loc),
		tile_of(loc),
		o,
		act_of(loc)
	)
end

return Objects
