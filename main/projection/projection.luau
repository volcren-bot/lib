--!strict
local Host = require("../../host")
local game_state = Host.game_state
local connection = Host.connection
local project = Host.project
type FinePoint = Host.FinePoint
local Geometry = require("../../utils/math/geometry")
local Point = Geometry.Point
local Quad = Geometry.Quad
local Box = Geometry.Box
type Point = Geometry.Point
type Quad = Geometry.Quad
type Box = Geometry.Box

export type Tile = {
	x: number,
	y: number,
}

local Projection = {}

Projection.TILE = 128

function Projection.base(): Tile?
	local state = game_state()
	local p = state.position
	if p == nil then
		return nil
	end
	return { x = p.x - p.local_x // Projection.TILE, y = p.y - p.local_y // Projection.TILE }
end

function Projection.arrival(at: Tile): FinePoint?
	local state = game_state()
	local p = state.position
	local camera = state.camera
	if p == nil or camera == nil then
		return nil
	end
	local base_x = p.x - p.local_x // Projection.TILE
	local base_y = p.y - p.local_y // Projection.TILE
	return {
		x = (at.x - base_x) * Projection.TILE + Projection.TILE / 2 - camera.focal_x,
		y = (at.y - base_y) * Projection.TILE + Projection.TILE / 2 - camera.focal_y,
		z = 0,
	}
end

local function screen_points(points: { FinePoint }, shift: { x: number, y: number, plane: number? }?): { Point }?
	local screen = project(points, nil, shift)
	if screen == nil then
		return nil
	end
	local out: { Point } = {}
	for i, p in ipairs(screen) do
		out[i] = Point.new(math.round(p.x), math.round(p.y))
	end
	return out
end

-- Projects `points` as the camera will show them after moving by `shift` (fine units).
function Projection.shifted(points: { FinePoint }, shift: FinePoint, plane: number?): { Point }?
	return screen_points(points, { x = math.round(shift.x), y = math.round(shift.y), plane = plane })
end

function Projection.points(points: { FinePoint }, at: Tile?): { Point }?
	if at then
		local shift = Projection.arrival(at :: Tile)
		if shift == nil then
			return nil
		end
		-- an `at` table may carry the `plane` the player will stand on (a climb or a drop), which the camera's height follows
		return Projection.shifted(points, shift, (at :: any).plane)
	end
	return screen_points(points)
end

function Projection.tile(tile: Tile, height: number?, at: Tile?): Quad?
	local base = Projection.base()
	if base == nil then
		return nil
	end
	local x = (tile.x - base.x) * Projection.TILE
	local y = (tile.y - base.y) * Projection.TILE
	local z = -(height or 0)
	local on = { x = tile.x - base.x, y = tile.y - base.y }
	local corners = Projection.points({
		{ x = x, y = y, z = z, tile = on },
		{ x = x, y = y + Projection.TILE, z = z, tile = on },
		{ x = x + Projection.TILE, y = y + Projection.TILE, z = z, tile = on },
		{ x = x + Projection.TILE, y = y, z = z, tile = on },
	}, at)
	if corners == nil then
		return nil
	end
	return Quad.new(corners[1], corners[2], corners[3], corners[4])
end

export type Cuboid = {
	bottom: Quad,
	top: Quad,
}

function Projection.cuboid(
	fine_x: number,
	fine_y: number,
	size: number?,
	height: number?,
	at: Tile?,
	shift: FinePoint?
): Cuboid?
	local half = (size or 1) * Projection.TILE / 2
	local up = -(height or 200)
	local function tile_of(value: number, low: boolean): number
		return math.floor((value + (if low then 1 else -1)) / Projection.TILE)
	end
	local corners = {
		{ x = fine_x - half, y = fine_y - half, low_x = true, low_y = true },
		{ x = fine_x - half, y = fine_y + half, low_x = true, low_y = false },
		{ x = fine_x + half, y = fine_y + half, low_x = false, low_y = false },
		{ x = fine_x + half, y = fine_y - half, low_x = false, low_y = true },
	}
	local points: { FinePoint } = {}
	for _, z in ipairs({ 0, up }) do
		for _, c in ipairs(corners) do
			table.insert(
				points,
				{ x = c.x, y = c.y, z = z, tile = { x = tile_of(c.x, c.low_x), y = tile_of(c.y, c.low_y) } }
			)
		end
	end
	local screen
	if shift then
		screen = Projection.shifted(points, shift)
	else
		screen = Projection.points(points, at)
	end
	if screen == nil then
		return nil
	end
	return {
		bottom = Quad.new(screen[1], screen[2], screen[3], screen[4]),
		top = Quad.new(screen[5], screen[6], screen[7], screen[8]),
	}
end

function Projection.bounds(cuboid: Cuboid): Box
	local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
	for _, quad in ipairs({ cuboid.bottom, cuboid.top }) do
		for _, p in ipairs(Quad.corners(quad)) do
			x1 = math.min(x1, p.x)
			y1 = math.min(y1, p.y)
			x2 = math.max(x2, p.x)
			y2 = math.max(y2, p.y)
		end
	end
	return Box.new(x1, y1, x2, y2)
end

function Projection.box_on_screen(box: Box): boolean
	local conn = connection()
	return box.x1 >= 0 and box.y1 >= 0 and box.x2 < conn.width and box.y2 < conn.height
end

function Projection.on_screen(quad: Quad): boolean
	local conn = connection()
	for _, p in ipairs(Quad.corners(quad)) do
		if p.x < 0 or p.y < 0 or p.x >= conn.width or p.y >= conn.height then
			return false
		end
	end
	return true
end

return Projection
