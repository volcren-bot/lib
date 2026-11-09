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
type Clickbox = Clickbox.Clickbox

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
	return entry.kind == MENU_LOC and entry.id == loc.id
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

function Objects.interact(
	loc: Loc,
	option: string | { string },
	walk_timeout_ms: (number | false)?,
	face: boolean?,
	spam: number?
): boolean
	return Clickbox.interact(
		clickbox_of(loc),
		hovered_by(loc),
		label(loc),
		option,
		owned_by(loc),
		if face == false then nil else tile_of(loc),
		walk_timeout_ms,
		spam
	)
end

function Objects.approach(loc: Loc, options: string | { string }, opts: Clickbox.Approach?): boolean
	return Clickbox.approach(clickbox_of(loc), hovered_by(loc), label(loc), options, owned_by(loc), tile_of(loc), opts)
end

return Objects
