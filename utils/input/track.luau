--!strict
-- Moving the mouse onto something that moves on screen (a swaying NPC, the scene sliding while the player walks): one triangle of
-- it is followed while the mouse goes there, and the move ends with short corrections until the mouse is inside it.
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

local Track = {}

-- How long a hover may take, how many moves it makes at most (the first and the corrections), how far (px) the spot may get
-- from where the move is going before the move is cancelled and aimed again, how often the spot is read during a move, the
-- smallest triangle (px²) that is followed, and how long a finished move gets for the client to report the mouse where it went.
Track.TIMEOUT_MS = 2500
Track.MOVES = 5
Track.JUMP_PX = 60
-- a jump also has to be this share of the distance the mouse still has to go: a far move's aim drifts and its end corrects it
Track.JUMP_SHARE = 0.5
-- `anywhere` counts anywhere on the target while the spot is about still (px per second), and on a moving one only this near
-- the spot (px): its edges leave the mouse first
Track.STILL_PX_S = 40
Track.NEAR_PX = 20
Track.POLL_MS = 15
Track.MIN_AREA = 4
Track.SETTLE_MS = 60
-- with `confirm`, how long the mouse stays put for it once a move ends on the target
Track.CONFIRM_MS = 80
-- the spot's speed is measured over the reads of this window (frames come every 20 ms, so close reads are noisy), the lead it
-- gives is capped (px), and `debug` logs every move
Track.SPEED_WINDOW_MS = 120
Track.MAX_LEAD_PX = 60
Track.debug = false

-- Where in a triangle the mouse goes: barycentric weights, the same spot of it in every frame.
export type Spot = { u: number, v: number }

-- A spot near the triangle's centre.
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

-- Whether the mouse is on the triangle: inside it, or within a pixel of the spot (rounding can put a small one's spot outside).
function Track.inside(tri: Polygon, spot: Point, mouse: Point): boolean
	return Point.distance(mouse, spot) <= 1 or Triangle.contains(tri, mouse)
end

-- Whether the mouse is on any of the triangles.
function Track.on_any(list: { Polygon }, mouse: Point): boolean
	for _, tri in ipairs(list) do
		if Triangle.contains(tri, mouse) then
			return true
		end
	end
	return false
end

-- Moves the mouse into triangle `index` of what `triangles` reads (the target's triangles on screen now, always in the same
-- order; nil when it can't be read), aiming at a spot that stays the same part of the triangle as it moves. `visible` can turn
-- down a spot (covered by the interface). The mouse is on the target on that triangle, or with `anywhere` on any of them;
-- `confirm` (the game showing it under the mouse) is then asked while the mouse stays put, and when it doesn't agree the
-- moves go on, to the spot itself. True once it is there (and confirmed); false with why: "changed" when the count of
-- triangles changed (another model), "gone" when the triangle can't be read, is too small or isn't visible, "unconfirmed" when the mouse is on the spot and the game still doesn't agree, "missed"
-- after `Track.MOVES` moves, "timeout".
function Track.hover(
	triangles: () -> { Polygon }?,
	index: number,
	visible: ((Point) -> boolean)?,
	anywhere: boolean?,
	confirm: (() -> boolean)?,
	spot: Spot?
): (boolean, string?)
	local at = spot or Track.spot()
	-- a model swapped for another (an NPC changing form or pose set) has a different count, and its index another face
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

	-- the spot's speed on screen, px per ms, over the reads of the last SPEED_WINDOW_MS
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
			Mouse.cancel()
			return false, if changed then "changed" else "gone"
		end
		observe(p)
		local mouse = Mouse.position()
		-- anywhere on it counts once the mouse has moved for it (not where it happened to be) and while it is about still
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
			-- on the spot itself and still not confirmed: the game doesn't pick this triangle (a hidden face)
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
		-- follow the spot while the mouse goes: a jump (a dive, a walk starting) is aimed again
		while Mouse.busy() and time() < deadline do
			sleep(Track.POLL_MS)
			local q = read()
			if q == nil then
				Mouse.cancel()
				return false, if changed then "changed" else "gone"
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
		-- the client reports the mouse where the move left it a frame later
		local settle = time() + Track.SETTLE_MS
		while time() < settle do
			local now_at = Mouse.position()
			if now_at and Point.distance(now_at, dest) <= 1 then
				break
			end
			sleep(Track.POLL_MS)
		end
	end
	Mouse.cancel()
	return false, "timeout"
end

return Track
