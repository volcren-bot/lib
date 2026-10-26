--!strict
local Random = require("./random")
local trunc = Random.trunc

export type Point = { x: number, y: number }
export type Box = { x1: number, y1: number, x2: number, y2: number }
export type Circle = { x: number, y: number, radius: number }
export type Quad = { top: Point, right: Point, bottom: Point, left: Point }
export type Polygon = { Point }
type Area = { x: number, y: number, width: number, height: number }

local round = math.round

local function pt(x: number, y: number): Point
	return { x = x, y = y }
end

local Point = {}
local Box = {}
local Circle = {}
local Quad = {}
local Polygon = {}
local Triangle = {}

Point.new = pt

function Point.distance(a: Point, b: Point): number
	return math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
end

function Point.angle_between(a: Point, b: Point): number
	return (math.deg(math.atan2(b.y - a.y, b.x - a.x)) - 90) % 360
end

function Point.rotate(p: Point, radians: number, center: Point): Point
	local s, c = math.sin(radians), math.cos(radians)
	return pt(
		round(center.x + c * (p.x - center.x) - s * (p.y - center.y)),
		round(center.y + s * (p.x - center.x) + c * (p.y - center.y))
	)
end

function Point.random(p: Point, range: number): Point
	local span = 2 * range + 1
	return pt(p.x - range + math.floor(math.random() * span), p.y - range + math.floor(math.random() * span))
end

local function nearest_on_line(p: Point, p1: Point, p2: Point): (Point, number)
	local dx, dy = p2.x - p1.x, p2.y - p1.y
	local d = dx * dx + dy * dy
	if d == 0 then
		return p1, math.sqrt((p.x - p1.x) ^ 2 + (p.y - p1.y) ^ 2)
	end
	local f = ((p.x - p1.x) * dx + (p.y - p1.y) * dy) / d
	if f < 0 then
		return p1, math.sqrt((p.x - p1.x) ^ 2 + (p.y - p1.y) ^ 2)
	elseif f > 1 then
		return p2, math.sqrt((p.x - p2.x) ^ 2 + (p.y - p2.y) ^ 2)
	end
	local nearest = pt(round(p1.x + f * dx), round(p1.y + f * dy))
	return nearest, math.sqrt((p.x - nearest.x) ^ 2 + (p.y - nearest.y) ^ 2)
end

local function in_triangle(p: Point, a: Point, b: Point, c: Point): boolean
	local function orientation(p1: Point, p2: Point): number
		local o = (p2.x - p1.x) * (p.y - p1.y) - (p.x - p1.x) * (p2.y - p1.y)
		return if o > 0 then 1 elseif o < 0 then -1 else 0
	end
	local or1, or2 = orientation(a, b), orientation(b, c)
	if or1 * or2 == -1 then
		return false
	end
	local or3 = orientation(c, a)
	if or1 == or3 or or3 == 0 then
		return true
	elseif or1 == 0 then
		return or2 * or3 >= 0
	elseif or2 == 0 then
		return or1 * or3 >= 0
	end
	return false
end

function Polygon.area(poly: Polygon): number
	local sum = 0
	local j = #poly
	for i = 1, #poly do
		sum += poly[j].x * poly[i].y - poly[j].y * poly[i].x
		j = i
	end
	return math.abs(sum) * 0.5
end

function Polygon.contains(poly: Polygon, p: Point): boolean
	if #poly < 3 then
		return false
	end
	local inside = false
	local j = #poly
	for i = 1, #poly do
		local a, b = poly[i], poly[j]
		if (a.y <= p.y and p.y < b.y) or (b.y <= p.y and p.y < a.y) then
			if p.x - a.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) then
				inside = not inside
			end
		end
		j = i
	end
	return inside
end

function Polygon.convex_hull(points: { Point }): Polygon
	local sorted: { Point } = table.clone(points)
	table.sort(sorted, function(a: Point, b: Point)
		return a.x < b.x or (a.x == b.x and a.y < b.y)
	end)
	if #sorted < 3 then
		return sorted
	end
	local function cross(o: Point, a: Point, b: Point): number
		return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
	end
	local hull: Polygon = {}
	for pass = 1, 2 do
		local start = #hull
		local first, last, step = 1, #sorted, 1
		if pass == 2 then
			first, last, step = #sorted, 1, -1
		end
		for i = first, last, step do
			local p = sorted[i]
			while #hull >= start + 2 and cross(hull[#hull - 1], hull[#hull], p) <= 0 do
				table.remove(hull)
			end
			table.insert(hull, p)
		end
		table.remove(hull)
	end
	return hull
