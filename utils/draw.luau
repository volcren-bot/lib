--!strict
local Host = require("../host")
local draw_rect = Host.draw_rect
local clear_overlay = Host.clear_overlay
local draw_line = Host.draw_line
local draw_lines = Host.draw_lines
local draw_batch = Host.draw_batch
local Geometry = require("./math/geometry")
type Point = Geometry.Point
type Quad = Geometry.Quad
type Area = Host.Area
type Corners = Host.Corners
type Shape = Host.Shape
local Draw = {}

-- The shapes of the running `Draw.batch`, nil outside one.
local batch: { Shape }? = nil

export type Color = {
	r: number,
	g: number,
	b: number,
	a: number?,
}

function Draw.color(r: number, g: number, b: number, a: number?): Color
	return { r = r, g = g, b = b, a = a or 255 }
end

Draw.RED = Draw.color(255, 0, 0)
Draw.GREEN = Draw.color(0, 255, 0)
Draw.BLUE = Draw.color(0, 0, 255)
Draw.YELLOW = Draw.color(255, 255, 0)
Draw.CYAN = Draw.color(0, 255, 255)
Draw.MAGENTA = Draw.color(255, 0, 255)
Draw.WHITE = Draw.color(255, 255, 255)
Draw.BLACK = Draw.color(0, 0, 0)

local function shape(shapes: { Shape }, kind: "rect" | "line", x1: number, y1: number, x2: number, y2: number, c: Color)
	table.insert(shapes, { kind = kind, x1 = x1, y1 = y1, x2 = x2, y2 = y2, r = c.r, g = c.g, b = c.b, a = c.a })
end

function Draw.rect(x1: number, y1: number, x2: number, y2: number, color: Color?)
	local c = color or Draw.RED
	x1, y1, x2, y2 = math.round(x1), math.round(y1), math.round(x2), math.round(y2)
	if batch then
		shape(batch, "rect", x1, y1, x2, y2, c)
	else
		draw_rect(x1, y1, x2, y2, c.r, c.g, c.b, c.a or 255)
	end
end

function Draw.box(box: Area, color: Color?)
	Draw.rect(box.x, box.y, box.x + box.width - 1, box.y + box.height - 1, color)
end

function Draw.button(button: Corners, color: Color?)
	Draw.rect(button.x1, button.y1, button.x2, button.y2, color)
end

function Draw.line(a: Point, b: Point, color: Color?)
	local c = color or Draw.RED
	if batch then
		shape(batch, "line", a.x, a.y, b.x, b.y, c)
	else
		draw_line(math.round(a.x), math.round(a.y), math.round(b.x), math.round(b.y), c.r, c.g, c.b, c.a or 255)
	end
end

function Draw.lines(segments: { { Point } }, color: Color?)
	local c = color or Draw.RED
	if batch then
		for _, s in ipairs(segments) do
			shape(batch, "line", s[1].x, s[1].y, s[2].x, s[2].y, c)
		end
		return
	end
	local lines = table.create(#segments) :: { { number } }
	for i, s in ipairs(segments) do
		lines[i] = { s[1].x, s[1].y, s[2].x, s[2].y }
	end
	draw_lines(lines, c.r, c.g, c.b, c.a or 255)
end

function Draw.polygon(points: { Point }, color: Color?)
	local segments = table.create(#points) :: { { Point } }
	for i, p in ipairs(points) do
		segments[i] = { p, points[i % #points + 1] }
	end
	Draw.lines(segments, color)
end

function Draw.quad(quad: Quad, color: Color?)
	Draw.polygon(Geometry.Quad.corners(quad), color)
end

function Draw.cuboid(cuboid: { bottom: Quad, top: Quad }, color: Color?)
	local bottom, top = Geometry.Quad.corners(cuboid.bottom), Geometry.Quad.corners(cuboid.top)
	local segments = {}
	for i = 1, 4 do
		local j = i % 4 + 1
		table.insert(segments, { bottom[i], bottom[j] })
		table.insert(segments, { top[i], top[j] })
		table.insert(segments, { bottom[i], top[i] })
	end
	Draw.lines(segments, color)
end

function Draw.clear()
	if batch then
		-- Everything batched so far would be wiped anyway.
		local clear: Shape = { kind = "clear" }
		table.clear(batch)
		table.insert(batch, clear)
	else
		clear_overlay()
	end
end

function Draw.batch(paint: () -> ())
	if batch then
		paint()
		return
	end
	local shapes: { Shape } = {}
	batch = shapes
	local ok, err = pcall(paint)
	batch = nil
	if not ok then
		error(err, 0)
	end
	draw_batch(shapes)
end

return Draw
