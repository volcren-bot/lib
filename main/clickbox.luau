--!strict
local Host = require("@lib/host")
type Model = Host.NpcModel
type ScreenPoint = Host.ScreenPoint
type Tile = Host.Tile
local Geometry = require("@lib/utils/math/geometry")
local Point = Geometry.Point
local Polygon = Geometry.Polygon
local Quad = Geometry.Quad
local Triangle = Geometry.Triangle
type Point = Geometry.Point
type Polygon = Geometry.Polygon
type Quad = Geometry.Quad
local Camera = require("@lib/main/camera")
local Draw = require("@lib/utils/draw")
local Interact = require("@lib/main/interact")
local Log = require("@lib/utils/log")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Mouse = require("@lib/utils/input/mouse")
local Player = require("@lib/main/player")
local Projection = require("@lib/main/projection/projection")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Track = require("@lib/utils/input/track")
local Walker = require("@lib/main/walker")
local game_state = Host.game_state

export type Clickbox = {
	polygon: Polygon,
	bounding_box: boolean,
	box: { bottom: Quad, top: Quad }?,
	triangles: { Polygon }?,
	anchor: Point?,
}

export type Aim = (lead_ms: number?) -> Clickbox?

export type Anchor = { x: number, y: number, size: number?, height: number? }

export type Approach = {
	near: number?,
	walk: Walker.WalkOptions?,
	timeout_ms: number?,
	arrive_ms: (number | false)?,
	settle: boolean?,
	closer: number?,
	spam: number?,
}

local Clickbox = {}

Clickbox.TARGET_TRIES = 30

local function points(screen: { ScreenPoint }): { Point }
	local out: { Point } = {}
	for i, p in ipairs(screen) do
		out[i] = Point.new(math.round(p.x), math.round(p.y))
	end
	return out
end

