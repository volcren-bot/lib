--!strict
local Host = require("@lib/host")
local sleep = Host.sleep
local time = Host.time
local Geometry = require("@lib/utils/math/geometry")
local Point = Geometry.Point
local Triangle = Geometry.Triangle
type Point = Geometry.Point
type Polygon = Geometry.Polygon
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Random = require("@lib/utils/math/random")
local Widgets = require("@lib/main/interfaces/widgets")

local Track = {}

Track.TIMEOUT_MS = 2500
Track.MOVES = 5
Track.JUMP_PX = 60
Track.JUMP_SHARE = 0.5
Track.STILL_PX_S = 40
Track.NEAR_PX = 20
Track.POLL_MS = 15
Track.MIN_AREA = 4
Track.SETTLE_MS = 60
Track.CONFIRM_MS = 80
Track.SPEED_WINDOW_MS = 120
Track.MAX_LEAD_PX = 60
Track.debug = false

export type Spot = { u: number, v: number }

function Track.spot(): Spot
	for _ = 1, Triangle.CENTER_TRIES do
		local u, v = Random.gauss(1 / 3, Triangle.CENTER_SPREAD), Random.gauss(1 / 3, Triangle.CENTER_SPREAD)
		if u >= 0 and v >= 0 and u + v <= 1 then
			return { u = u, v = v }
		end
	end
	return { u = 1 / 3, v = 1 / 3 }
end

function Track.point(tri: Polygon, spot: Spot): Point
	local a, b, c = tri[1], tri[2], tri[3]
	local w = 1 - spot.u - spot.v
	return Point.new(
		math.round(spot.u * a.x + spot.v * b.x + w * c.x),
		math.round(spot.u * a.y + spot.v * b.y + w * c.y)
	)
end

function Track.inside(tri: Polygon, spot: Point, mouse: Point): boolean
	return Point.distance(mouse, spot) <= 1 or Triangle.contains(tri, mouse)
end

function Track.on_any(list: { Polygon }, mouse: Point): boolean
	for _, tri in ipairs(list) do
		if Triangle.contains(tri, mouse) then
			return true
		end
	end
	return false
end

function Track.hover(
	triangles: () -> { Polygon }?,
	index: number,
	visible: ((Point) -> boolean)?,
	anywhere: boolean?,
	confirm: (() -> boolean)?,
	spot: Spot?
): (boolean, string?)
	local at = spot or Track.spot()
	local count: number? = nil
	local changed = false
	local function read(): (Point?, Polygon?, { Polygon }?)
		local list = triangles()
		if list and count and #list ~= count then
			changed = true
			return nil, nil, nil
		end
		count = count or (list and #list)
		local tri = list and list[index]
		if list == nil or tri == nil or #tri < 3 or Triangle.area(tri) < Track.MIN_AREA then
			return nil, nil, nil
		end
		local p = Track.point(tri, at)
		if visible and not visible(p) then
			return nil, nil, nil
		end
		return p, tri, list
	end

	local function lost(): (boolean, string)
		Mouse.cancel()
		return false, if changed then "changed" else "gone"
	end

	local vx, vy = 0, 0
	local reads: { { p: Point, at: number } } = {}
	local function observe(p: Point)
		local now = time()
		table.insert(reads, { p = p, at = now })
		while #reads > 2 and now - reads[2].at >= Track.SPEED_WINDOW_MS do
			table.remove(reads, 1)
		end
		local first = reads[1]
		local dt = now - first.at
		if dt >= Track.SPEED_WINDOW_MS / 2 then
			vx, vy = (p.x - first.p.x) / dt, (p.y - first.p.y) / dt
		end
	end
	local function ahead(p: Point, ms: number): Point
		local dx, dy = vx * ms, vy * ms
		local len = math.sqrt(dx * dx + dy * dy)
		if len > Track.MAX_LEAD_PX then
			dx, dy = dx / len * Track.MAX_LEAD_PX, dy / len * Track.MAX_LEAD_PX
		end
		return Point.new(math.round(p.x + dx), math.round(p.y + dy))
	end

	local deadline = time() + Track.TIMEOUT_MS
	local moves = 0
	while time() < deadline do
		local p, tri, list = read()
		if p == nil or tri == nil or list == nil then
			return lost()
		end
		observe(p)
		local mouse = Mouse.position()
		local still = math.sqrt(vx * vx + vy * vy) * 1000 <= Track.STILL_PX_S
		local close = mouse ~= nil and (still or Point.distance(mouse, p) <= Track.NEAR_PX)
		if
			mouse and (Track.inside(tri, p, mouse) or (anywhere and close and moves > 0 and Track.on_any(list, mouse)))
		then
			if confirm == nil then
				return true
			end
			local until_at = time() + Track.CONFIRM_MS
			repeat
				if confirm() then
					return true
				end
				sleep(Track.POLL_MS)
			until time() >= until_at
			if Track.inside(tri, p, mouse) then
				if Track.debug then
					Log.log("Track", "on the spot but not confirmed: another triangle")
				end
				return false, "unconfirmed"
			end
			if Track.debug then
				Log.log("Track", "on the target but not confirmed: going on to the spot")
			end
			anywhere = false
		end
		if moves >= Track.MOVES then
			return false, "missed"
		end
		moves += 1
		local dest = ahead(p, Mouse.travel_ms(p))
		if Track.debug then
			Log.log(
				"Track",
				`move {moves}: spot {p.x},{p.y} speed {math.round(vx * 1000)},{math.round(vy * 1000)} px/s, to {dest.x},{dest.y}, mouse {mouse and `{mouse.x},{mouse.y}` or "?"}`
			)
		end
		Mouse.move_async(dest, true)
		while Mouse.busy() and time() < deadline do
			sleep(Track.POLL_MS)
			local q = read()
			if q == nil then
				return lost()
			end
			observe(q)
			local mouse_now = Mouse.position()
			local left = if mouse_now then Mouse.travel_ms(dest, mouse_now) else 0
			local to_go = if mouse_now then Point.distance(mouse_now, dest) else 0
			if Point.distance(ahead(q, left), dest) > math.max(Track.JUMP_PX, to_go * Track.JUMP_SHARE) then
				if Track.debug then
					Log.log("Track", `the spot jumped to {q.x},{q.y}: aiming again`)
				end
				Mouse.cancel()
				break
			end
		end
		Widgets.wait_within(function(): boolean
			local now_at = Mouse.position()
			return now_at ~= nil and Point.distance(now_at, dest) <= 1
		end, Track.SETTLE_MS, Track.POLL_MS)
	end
	Mouse.cancel()
	return false, "timeout"
end

return Track
