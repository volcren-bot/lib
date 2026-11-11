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
Track.HEAT_CELL = 6
Track.HEAT_CAP = 60
Track.WARM = 8
Track.CENTER_SPREAD = 0.45
Track.MOUSE_PULL = 2
Track.debug = false

export type Spot = { u: number, v: number }

export type Shape = { triangles: { Polygon }, anchor: Point? }

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
			local q, _, now_list = read()
			if q == nil or now_list == nil then
				return lost()
			end
			observe(q)
			local mouse_now = Mouse.position()
			if confirm and mouse_now and Track.on_any(now_list, mouse_now) and confirm() then
				Mouse.cancel()
				sleep(Track.POLL_MS)
				if confirm() then
					return true, nil
				end
			end
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

local function cell_key(cx: number, cy: number): number
	return (cx + 32768) * 65536 + (cy + 32768)
end

local function cell_center(key: number, origin: Point): Point
	local size = Track.HEAT_CELL
	local cx, cy = key // 65536 - 32768, key % 65536 - 32768
	return Point.new(origin.x + cx * size + size // 2, origin.y + cy * size + size // 2)
end

local function covered_cells(
	triangles: { Polygon },
	origin: Point,
	visible: ((Point) -> boolean)?
): { [number]: boolean }
	local size = Track.HEAT_CELL
	local cells: { [number]: boolean } = {}
	for _, t in ipairs(triangles) do
		if #t >= 3 and Triangle.area(t) >= 1 then
			local x1 = math.floor((math.min(t[1].x, t[2].x, t[3].x) - origin.x) / size)
			local x2 = math.floor((math.max(t[1].x, t[2].x, t[3].x) - origin.x) / size)
			local y1 = math.floor((math.min(t[1].y, t[2].y, t[3].y) - origin.y) / size)
			local y2 = math.floor((math.max(t[1].y, t[2].y, t[3].y) - origin.y) / size)
			for cx = x1, x2 do
				for cy = y1, y2 do
					local key = cell_key(cx, cy)
					if not cells[key] then
						local p = cell_center(key, origin)
						if Triangle.contains(t, p) and (visible == nil or visible(p)) then
							cells[key] = true
						end
					end
				end
			end
		end
	end
	return cells
end

local function heat_weight(n: number): number
	local h = math.min(n, Track.HEAT_CAP) / Track.HEAT_CAP
	return h * h
end

local function pick_cell(heat: { [number]: number }, origin: Point, mouse: Point?): number?
	local keys: { number } = {}
	local total, x, y = 0, 0, 0
	for key, n in heat do
		local p, w = cell_center(key, origin), heat_weight(n)
		table.insert(keys, key)
		total += w
		x += w * p.x
		y += w * p.y
	end
	if total <= 0 then
		return nil
	end
	x, y = x / total, y / total
	local vx, vy = 0, 0
	for _, key in keys do
		local p, w = cell_center(key, origin), heat_weight(heat[key])
		vx += w * (p.x - x) ^ 2
		vy += w * (p.y - y) ^ 2
	end
	local sx, sy = math.max(math.sqrt(vx / total), 1), math.max(math.sqrt(vy / total), 1)
	local reach = Track.MOUSE_PULL * math.max(sx, sy)
	sx, sy = sx * Track.CENTER_SPREAD, sy * Track.CENTER_SPREAD
	return Random.weighted(keys, function(key: number): number
		local p = cell_center(key, origin)
		local w = heat_weight(heat[key]) * math.exp(-0.5 * (((p.x - x) / sx) ^ 2 + ((p.y - y) / sy) ^ 2))
		if mouse then
			w *= math.exp(-Point.distance(p, mouse) / reach)
		end
		return w
	end)
end

function Track.hover_heat(
	read: () -> Shape?,
	visible: ((Point) -> boolean)?,
	confirm: (() -> boolean)?
): (boolean, string?)
	local size = Track.HEAT_CELL
	local heat: { [number]: number } = {}
	local any_warm = false
	local target: number? = nil
	local dest: Point? = nil
	local moves = 0
	local finished_at = -math.huge
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

	local function update(): Point?
		local shape = read()
		if shape == nil or #shape.triangles == 0 then
			return nil
		end
		local origin = shape.anchor or Point.new(0, 0)
		local next_heat: { [number]: number } = {}
		any_warm = false
		for key in covered_cells(shape.triangles, origin, visible) do
			local n = (heat[key] or 0) + 1
			next_heat[key] = n
			any_warm = any_warm or n >= Track.WARM
		end
		heat = next_heat
		observe(origin)
		return origin
	end

	local function warm_at(origin: Point, p: Point): boolean
		local n = heat[cell_key(math.floor((p.x - origin.x) / size), math.floor((p.y - origin.y) / size))]
		return n ~= nil and (n >= Track.WARM or not any_warm)
	end

	local deadline = time() + Track.TIMEOUT_MS
	while time() < deadline do
		local origin = update()
		if origin == nil or next(heat) == nil then
			Mouse.cancel()
			return false, "gone"
		end
		local mouse = Mouse.position()
		if target == nil or heat[target] == nil then
			target = pick_cell(heat, origin, mouse)
			if target == nil then
				Mouse.cancel()
				return false, "gone"
			end
			if Mouse.busy() then
				Mouse.cancel()
				finished_at = -math.huge
			end
		end
		local goal = cell_center(target :: number, origin)
		if confirm and mouse and warm_at(origin, mouse) and confirm() then
			if not Mouse.busy() then
				return true, nil
			end
			Mouse.cancel()
			sleep(Track.POLL_MS)
			if confirm() then
				return true, nil
			end
		end
		if Mouse.busy() then
			local going = dest
			if going and mouse then
				local left = Mouse.travel_ms(going, mouse)
				if
					Point.distance(ahead(goal, left), going)
					> math.max(Track.JUMP_PX, Point.distance(mouse, going) * Track.JUMP_SHARE)
				then
					if Track.debug then
						Log.log("Track", `the target moved to {goal.x},{goal.y}: aiming again`)
					end
					Mouse.cancel()
				end
			end
			finished_at = if Mouse.busy() then time() else -math.huge
		elseif
			time() - finished_at < Track.SETTLE_MS
			and dest
			and mouse
			and Point.distance(mouse, dest :: Point) > 1
		then
			sleep(Track.POLL_MS)
			continue
		elseif mouse and Point.distance(mouse, goal) <= size then
			if confirm == nil then
				return true, nil
			end
			local until_at = time() + Track.CONFIRM_MS
			repeat
				if confirm() then
					return true, nil
				end
				sleep(Track.POLL_MS)
			until time() >= until_at
			return false, "unconfirmed"
		else
			if moves >= Track.MOVES then
				return false, "missed"
			end
			moves += 1
			dest = ahead(goal, Mouse.travel_ms(goal))
			if Track.debug then
				local d = dest :: Point
				Log.log("Track", `heat move {moves}: target {goal.x},{goal.y}, to {d.x},{d.y}`)
			end
			Mouse.move_async(dest :: Point, true)
			finished_at = time()
		end
		sleep(Track.POLL_MS)
	end
	Mouse.cancel()
	return false, "timeout"
end

return Track