local function triangles_of(model: Model): { Polygon }
	local triangles = table.create(#model.faces) :: { Polygon }
	for i, face in ipairs(model.faces) do
		triangles[i] = points(face)
	end
	return triangles
end

function Clickbox.from_model(model: Model, what: string): Clickbox?
	if model.bounding_box then
		if #model.corners < 8 then
			return nil
		end
		local c = points(model.corners)
		local has_faces = #model.faces > 0 and #model.hull >= 3
		return {
			polygon = if has_faces then points(model.hull) else Polygon.convex_hull(c),
			bounding_box = true,
			box = { bottom = Quad.new(c[3], c[4], c[8], c[7]), top = Quad.new(c[1], c[2], c[6], c[5]) },
			triangles = if has_faces then triangles_of(model) else nil,
		}
	end
	if #model.hull < 3 or #model.faces == 0 then
		return nil
	end
	return { polygon = points(model.hull), bounding_box = false, triangles = triangles_of(model) }
end

function Clickbox.from_cuboid(cuboid: { bottom: Quad, top: Quad }): Clickbox
	local corners: { Point } = {}
	for _, quad in ipairs({ cuboid.bottom, cuboid.top }) do
		for _, p in ipairs(Quad.corners(quad)) do
			table.insert(corners, p)
		end
	end
	return { polygon = Polygon.convex_hull(corners), bounding_box = true, box = cuboid, triangles = nil }
end

Clickbox.MIN_TRIANGLE_AREA = 4
Clickbox.CENTER_SPREAD = 0.45
Clickbox.MOUSE_PULL = 2

type Center = { x: number, y: number, sx: number, sy: number }

local function aimable_area(box: Clickbox, t: Polygon, visible: (Point) -> boolean): number?
	local area = Triangle.area(t)
	if area >= Clickbox.MIN_TRIANGLE_AREA then
		local center = Triangle.centroid(t)
		if Polygon.contains(box.polygon, center) and visible(center) then
			return area
		end
	end
	return nil
end

local function center_of(list: { Polygon }, indices: { number }): Center?
	local total, x, y = 0, 0, 0
	for _, i in ipairs(indices) do
		local area, c = Triangle.area(list[i]), Triangle.centroid(list[i])
		total += area
		x += area * c.x
		y += area * c.y
	end
	if total <= 0 then
		return nil
	end
	x, y = x / total, y / total
	local vx, vy = 0, 0
	for _, i in ipairs(indices) do
		local area, c = Triangle.area(list[i]), Triangle.centroid(list[i])
		vx += area * (c.x - x) ^ 2
		vy += area * (c.y - y) ^ 2
	end
	return { x = x, y = y, sx = math.max(math.sqrt(vx / total), 1), sy = math.max(math.sqrt(vy / total), 1) }
end

local function centered_index(list: { Polygon }, indices: { number }, center: Center, from: Point?): number?
	local sx, sy = center.sx * Clickbox.CENTER_SPREAD, center.sy * Clickbox.CENTER_SPREAD
	local reach = Clickbox.MOUSE_PULL * math.max(center.sx, center.sy)
	return Random.weighted(indices, function(i: number): number
		local c = Triangle.centroid(list[i])
		local weight = Triangle.area(list[i])
			* math.exp(-0.5 * (((c.x - center.x) / sx) ^ 2 + ((c.y - center.y) / sy) ^ 2))
		if from then
			weight *= math.exp(-Point.distance(c, from) / reach)
		end
		return weight
	end)
end

local function pick_triangle(box: Clickbox, from: Point?, visible: (Point) -> boolean): Polygon?
	local list = box.triangles or {}
	local aimable: { number } = {}
	for i, t in ipairs(list) do
		if aimable_area(box, t, visible) then
			table.insert(aimable, i)
		end
	end
	local center = center_of(list, aimable)
	if center == nil then
		return nil
	end
	local index = centered_index(list, aimable, center, from)
	return if index then list[index] else nil
end

local function stable_triangles(box: Clickbox): { Polygon }?
	if box.triangles then
		return box.triangles
	end
	local cuboid = box.box
	if cuboid == nil then
		return nil
	end
	local out: { Polygon } = {}
	for _, quad in ipairs({ cuboid.top, cuboid.bottom }) do
		local c = Quad.corners(quad)
		table.insert(out, { c[1], c[2], c[3] })
		table.insert(out, { c[1], c[3], c[4] })
	end
	return out
end

Clickbox.FOLLOW_AREA = 25

local function pick_index(box: Clickbox, list: { Polygon }, from: Point?, visible: (Point) -> boolean): number?
	local candidates: { number }, small: { number }, aimable: { number } = {}, {}, {}
	for i, t in ipairs(list) do
		local area = aimable_area(box, t, visible)
		if area then
			table.insert(aimable, i)
			table.insert(if area >= Clickbox.FOLLOW_AREA then candidates else small, i)
		end
	end
	if #candidates == 0 then
		candidates = small
	end
	table.sort(candidates, function(a: number, b: number): boolean
		return Triangle.area(list[a]) > Triangle.area(list[b])
	end)
	for i = #candidates, math.max(1, math.ceil(#candidates / 2)) + 1, -1 do
		candidates[i] = nil
	end
	local center = center_of(list, aimable)
	if #candidates == 0 or center == nil then
		return nil
	end
	return centered_index(list, candidates, center, from)
end

local function visibility(keep: ((Point) -> boolean)?, ignore_windows: boolean?): ((Point) -> boolean)?
	local view = Toplevel.viewport()
	if view == nil then
		return nil
	end
	local blockers = (if ignore_windows then Toplevel.panel_blockers() else Toplevel.blockers()) or {}
	return function(p: Point): boolean
		local at = Point.new(math.round(p.x), math.round(p.y))
		return Toplevel.is_visible(at, view, blockers) and (keep == nil or keep(at))
	end
end

function Clickbox.target(
	box: Clickbox,
	what: string,
	keep: ((Point) -> boolean)?,
	ignore_windows: boolean?
): (Point?, Polygon?)
	local visible = visibility(keep, ignore_windows)
	if visible == nil then
		return nil, nil
	end
	local from = Mouse.position()
	for _ = 1, Clickbox.TARGET_TRIES do
		local p: Point?
		local t: Polygon? = nil
		if box.triangles then
			t = pick_triangle(box, from, visible)
			if t == nil then
				break
			end
			p = Triangle.random_point_near_center(t)
		else
			p = Polygon.random_weighted_point(box.polygon, from or Quad.mean((box.box :: any).top))
		end
		if p and Polygon.contains(box.polygon, p) and visible(p) then
			return p, t
		end
	end
	return nil, nil
end

Clickbox.ANCHOR_HEIGHT = 200

local function shifted(box: Clickbox, anchor: Anchor, shift: Host.FinePoint): Clickbox?
	local ref: { Host.FinePoint } = {
		{ x = anchor.x, y = anchor.y, z = 0 },
		{ x = anchor.x, y = anchor.y, z = -(anchor.height or Clickbox.ANCHOR_HEIGHT) },
	}
	local now, later = Projection.points(ref), Projection.shifted(ref, shift)
	if now == nil or later == nil or #now < 2 or #later < 2 then
		return nil
	end
	local span = Point.distance(now[1], now[2])
	local scale = if span >= 1 then Point.distance(later[1], later[2]) / span else 1
	local function move(p: Point): Point
		return Point.new(
			math.round(later[1].x + (p.x - now[1].x) * scale),
			math.round(later[1].y + (p.y - now[1].y) * scale)
		)
	end
	local function move_all(polygon: Polygon): Polygon
		local out: Polygon = {}
		for i, p in ipairs(polygon) do
			out[i] = move(p)
		end
		return out
	end
	local cuboid = box.box
	local triangles: { Polygon }? = nil
	if box.triangles then
		triangles = {}
		for i, t in ipairs(box.triangles) do
			(triangles :: { Polygon })[i] = move_all(t)
		end
	end
	return {
		polygon = move_all(box.polygon),
		bounding_box = box.bounding_box,
		box = if cuboid
			then {
				bottom = Quad.new(
					move(cuboid.bottom.top),
					move(cuboid.bottom.right),
					move(cuboid.bottom.bottom),
					move(cuboid.bottom.left)
				),
				top = Quad.new(
					move(cuboid.top.top),
					move(cuboid.top.right),
					move(cuboid.top.bottom),
					move(cuboid.top.left)
				),
			}
			else nil,
		triangles = triangles,
	}
end

local function anchor_point(at: Anchor, shift: Host.FinePoint?): Point?
	local ref: { Host.FinePoint } = { { x = at.x, y = at.y, z = 0 } }
	local projected = if shift then Projection.shifted(ref, shift) else Projection.points(ref)
	local p = projected and projected[1]
	return if p then Point.new(math.round(p.x), math.round(p.y)) else nil
end

function Clickbox.walking(model: () -> Clickbox?, anchor: () -> Anchor?, what: string): Aim
	return function(lead_ms: number?)
		local box = model()
		local at = anchor()
		local shift = if lead_ms and lead_ms > 0 then Walker.ahead(lead_ms) else nil
		if shift == nil or (shift.x == 0 and shift.y == 0) or at == nil then
			if box and at then
				box.anchor = anchor_point(at)
			end
			return box
		end
		if box then
			local moved = shifted(box, at, shift) or box
			moved.anchor = anchor_point(at, shift)
			return moved
		end
		local cuboid = Projection.cuboid(at.x, at.y, at.size, at.height, nil, shift)
		if cuboid == nil then
			return nil
		end
		return Clickbox.from_cuboid(cuboid)
	end
end

Clickbox.WALK_REACTION_MS = 30
Clickbox.WALK_HOLD_MS = 150
Clickbox.WALK_LEAD_MS = 300
Clickbox.WALK_LEAD_TOLERANCE = 40

local function lead_ms(to: Point): number
	return Mouse.travel_ms(to) + Clickbox.WALK_REACTION_MS
end

local function target_ahead(clickbox: Aim, what: string, lead: number): Point?
	local ahead = clickbox(lead)
	if ahead == nil then
		return nil
	end
	local later = clickbox(lead + Clickbox.WALK_HOLD_MS)
	if later then
		local held = Clickbox.target(ahead, what, function(p: Point): boolean
			return Polygon.contains(later.polygon, p)
		end)
		if held then
			return held
		end
	end
	return (Clickbox.target(ahead, what))
end

local function close_window_over(box: Clickbox, what: string): boolean
	if not Toplevel.has_interface() or Clickbox.target(box, what, nil, true) == nil then
		return false
	end
	Log.log("Clickbox", `closing the {Toplevel.interface_name() or "window"} that covers {what}`)
	return Toplevel.escape_clear()
end

local function aim(clickbox: Aim, what: string): Point?
	local box = clickbox()
	local target = nil
	if box then
		target = Clickbox.target(box, what)
		if target == nil and close_window_over(box, what) then
			box = clickbox()
			target = if box then Clickbox.target(box, what) else nil
		end
	end
	if not Player.in_transit() then
		return target
	end
	local lead = if target then lead_ms(target) else Clickbox.WALK_LEAD_MS
	for _ = 1, 2 do
		local p = target_ahead(clickbox, what, lead)
		if p == nil then
			break
		end
		target = p
		local next_lead = lead_ms(p)
		if math.abs(next_lead - lead) < Clickbox.WALK_LEAD_TOLERANCE then
			break
		end
		lead = next_lead
	end
	return target
end

Clickbox.CAMERA_RANGE = 15 :: number?

local function on_screen(clickbox: Aim, what: string): boolean
	local box = clickbox()
	return box ~= nil and Clickbox.target(box, what) ~= nil
end

function Clickbox.reveal(clickbox: Aim, tile: () -> Tile?, what: string): boolean
	if on_screen(clickbox, what) then
		return true
	end
	local range = Clickbox.CAMERA_RANGE
	if range == nil then
		return false
	end
	local state = game_state()
	local me, at = state.position, tile()
	if me == nil or at == nil then
		return false
	end
	local away = math.max(math.abs(at.x - me.x), math.abs(at.y - me.y))
	if away > range then
		return false
	end

	Camera.face(at, true)
	if on_screen(clickbox, what) then
		return true
	end
	local zoom = Camera.zoom()
	if zoom then
		local farthest = Camera.ZOOM_MIN + Random.int(0, 40)
		for _, to in ipairs({ math.round((zoom + farthest) / 2), farthest }) do
			if to < zoom - Camera.zoom_tolerance then
				Camera.set_zoom(to)
				zoom = Camera.zoom() or to
				if on_screen(clickbox, what) then
					return true
				end
			end
		end
	end
	return false
end

Clickbox.ATTEMPTS = 5

local function clear_menu(clickbox: Aim)
	if not Minimenu.is_open() then
		return
	end
	local box = clickbox()
	if box == nil or #box.polygon == 0 then
		return
	end
	local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
	for _, p in ipairs(box.polygon) do
		x1, y1, x2, y2 = math.min(x1, p.x), math.min(y1, p.y), math.max(x2, p.x), math.max(y2, p.y)
	end
	if Minimenu.overlaps(Geometry.Box.new(x1, y1, x2, y2)) and not Minimenu.close() then
		Log.log("Clickbox", "couldn't close the minimenu covering the target")
	end
end

function Clickbox.hover(clickbox: Aim, hovered: () -> boolean, what: string, tile: (() -> Tile?)?): boolean
	if tile then
		local at = tile()
		if at then
			Camera.face(at)
		end
		Clickbox.reveal(clickbox, tile, what)
	end
	clear_menu(clickbox)
	for _ = 1, Clickbox.ATTEMPTS do
		local box = clickbox()
		if box and Clickbox.target(box, what) == nil and close_window_over(box, what) then
			box = clickbox()
		end
		local visible = visibility()
		if box and box.triangles and visible then
			local ok, why = Track.hover_heat(function(): Track.Shape?
				local now = clickbox()
				return if now and now.triangles then { triangles = now.triangles, anchor = now.anchor } else nil
			end, visible, hovered)
			if ok then
				return true
			end
			Log.log("Clickbox", `couldn't keep the mouse on {what} ({why})`)
			continue
		end
		local list = if box then stable_triangles(box) else nil
		local index = if box and list and visible then pick_index(box, list, Mouse.position(), visible) else nil
		if index == nil then
			return false
		end
		local ok, why = Track.hover(function(): { Polygon }?
			local now = clickbox()
			return if now then stable_triangles(now) else nil
		end, index, visible, true, hovered)
		if ok then
			return true
		end
		Log.log("Clickbox", `couldn't keep the mouse on {what} ({why})`)
	end
	return false
end

function Clickbox.hover_async(clickbox: Aim, what: string): boolean
	clear_menu(clickbox)
	local target = aim(clickbox, what)
	if target == nil then
		return false
	end
	Mouse.move_async(target)
	return true
end

function Clickbox.click(
	clickbox: Aim,
	hovered: () -> boolean,
	what: string,
	button: Mouse.Button?,
	tile: (() -> Tile?)?,
	spam: number?
): boolean
	local ok = Clickbox.hover(clickbox, hovered, what, tile)
	if not ok then
		return false
	end
	Mouse.click(nil, button)
	Interact.spam_click(spam, hovered, button)
	return true
end

Clickbox.MISCLICK_ATTEMPTS = 3

local function option_list(option: string | { string }): { string }
	return if type(option) == "string" then { option } else option :: { string }
end

local function offered(options: { string }, target: Minimenu.Target?): string?
	for _, option in ipairs(options) do
		if Minimenu.find(option, target) ~= nil then
			return option
		end
	end
	return nil
end

function Clickbox.interact(
	clickbox: Aim,
	hovered: () -> boolean,
	what: string,
	option: string | { string },
	target: Minimenu.Target?,
	tile: (() -> Tile?)?,
	walk_timeout_ms: (number | false)?,
	spam: number?,
	menu: boolean?
): boolean
	local options = option_list(option)
	local handled, result = Interact.open_menu(options, target, walk_timeout_ms)
	if handled then
		return result == true
	end
	for _ = 1, Clickbox.MISCLICK_ATTEMPTS do
		local ok = Clickbox.hover(clickbox, hovered, what, tile)
		if not ok then
			return false
		end
		local at = Mouse.position()
		if at == nil then
			return false
		end
		local pick = offered(options, target) or options[1]
		local walking = Player.destination() ~= nil
		local done, misclicked = Interact.with(at, pick, target, walk_timeout_ms, spam, true, menu)
		if done or (misclicked == nil and not walking) then
			return done
		end
	end
	return false
end

Clickbox.APPROACH_NEAR = 3
Clickbox.EARLY_RETRY_MS = 1500
Clickbox.APPROACH_TIMEOUT_MS = 30000

local function aimable(clickbox: Aim, what: string): boolean
	return aim(clickbox, what) ~= nil
end

function Clickbox.approach(
	clickbox: Aim,
	hovered: () -> boolean,
	what: string,
	option: string | { string },
	target: Minimenu.Target?,
	tile: () -> Tile?,
	opts: Approach?
): boolean
	local o: Approach = opts or {}
	local options = option_list(option)
	local near = o.near or Clickbox.APPROACH_NEAR
	local walk: Walker.WalkOptions = o.walk or {}
	local at = tile()
	if at == nil then
		return false
	end
	local me = Walker.position()
	if me == nil then
		return false
	end

	Camera.face(at)
	local picked_early = false
	if not aimable(clickbox, what) and Walker.distance(me, at) > near then
		local last_try: number? = nil
		local goal = { x = math.floor(at.x), y = math.floor(at.y) }
		local ok = Walker.walk(goal, {
			near = near,
			timeout_ms = o.timeout_ms or Clickbox.APPROACH_TIMEOUT_MS,
			straight = walk.straight,
			before_click = walk.before_click,
			accept = walk.accept or function(entry: Host.MenuEntry): boolean
				for _, option in ipairs(options) do
					if Minimenu.matches(entry, option, target) then
						return true
					end
				end
				return false
			end,
			on_step = function(here: Tile): boolean
				if walk.on_step and walk.on_step(here) == false then
					return false
				end
				if
					not o.settle
					and (last_try == nil or Host.time() - last_try >= Clickbox.EARLY_RETRY_MS)
					and aimable(clickbox, what)
				then
					last_try = Host.time()
					if Clickbox.interact(clickbox, hovered, what, option, target, tile, false, o.spam) == true then
						picked_early = true
						return false
					end
				end
				return true
			end,
		})
		if not picked_early and not ok then
			return false
		end
	end

	if picked_early then
		if o.arrive_ms == false then
			return true
		end
		return Player.wait_walk(if o.arrive_ms then o.arrive_ms else nil)
	end
	if o.settle then
		Player.wait_walk(o.timeout_ms or Clickbox.APPROACH_TIMEOUT_MS)
	end
	if Clickbox.interact(clickbox, hovered, what, option, target, tile, o.arrive_ms, o.spam) then
		return true
	end
	local closer = o.closer
	local again = if closer then tile() else nil
	if closer == nil or again == nil then
		return false
	end
	Camera.face(again)
	local reached = Walker.walk({ x = math.floor(again.x), y = math.floor(again.y) }, {
		near = closer,
		timeout_ms = o.timeout_ms or Clickbox.APPROACH_TIMEOUT_MS,
		straight = walk.straight,
	})
	if not reached then
		return false
	end
	Player.wait_still(3000)
	return Clickbox.interact(clickbox, hovered, what, option, target, tile, o.arrive_ms, o.spam)
end

function Clickbox.draw(box: Clickbox, color: Draw.Color?)
	if box.box then
		Draw.cuboid(box.box, Draw.BLUE)
	end
	Draw.polygon(box.polygon, color or (if box.triangles then Draw.YELLOW else Draw.CYAN))
end

return Clickbox
