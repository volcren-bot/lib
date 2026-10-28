--!strict
local Host = require("../../host")
local locs = Host.locs
local loc_model = Host.loc_model
local menu = Host.menu
type Loc = Host.Loc
type MenuEntry = Host.MenuEntry
type NpcModel = Host.NpcModel
type Tile = Host.Tile
local Geometry = require("../../utils/math/geometry")
type Point = Geometry.Point
local Mouse = require("../../utils/input/mouse")
local Clickbox = require("../clickbox")
local Projection = require("../projection/projection")
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
	return loc.name ~= nil and string.lower((string.gsub(loc.name, "<[^>]*>", ""))) == string.lower(what)
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
	local found: { Loc } = {}
	for _, loc in ipairs(all) do
		if loc.clickable and (what == nil or matches(loc, what)) then
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
	local model = loc_model(loc)
	if model == nil then
		return nil
	end
	return model
end

function Objects.clickbox(loc: Loc): Clickbox?
	local model = Objects.model(loc)
	if model == nil then
		return nil
	end
	return Clickbox.from_model(model, loc.name or tostring(loc.id))
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
	local centre_x = loc.scene_x * Projection.TILE + loc.size_x * Projection.TILE / 2
	local centre_y = loc.scene_y * Projection.TILE + loc.size_y * Projection.TILE / 2
	local cuboid = Projection.cuboid(centre_x, centre_y, math.max(loc.size_x, loc.size_y), nil, at)
	if cuboid == nil then
		return nil
	end
	return Clickbox.from_cuboid(cuboid)
end

local function clickbox_of(loc: Loc): Clickbox.Aim
	local anchor: Clickbox.Anchor = {
		x = loc.scene_x * Projection.TILE + loc.size_x * Projection.TILE / 2,
		y = loc.scene_y * Projection.TILE + loc.size_y * Projection.TILE / 2,
		size = math.max(loc.size_x, loc.size_y),
	}
	return Clickbox.walking(function()
		return Objects.clickbox(loc)
	end, function()
		return anchor
	end, loc.name or tostring(loc.id))
end

local function hovered_by(loc: Loc): () -> boolean
	return function()
		return Objects.hovered(loc)
	end
end

local function tile_of(loc: Loc): () -> Tile?
	local middle = { x = loc.x + (loc.size_x - 1) / 2, y = loc.y + (loc.size_y - 1) / 2 }
	return function()
		return middle
	end
end

function Objects.hover(loc: Loc): boolean
	return Clickbox.hover(clickbox_of(loc), hovered_by(loc), loc.name or tostring(loc.id), tile_of(loc))
end

function Objects.click(loc: Loc, button: Mouse.Button?): boolean
	return Clickbox.click(clickbox_of(loc), hovered_by(loc), loc.name or tostring(loc.id), button, tile_of(loc))
end

-- `face` false leaves the camera alone (for a loc already on screen).
function Objects.interact(
	loc: Loc,
	option: string | { string },
	walk_timeout_ms: (number | false)?,
	face: boolean?
): boolean
	local function owns(entry: MenuEntry): boolean
		return Objects.owns(loc, entry)
	end
	return Clickbox.interact(
		clickbox_of(loc),
		hovered_by(loc),
		loc.name or tostring(loc.id),
		option,
		owns,
		if face == false then nil else tile_of(loc),
		walk_timeout_ms
	)
end

function Objects.approach(loc: Loc, options: string | { string }, opts: Clickbox.Approach?): boolean
	local function owns(entry: MenuEntry): boolean
		return Objects.owns(loc, entry)
	end
	return Clickbox.approach(
		clickbox_of(loc),
		hovered_by(loc),
		loc.name or tostring(loc.id),
		options,
		owns,
		tile_of(loc),
		opts
	)
end

return Objects