end

function Polygon.nearest_edge(poly: Polygon, p: Point): Point
	if #poly == 0 then
		return pt(0, 0)
	end
	local best, result = math.huge, poly[1]
	for i = 1, #poly do
		local q, dist = nearest_on_line(p, poly[i], poly[i % #poly + 1])
		if dist < best then
			best, result = dist, q
		end
	end
	return result
end

function Polygon.random_weighted_point(poly: Polygon, from: Point, weight: number?, bias: number?): Point
	local w, b = weight or 10, bias or 1
	local area = Polygon.area(poly)
	if b > 0 then
		local xr, yr = 0, 0
		for _, p in poly do
			xr += math.abs(p.x - from.x)
			yr += math.abs(p.y - from.y)
		end
		xr /= #poly
		yr /= #poly
		from = pt(from.x + round(Random.gauss(0, xr * b) / w), from.y + round(Random.gauss(0, yr * b) / w))
	end
	if not Polygon.contains(poly, from) then
		from = Polygon.nearest_edge(poly, from)
	end

	local r = math.random() * area
	local sum = 0
	for i = 1, #poly do
		local tri = { from, poly[i], poly[i % #poly + 1] }
		sum += Triangle.area(tri)
		if r < sum then
			return Triangle.random_weighted_point(tri, from, w, 0)
		end
	end
	return from
end

function Triangle.area(tri: Polygon): number
	local a, b, c = tri[1], tri[2], tri[3]
	return math.ceil(math.abs((a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y)) / 2))
end

function Triangle.random_weighted_point(tri: Polygon, from: Point, weight: number?, bias: number?): Point
	local w, b = weight or 10, bias or 1
	local a, bb, c = tri[1], tri[2], tri[3]
	if b > 0 and w ~= 0 then
		local xr = math.abs(a.x - from.x) + math.abs(bb.x - from.x) + math.abs(c.x - from.x)
		local yr = math.abs(a.y - from.y) + math.abs(bb.y - from.y) + math.abs(c.y - from.y)
		from = pt(from.x + round(Random.gauss(0, xr / 3 * b) / w), from.y + round(Random.gauss(0, yr / 3 * b) / w))
	end
	if not in_triangle(from, a, bb, c) then
		from = Polygon.nearest_edge(tri, from)
	end

	local r1, r2 = math.random(), math.random()
	if r1 + r2 > 1 then
		r1, r2 = 1 - r1, 1 - r2
	end
	local r3 = math.random()
	local sum = 1 + w * r3 + 0.0000001
	local u, v, ww, t = r1 / sum, r2 / sum, (1 - r1 - r2) / sum, (w * r3) / sum
	return pt(round(u * a.x + v * bb.x + ww * c.x + t * from.x), round(u * a.y + v * bb.y + ww * c.y + t * from.y))
end

function Triangle.contains(tri: Polygon, p: Point): boolean
	return in_triangle(p, tri[1], tri[2], tri[3])
end

function Triangle.centroid(tri: Polygon): Point
	return pt((tri[1].x + tri[2].x + tri[3].x) / 3, (tri[1].y + tri[2].y + tri[3].y) / 3)
end

Triangle.CENTER_SPREAD = 0.12
Triangle.CENTER_TRIES = 20

function Triangle.random_point_near_center(tri: Polygon, spread: number?): Point
	local s = spread or Triangle.CENTER_SPREAD
	local a, b, c = tri[1], tri[2], tri[3]
	for _ = 1, Triangle.CENTER_TRIES do
		local u, v = Random.gauss(1 / 3, s), Random.gauss(1 / 3, s)
		local w = 1 - u - v
		if u >= 0 and v >= 0 and w >= 0 then
			return pt(round(u * a.x + v * b.x + w * c.x), round(u * a.y + v * b.y + w * c.y))
		end
	end
	local center = Triangle.centroid(tri)
	return pt(round(center.x), round(center.y))
end

function Box.new(x1: number, y1: number, x2: number, y2: number): Box
	return { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
end

function Box.from_area(a: Area): Box
	return Box.new(a.x, a.y, a.x + a.width - 1, a.y + a.height - 1)
end

function Box.contains(b: Box, p: Point): boolean
	return p.x >= b.x1 and p.y >= b.y1 and p.x <= b.x2 and p.y <= b.y2
end

function Box.center(b: Box): Point
	return pt(trunc((b.x1 + b.x2) / 2), trunc((b.y1 + b.y2) / 2))
end

function Box.corners(b: Box): Polygon
	return { pt(b.x1, b.y1), pt(b.x2, b.y1), pt(b.x2, b.y2), pt(b.x1, b.y2) }
end

function Box.random_point(b: Box): Point
	return pt(Random.range(b.x1, b.x2), Random.range(b.y1, b.y2))
end

function Box.random_point_center(b: Box): Point
	return pt(trunc(Random.mean(b.x1, b.x2)), trunc(Random.mean(b.y1, b.y2)))
end

function Box.random_skewed_point(b: Box, from: Point, force: number?): Point
	local f = force or 0.35
	local fx = if from.x < b.x1 then b.x1 elseif from.x > b.x2 then b.x2 else from.x
	local fy = if from.y < b.y1 then b.y1 elseif from.y > b.y2 then b.y2 else from.y
	local c = Box.center(b)
	local r = math.sqrt((fx - c.x) ^ 2 + (fy - c.y) ^ 2) * f
	local angle = math.atan2(c.y - fy, c.x - fx)
	fx += round(math.cos(angle) * r)
	fy += round(math.sin(angle) * r)
	return pt(round(Random.mode(fx, b.x1, b.x2, 4.0)), round(Random.mode(fy, b.y1, b.y2, 4.0)))
end

function Box.random_weighted_point(b: Box, from: Point, weight: number?, bias: number?): Point
	return Polygon.random_weighted_point(Box.corners(b), from, weight, bias)
end

function Circle.new(x: number, y: number, radius: number): Circle
	return { x = x, y = y, radius = radius }
end

function Circle.contains(c: Circle, p: Point): boolean
	return math.sqrt((p.x - c.x) ^ 2 + (p.y - c.y) ^ 2) <= c.radius
end

function Circle.point_at_degrees(c: Circle, degrees: number): Point
	local radians = math.rad(degrees) - math.pi / 2
	return pt(round(c.radius * math.cos(radians)) + c.x, round(c.radius * math.sin(radians)) + c.y)
end

function Circle.random_point(c: Circle): Point
	local r = math.floor(c.radius * math.sqrt(math.random()))
	local theta = math.random() * 2 * math.pi
	return pt(c.x + round(r * math.cos(theta)), c.y + round(r * math.sin(theta)))
end

function Circle.random_point_center(c: Circle): Point
	local r = math.floor(c.radius * math.sqrt(Random.left(0.0, 1.0)))
	local theta = math.random() * 2 * math.pi
	return pt(c.x + round(r * math.cos(theta)), c.y + round(r * math.sin(theta)))
end

function Circle.random_skewed_point(c: Circle, from: Point, force: number?): Point
	local center = pt(c.x, c.y)
	if not Circle.contains(c, from) then
		local angle = math.atan2(from.y - c.y, from.x - c.x)
		from = pt(round(c.x + c.radius * math.cos(angle)), round(c.y + c.radius * math.sin(angle)))
	end
	local r = math.sqrt((from.x - c.x) ^ 2 + (from.y - c.y) ^ 2) * (force or 0.35)

	local angle = math.atan2(c.y - from.y, c.x - from.x)
	local skewed = pt(from.x + round(math.cos(angle) * r), from.y + round(math.sin(angle) * r))
	local result = pt(round(Random.mode(skewed.x, from.x, c.x, 2.0)), round(Random.mode(skewed.y, from.y, c.y, 2.0)))

	local degrees = Point.angle_between(from, center)
	return Point.rotate(result, Point.angle_between(result, center) + degrees, center)
end

function Circle.random_weighted_point(c: Circle, from: Point, weight: number?, bias: number?): Point
	local w, b = weight or 10, bias or 1
	if b > 0 and w ~= 0 then
		from = pt(
			from.x + round(Random.gauss(0, c.radius * b / 2) / w),
			from.y + round(Random.gauss(0, c.radius * b / 2) / w)
		)
	end
	if not Circle.contains(c, from) then
		from = Circle.point_at_degrees(c, Point.angle_between(from, pt(c.x, c.y)))
	end

	local angle = math.random() * 2 * math.pi
	local dist = math.sqrt(math.random()) * c.radius
	local rand_x, rand_y = c.x + math.cos(angle) * dist, c.y + math.sin(angle) * dist

	local r1, r2 = 1, w * math.random()
	local sum = r1 + r2 + 0.0000001
	local u, t = r1 / sum, r2 / sum
	return pt(round(u * rand_x + t * from.x), round(u * rand_y + t * from.y))
end

function Quad.new(top: Point, right: Point, bottom: Point, left: Point): Quad
	return { top = top, right = right, bottom = bottom, left = left }
end

function Quad.corners(q: Quad): Polygon
	return { q.top, q.right, q.bottom, q.left }
end

function Quad.mean(q: Quad): Point
	return pt(
		trunc((q.top.x + q.right.x + q.bottom.x + q.left.x) / 4),
		trunc((q.top.y + q.right.y + q.bottom.y + q.left.y) / 4)
	)
end

function Quad.contains(q: Quad, p: Point): boolean
	return in_triangle(p, q.top, q.bottom, q.right) or in_triangle(p, q.top, q.left, q.bottom)
end

function Quad.nearest_edge(q: Quad, p: Point): Point
	local edges = { { q.top, q.left }, { q.left, q.bottom }, { q.bottom, q.right }, { q.right, q.top } }
	local best, result = math.huge, q.top
	for _, edge in edges do
		local nearest, dist = nearest_on_line(p, edge[1], edge[2])
		if dist < best then
			best, result = dist, nearest
		end
	end
	return result
end

local function quad_frame(q: Quad): (number, Point, number, number, number, number)
	local top, bottom, left = q.top, q.bottom, q.left
	local a = math.atan2(left.y - top.y, left.x - top.x)
	local x = (top.x + q.right.x + bottom.x + left.x) / 4
	local y = (top.y + q.right.y + bottom.y + left.y) / 4
	local half_w = math.sqrt((left.y - top.y) ^ 2 + (left.x - top.x) ^ 2) / 2
	local half_h = math.sqrt((left.y - bottom.y) ^ 2 + (left.x - bottom.x) ^ 2) / 2
	local x1, y1, x2, y2 = x - half_w, y - half_h, x + half_w, y + half_h
	local center = pt(round((x2 + x1) / 2 + (math.random() * 2 - 1)), round((y2 + y1) / 2 + (math.random() * 2 - 1)))
	return a, center, x1, y1, x2, y2
end

function Quad.random_point(q: Quad): Point
	local a, center, x1, y1, x2, y2 = quad_frame(q)
	local p = pt(Random.range(round(x1) + 2, round(x2) - 2), Random.range(round(y1) + 2, round(y2) - 2))
	return Point.rotate(p, a, center)
end

function Quad.random_point_center(q: Quad): Point
	local a, center, x1, y1, x2, y2 = quad_frame(q)
	local p = pt(round(Random.mean(x1 + 1, x2 - 1)), round(Random.mean(y1 + 1, y2 - 1)))
	return Point.rotate(p, a, center)
end

function Quad.random_skewed_point(q: Quad, from: Point, force: number?): Point
	if not Quad.contains(q, from) then
		from = Quad.nearest_edge(q, from)
	end
	local c = Quad.mean(q)
	local r = math.sqrt((from.x - c.x) ^ 2 + (from.y - c.y) ^ 2) * (force or 0.35)
	local angle = math.atan2(c.y - from.y, c.x - from.x)
	local skewed = pt(from.x + round(math.cos(angle) * r), from.y + round(math.sin(angle) * r))
	local corners = Quad.corners(q)
	local corner = corners[math.random(1, 4)]
	return pt(round(Random.mode(skewed.x, from.x, corner.x, 4.0)), round(Random.mode(skewed.y, from.y, corner.y, 4.0)))
end

function Quad.random_weighted_point(q: Quad, from: Point, weight: number?, bias: number?): Point
	return Polygon.random_weighted_point(Quad.corners(q), from, weight, bias)
end

return {
	Point = Point,
	Box = Box,
	Circle = Circle,
	Quad = Quad,
	Polygon = Polygon,
	Triangle = Triangle,
}
