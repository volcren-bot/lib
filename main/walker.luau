--!strict
local Host = require("@lib/host")
local game_state = Host.game_state
local find_path = Host.find_path
local scene_route = Host.scene_route
local nav_plan = Host.nav_plan
local server_tile = Host.server_tile
local movement = Host.movement
local locs = Host.locs
local sleep = Host.sleep
local time = Host.time
local Biometrics = require("@lib/main/antiban/biometrics")
local Camera = require("@lib/main/camera")
local Geometry = require("@lib/utils/math/geometry")
local Log = require("@lib/utils/log")
local Minimap = require("@lib/main/interfaces/minimap")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Mouse = require("@lib/utils/input/mouse")
local Player = require("@lib/main/player")
local Projection = require("@lib/main/projection/projection")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Track = require("@lib/utils/input/track")
type Tile = Projection.Tile
type NavTile = Host.NavTile
type NavPlan = Host.NavPlan
type NavAction = Host.NavAction
type NavLoc = Host.NavLoc

local Walker = {}

local function lazy(path: string): any
	return (require :: any)(path)
end

Walker.DEBUG = false

local function debug(text: string)
	if Walker.DEBUG then
		Log.log("Walker", text)
	end
end

function Walker.position(): Tile?
	local state = game_state()
	local p = state.position
	if p == nil then
		return nil
	end
	return { x = p.x, y = p.y }
end

function Walker.relative(dx: number, dy: number): Tile?
	local me = Walker.position()
	if me == nil then
		return nil
	end
	return { x = me.x + dx, y = me.y + dy }
end

function Walker.path(to: Tile, from: Tile?): { Tile }?
	local start = from or Walker.position()
	if start == nil then
		return nil
	end
	return find_path(start, to)
end

function Walker.route(to: Tile, from: Tile?): Host.SceneRoute?
	local start = from or Walker.position()
	if start == nil then
		return nil
	end
	return scene_route(start, to)
end

local clicked_tile: Tile? = nil

function Walker.last_click(): Tile?
	local flag = Player.destination()
	if flag == nil then
		clicked_tile = nil
		return nil
	end
	local clicked = clicked_tile
	if clicked == nil or Walker.distance(clicked, flag :: Tile) > 2 then
		return flag
	end
	return clicked
end

Walker.WALK_MS_PER_TILE = 600
Walker.RUN_MS_PER_TILE = 300

local function ms_per_tile(): number
	return if Player.is_running() then Walker.RUN_MS_PER_TILE else Walker.WALK_MS_PER_TILE
end

local function tile_centre(t: Tile, base_x: number, base_y: number): (number, number)
	return (t.x - base_x) * Projection.TILE + Projection.TILE / 2,
		(t.y - base_y) * Projection.TILE + Projection.TILE / 2
end

function Walker.ahead(ms: number): Host.FinePoint?
	local state = game_state()
	local p = state.position
	if p == nil then
		return nil
	end
	local flag: Tile? = state.destination
	if flag == nil then
		local server = Host.server_tile()
		flag = if server and server.steps > 0 then { x = server.x, y = server.y } else nil
	end
	if flag == nil or ms <= 0 then
		return { x = 0, y = 0 }
	end
	local route = scene_route({ x = p.x, y = p.y }, flag)
	local tiles = if route and #route.tiles > 0 then route.tiles else { flag }
	local base_x = p.x - p.local_x // Projection.TILE
	local base_y = p.y - p.local_y // Projection.TILE
	local x, y = p.local_x, p.local_y
	local first = 1
	if #tiles >= 2 then
		local ax, ay = tile_centre(tiles[1], base_x, base_y)
		local bx, by = tile_centre(tiles[2], base_x, base_y)
		if (ax - x) * (bx - ax) + (ay - y) * (by - ay) < 0 then
			first = 2
		end
	end
	local budget = ms * Projection.TILE / ms_per_tile()
	for i = first, #tiles do
		local tx, ty = tile_centre(tiles[i], base_x, base_y)
		local step = math.max(math.abs(tx - x), math.abs(ty - y))
		if step >= budget then
			local f = budget / step
			x, y = x + (tx - x) * f, y + (ty - y) * f
			break
		end
		x, y = tx, ty
		budget -= step
	end
	return { x = x - p.local_x, y = y - p.local_y }
end

local function quad_on_screen(quad: Geometry.Quad, view: Geometry.Box?, blockers: { Geometry.Box }?): boolean
	local visible = Toplevel.is_visible(Geometry.Quad.mean(quad), view, blockers)
	for _, c in ipairs(Geometry.Quad.corners(quad)) do
		visible = visible and Toplevel.is_visible(c, view, blockers)
	end
	return visible
end

Walker.SCREEN_PADDING = 0.10

local function walk_view(): Geometry.Box?
	local view = Toplevel.viewport()
	if view == nil then
		return nil
	end
	local px = math.round((view.x2 - view.x1) * Walker.SCREEN_PADDING)
	local py = math.round((view.y2 - view.y1) * Walker.SCREEN_PADDING)
	return Geometry.Box.new(view.x1 + px, view.y1 + py, view.x2 - px, view.y2 - py)
end

local function quad_walkable(quad): boolean
	return quad_on_screen(quad, walk_view(), Toplevel.blockers())
end

function Walker.on_screen(tile: Tile): boolean
	local quad = Projection.tile(tile)
	return quad ~= nil and quad_walkable(quad)
end

Walker.HOVER_ATTEMPTS = 2
Walker.SCREEN_FALLBACKS = 2
Walker.WALK_HERE_MAX_ROW = 14

local function is_walk_here(entry: Host.MenuEntry): boolean
	return string.find(string.lower(entry.option), "^walk here") ~= nil
end

local function select_walk_here(): boolean
	local at = Mouse.position()
	if at == nil then
		return false
	end
	Mouse.click(at, "right")
	Random.sleep(80, 200)
	local entries = Minimenu.entries()
	local index: number? = nil
	if entries then
		for i, entry in ipairs(entries) do
			if is_walk_here(entry) then
				index = i
				break
			end
		end
	end
	local row = if index and index <= Walker.WALK_HERE_MAX_ROW then Minimenu.row(index) else nil
	if row == nil then
		Minimenu.close()
		return false
	end
	Mouse.click(row)
	return true
end

Walker.CLICK_LEAD_MS = 80

local function quad_ahead(tile: Tile, lead_ms: number): Geometry.Quad?
	local shift = Walker.ahead(lead_ms)
	local base = Projection.base()
	if shift == nil or base == nil or (shift.x == 0 and shift.y == 0) then
		return Projection.tile(tile)
	end
	local x, y = (tile.x - base.x) * Projection.TILE, (tile.y - base.y) * Projection.TILE
	local corners = Projection.shifted({
		{ x = x, y = y, z = 0 },
		{ x = x, y = y + Projection.TILE, z = 0 },
		{ x = x + Projection.TILE, y = y + Projection.TILE, z = 0 },
		{ x = x + Projection.TILE, y = y, z = 0 },
	}, shift)
	if corners == nil or #corners < 4 then
		return nil
	end
	return Geometry.Quad.new(corners[1], corners[2], corners[3], corners[4])
end

local function aim_quad(tile: Tile): Geometry.Quad?
	local quad = Projection.tile(tile)
	if quad == nil or not Player.in_transit() then
		return quad
	end
	local lead = Mouse.travel_ms(Geometry.Quad.mean(quad)) + Walker.CLICK_LEAD_MS
	return quad_ahead(tile, lead) or quad
end

local function click_projected(
	tile: Tile,
	accept: ((Host.MenuEntry) -> boolean)?,
	menu: boolean?,
	half: number?
): (boolean, number)
	local used = half or math.random(1, 2)
	local quad = Projection.tile(tile)
	if quad == nil then
		Log.log("Walker", `tile {tile.x},{tile.y} can't be projected`)
		return false, used
	end
	if not quad_walkable(quad) then
		Log.log("Walker", `tile {tile.x},{tile.y} is off the game view or behind the interface`)
		return false, used
	end
	local walkable = false
	local view, blockers = walk_view(), Toplevel.blockers()
	local function visible(p: Geometry.Point): boolean
		return Toplevel.is_visible(Geometry.Point.new(math.round(p.x), math.round(p.y)), view, blockers)
	end
	for _ = 1, Walker.HOVER_ATTEMPTS do
		local followed, why = Track.hover(function(): { Geometry.Polygon }?
			local now = Projection.tile(tile)
			if now == nil then
				return nil
			end
			local c = Geometry.Quad.corners(now)
			return { { c[1], c[2], c[3] }, { c[1], c[3], c[4] } }
		end, used, visible)
		if not followed then
			Log.log("Walker", `couldn't keep the mouse on tile {tile.x},{tile.y} ({why})`)
			return false, used
		end
		for _ = 1, 4 do
			local top = Minimenu.entries()
			if top and top[1] and (is_walk_here(top[1]) or (accept and accept(top[1]))) then
				walkable = true
				break
			end
			sleep(25)
		end
		if walkable then
			break
		end
	end
	local before = Minimenu.clicked()
	if walkable then
		Mouse.click(nil)
	elseif menu == false or not select_walk_here() then
		return false, used
	end
	if before ~= nil then
		local clicked = Minimenu.wait_click(before)
		if clicked == nil then
			return false, used
		end
	end
	clicked_tile = tile
	return true, used
end

Walker.CLICK_CHECK_MS = 700

local function walk_destination(tile: Tile): Tile?
	local deadline = Host.time() + Walker.CLICK_CHECK_MS
	while Host.time() < deadline do
		local dest = Player.destination()
		if dest then
			return dest
		end
		local me = Walker.position()
		if me and me.x == tile.x and me.y == tile.y then
			return nil
		end
		sleep(30)
	end
	return nil
end

local function reveal_tile(tile: Tile)
	local zoom = Camera.zoom()
	if zoom == nil or Walker.on_screen(tile) then
		return
	end
	local farthest = Camera.ZOOM_MIN + Random.int(0, 40)
	for _, to in ipairs({ math.round((zoom + farthest) / 2), farthest }) do
		if to < zoom - Camera.zoom_tolerance then
			Camera.set_zoom(to)
			zoom = Camera.zoom() or to
			if Walker.on_screen(tile) then
				return
			end
		end
	end
end

function Walker.click_tile(tile: Tile): boolean
	Camera.face(tile)
	reveal_tile(tile)
	local ok, half = click_projected(tile)
	if not ok then
		return false
	end
	local dest = walk_destination(tile)
	if dest and (dest.x ~= tile.x or dest.y ~= tile.y) then
		Log.log("Walker", `the click walks to {dest.x},{dest.y}, not {tile.x},{tile.y}: clicking the tile's other half`)
		if click_projected(tile, nil, nil, 3 - half) then
			dest = walk_destination(tile)
		end
		if dest and (dest.x ~= tile.x or dest.y ~= tile.y) and Walker.on_minimap(tile) then
			Log.log("Walker", `still walking to {dest.x},{dest.y}: clicking {tile.x},{tile.y} on the minimap`)
			Walker.click_minimap(tile)
		end
	end
	return true
end

function Walker.hover_tile_async(tile: Tile, at: Tile?): boolean
	local quad = if at then Projection.tile(tile, nil, at) else aim_quad(tile)
	if quad == nil or not quad_walkable(quad) then
		return false
	end
	Mouse.move_async(quad)
	return true
end

function Walker.wait_arrival(tile: Tile, timeout_ms: number?): boolean
	local timeout = timeout_ms or 10000
	local waited = 0
	while waited < timeout do
		local me = Walker.position()
		if me == nil then
			return false
		end
		if me.x == tile.x and me.y == tile.y then
			return true
		end
		sleep(100)
		waited += 100
	end
	return false
end

function Walker.walk_tile(tile: Tile, timeout_ms: number?): boolean
	return Walker.click_tile(tile) and Walker.wait_arrival(tile, timeout_ms)
end

function Walker.distance(a: Tile, b: Tile): number
	return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

Walker.MINIMAP_REACH = 0.8
Walker.MINIMAP_CHANCE = 0.05
Walker.MINIMAP_ZOOM_MIN = 4
Walker.MINIMAP_ZOOM_HIGHER_CHANCE = 0.25
Walker.SHORTER_CHANCE = 0.2
Walker.SHORTER_MAX = 4
Walker.SCENE_SETTLE_MS = 400
Walker.SCREEN_REACH = 30

Walker.SCENE_TILES = 104
Walker.SCENE_MARGIN = 2

local function in_scene(t: Tile, base: Tile): boolean
	local x, y, last = t.x - base.x, t.y - base.y, Walker.SCENE_TILES - 1 - Walker.SCENE_MARGIN
	return x >= Walker.SCENE_MARGIN and y >= Walker.SCENE_MARGIN and x <= last and y <= last
end

local function scene_base(): string
	local p = game_state().position
	if p == nil then
		return ""
	end
	return `{p.x - p.local_x // 128},{p.y - p.local_y // 128}`
end

local function minimap_point(tile: Tile): Geometry.Point?
	local map = Minimap.widget()
	local p = Minimap.tile_to_point(tile)
	if map == nil or p == nil then
		return nil
	end
	local center = Geometry.Point.new(map.x + map.width / 2, map.y + map.height / 2)
	if Geometry.Point.distance(p, center) > map.width / 2 * Walker.MINIMAP_REACH then
		return nil
	end
	return p
end

function Walker.on_minimap(tile: Tile): boolean
	return minimap_point(tile) ~= nil
end

local function ensure_minimap_zoom(): boolean
	local zoom = Minimap.zoom()
	if zoom == nil then
		return false
	end
	if zoom >= Walker.MINIMAP_ZOOM_MIN then
		return true
	end
	local target = Walker.MINIMAP_ZOOM_MIN
	if Biometrics.random_boolean(Walker.MINIMAP_ZOOM_HIGHER_CHANCE) then
		target = Random.int(Walker.MINIMAP_ZOOM_MIN + 1, Minimap.ZOOM_MAX)
	end
	return Minimap.set_zoom(target)
end

function Walker.click_minimap(tile: Tile): boolean
	if not ensure_minimap_zoom() then
		Log.log("Walker", "couldn't set the minimap zoom")
		return false
	end
	local p = minimap_point(tile)
	if p == nil then
		Log.log("Walker", `tile {tile.x},{tile.y} isn't on the minimap`)
		return false
	end
	Mouse.click(Geometry.Circle.new(p.x, p.y, 2))
	for _ = 1, 24 do
		if Player.destination() ~= nil then
			clicked_tile = tile
			return true
		end
		sleep(50)
	end
	Log.log("Walker", "the client didn't start walking after the minimap click")
	return false
end

local function line(a: Tile, b: Tile): { Tile }
	local steps = Walker.distance(a, b)
	local tiles: { Tile } = {}
	for i = 0, steps do
		local t = if steps == 0 then 0 else i / steps
		table.insert(tiles, { x = math.round(a.x + (b.x - a.x) * t), y = math.round(a.y + (b.y - a.y) * t) })
	end
	return tiles
end

Walker.STEER_TILES = 32
Walker.STEER_OFFSETS = { -60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60 }
Walker.STEER_GAIN = 4
Walker.STEER_SLACK = 1

local function route_view(
	tiles: { NavTile },
	from: number,
	to: number,
	at: NavTile
): ({ { degrees: number, shown: number } }, number)
	local state = game_state()
	local camera, p = state.camera, state.position
	local none = from - 1
	if camera == nil or p == nil or from > to then
		return {}, none
	end
	local base_x, base_y = p.x - p.local_x // Projection.TILE, p.y - p.local_y // Projection.TILE
	local fx, fy = tile_centre(at, base_x, base_y)
	local shift = { x = math.round(fx - camera.focal_x), y = math.round(fy - camera.focal_y) }
	local wanted: { number } = {}
	local mx, my = 0, 0
	for i = from, math.min(to, from + Walker.STEER_TILES - 1) do
		local t = tiles[i]
		if
			t.plane ~= at.plane
			or Walker.distance(t, at) > Walker.SCREEN_REACH
			or not in_scene(t, { x = base_x, y = base_y })
		then
			break
		end
		table.insert(wanted, i)
		local cx, cy = tile_centre(t, base_x, base_y)
		mx += cx - fx
		my += cy - fy
	end
	if #wanted == 0 then
		return {}, none
	end
	local facing = Camera.yaw_to_degrees(camera.yaw)
	local bearing = if mx == 0 and my == 0 then facing else math.deg(math.atan2(mx, my))
	local turns: { number } = { 0 }
	for _, offset in ipairs(Walker.STEER_OFFSETS) do
		table.insert(turns, (bearing + offset - facing + 180) % 360 - 180)
	end
	local points: { Host.FinePoint } = {}
	for _, turn in ipairs(turns) do
		local c, s = math.cos(math.rad(turn)), math.sin(math.rad(turn))
		for _, i in ipairs(wanted) do
			local cx, cy = tile_centre(tiles[i], base_x, base_y)
			local dx, dy = cx - fx, cy - fy
			table.insert(points, { x = math.round(fx + dx * c - dy * s), y = math.round(fy + dx * s + dy * c), z = 0 })
		end
	end
	local screen = Projection.shifted(points, shift)
	if screen == nil then
		return {}, none
	end
	local view, blockers = walk_view(), Toplevel.blockers()
	local views: { { degrees: number, shown: number } } = {}
	local current = none
	for n, turn in ipairs(turns) do
		local shown = none
		for k = #wanted, 1, -1 do
			local point = screen[(n - 1) * #wanted + k]
			if point and Toplevel.is_visible(point, view, blockers) then
				shown = wanted[k]
				break
			end
		end
		if n == 1 then
			current = shown
		else
			table.insert(views, { degrees = facing + turn, shown = shown })
		end
	end
	return views, current
end

Walker.LOW_PITCH = 400

local function steer(tiles: { NavTile }, from: number, to: number, at: NavTile, gain: number, async: boolean?): boolean
	if not Camera.face_enabled then
		return false
	end
	local pitch = Camera.pitch()
	local low = pitch ~= nil and pitch < Camera.PITCH_MAX - Walker.LOW_PITCH
	local high = Camera.PITCH_MAX - Random.int(0, Walker.FIDGET_PITCH)
	local views, current = route_view(tiles, from, to, at)
	local best = current
	for _, v in ipairs(views) do
		best = math.max(best, v.shown)
	end
	if best - current < gain then
		if low then
			debug(`raising the camera from pitch {pitch} to {high}`)
			return if async then Camera.set_pitch_async(high) else Camera.set_pitch(high)
		end
		return false
	end
	local good = function(i: number): boolean
		return views[i] ~= nil and views[i].shown >= best - Walker.STEER_SLACK
	end
	local choices: { number } = {}
	local steady: { number } = {}
	for i, v in ipairs(views) do
		if good(i) then
			table.insert(choices, v.degrees)
			if good(i - 1) and good(i + 1) then
				table.insert(steady, v.degrees)
			end
		end
	end
	local pick = if #steady > 0 then steady else choices
	local degrees = pick[math.random(1, #pick)] + Random.int(-4, 4)
	debug(
		`turning to {math.floor(degrees % 360)} deg: route shown to {best - from + 1} tiles from {current - from + 1}`
	)
	if low then
		local yaw = Camera.degrees_to_yaw(degrees)
		return if async then Camera.set_angles_async(yaw, high) else Camera.set_angles(yaw, high)
	end
	return if async then Camera.set_yaw_degrees_async(degrees) else Camera.set_yaw_degrees(degrees)
end

Walker.STEER_CHECK_MS = 1200
Walker.FIDGET_CHANCE = 0.75
Walker.FIDGET_CHANCE_DROP = 0.15
Walker.FIDGET_DELAY_MIN_MS = 300
Walker.FIDGET_DELAY_MAX_MS = 2000
Walker.FIDGET_NEXT_MIN_MS = 100
Walker.FIDGET_NEXT_MAX_MS = 200
Walker.FIDGET_MIN_LEFT_MS = 1500
Walker.FIDGET_PITCH = 250
Walker.FIDGET_ZOOM_NOTCHES = { 1, 2, 4, 2, 1 }

local zoom_home: number? = nil
local zoom_left: number? = nil

local function home_zoom(): number?
	local current = Camera.zoom()
	if
		current
		and (zoom_home == nil or zoom_left == nil or math.abs(current - zoom_left :: number) > Camera.zoom_tolerance)
	then
		zoom_home, zoom_left = current, nil
	end
	return zoom_home
end

local function fidget(zoom: number?)
	local Tasks = lazy("./antiban/antiban_tasks")
	local roll = math.random(1, 4)
	if roll == 1 then
		Tasks.tiny_camera_rotation()
	elseif roll == 2 then
		local pitch = Camera.pitch()
		local target = Random.int(Camera.PITCH_MAX - Walker.FIDGET_PITCH, Camera.PITCH_MAX)
		if pitch and math.abs(target - pitch) > Camera.tolerance then
			debug(`tiny pitch change: {pitch} -> {target}`)
			Camera.set_pitch_async(target)
		end
	elseif roll == 3 then
		local current = Camera.zoom()
		if current and zoom then
			local change = (Random.weighted_index(Walker.FIDGET_ZOOM_NOTCHES) or 1)
				* Camera.ZOOM_STEP
				* (if Random.chance(0.5) then 1 else -1)
			local target = math.clamp(zoom + change, Camera.ZOOM_MIN, Camera.ZOOM_MAX)
			if math.abs(target - current) < Camera.ZOOM_STEP / 2 then
				target = math.clamp(zoom - change, Camera.ZOOM_MIN, Camera.ZOOM_MAX)
			end
			if math.abs(target - current) >= Camera.ZOOM_STEP / 2 then
				debug(`tiny zoom change: {current} -> {target}`)
				zoom_left = target
				Camera.set_zoom_async(target)
			end
		end
	else
		Tasks.small_random_mouse()
	end
end

local function shorter(tiles: { NavTile }, from: number, at: number, shown: (NavTile) -> boolean): number
	for i = math.max(from, at - math.random(1, Walker.SHORTER_MAX)), at - 1 do
		if shown(tiles[i]) then
			return i
		end
	end
	return at
end

local function farthest_shown(tiles: { NavTile }, from: number, to: number, shown: (NavTile) -> boolean): number?
	for i = to, from, -1 do
		if shown(tiles[i]) then
			return i
		end
	end
	return nil
end

function Walker.here(): NavTile?
	local p = game_state().position
	if p == nil or p.plane == nil then
		return nil
	end
	return { x = p.x, y = p.y, plane = p.plane :: number }
end

function Walker.plan(to: Tile, plane: number?, options: Host.NavOptions?): NavPlan?
	local here = Walker.here()
	if here == nil then
		return nil
	end
	local plan, err = nav_plan(here, { x = to.x, y = to.y, plane = plane or here.plane }, options)
	if plan == nil then
		Log.log("Walker", `no plan to {to.x}, {to.y}: {err}`)
	end
	return plan
end

Walker.SCENE_LOAD_MS = 10000
Walker.SCENE_LOAD_POLL_MS = 100
Walker.TIMEOUT_MS = 90000

export type WalkOptions = {
	near: number?,
	timeout_ms: number?,
	on_step: ((Tile) -> boolean?)?,
	straight: boolean?,
	randomize: boolean?,
	before_click: ((target: Tile, here: Tile) -> boolean?)?,
	accept: ((entry: Host.MenuEntry) -> boolean)?,
	plane: number?,
	doors: boolean?,
	climbs: boolean?,
	shortcuts: boolean?,
	nav: Host.NavOptions?,
	transports: (boolean | { exclude: { [string]: boolean }?, min_saving_ticks: number? })?,
}

Walker.ACTION_RANGE = 16
Walker.ACTION_CHECK_MS = 150
Walker.UNDERGROUND = 6400
Walker.ACTION_ATTEMPTS = 3
Walker.SHORTCUT_LANDED_NEAR = 1
Walker.ACTION_IDLE_MS = 1800
Walker.ACTION_TIMEOUT_MS = 15000
Walker.DOOR_CHECK_MS = 200
Walker.DOOR_REOPEN_MS = 3000
Walker.DOOR_STUCK = "seems to be stuck"

local function last_chat(): number
	local all = Host.chat_messages()
	return if all and #all > 0 then all[#all].uid else -1
end

local function door_stuck(since: number): boolean
	for _, m in ipairs(Host.chat_messages() or {}) do
		if m.uid > since and string.find(string.lower(m.text), Walker.DOOR_STUCK, 1, true) then
			return true
		end
	end
	return false
end
Walker.OFF_PATH = 3
Walker.REPLAN_MS = 6000
Walker.CLICK_AHEAD_MIN_MS = 600
Walker.CLICK_AHEAD_MAX_MS = 1500
Walker.FLAG_NEAR = 2
Walker.STUCK_CLICKS = 6
Walker.CLICK_GRACE_MS = 300
Walker.SETTLE_MS = 250
Walker.SETTLE_TILES = 2
Walker.MINIMAP_TILES = 20

Walker.CLIMB_PAUSE_MIN_MS = 0
Walker.CLIMB_PAUSE_MAX_MS = 900
Walker.SHORTCUT_PAUSE_MS = 1200

Walker.CAMERA_SETTLE_MS = 600

local function camera_settle()
	local began = time()
	local z, pitch = math.huge, math.huge
	while time() - began < Walker.CAMERA_SETTLE_MS do
		local c = game_state().camera
		if c == nil or (math.abs(c.z - z) <= 2 and math.abs(c.pitch - pitch) <= 2) then
			break
		end
		z, pitch = c.z, c.pitch
		sleep(40)
	end
	debug(`camera settled in {math.floor(time() - began)} ms`)
end

local function same_door(a: NavLoc, b: NavLoc, along: Tile?): boolean
	local dx, dy = b.x - a.x, b.y - a.y
	return a.plane == b.plane
		and a.option == b.option
		and math.max(math.abs(dx), math.abs(dy)) <= 1
		and (along == nil or dx * along.y - dy * along.x == 0)
end

local function wall_along(loc: Host.Loc, across: Tile): Tile?
	if loc.shape == 0 and loc.rotation then
		return if (loc.rotation :: number) % 2 == 0 then { x = 0, y = 1 } else { x = 1, y = 0 }
	end
	if across.x ~= 0 and across.y == 0 then
		return { x = 0, y = 1 }
	elseif across.y ~= 0 and across.x == 0 then
		return { x = 1, y = 0 }
	end
	return nil
end

local function loc_key(l: NavLoc): string
	return `{l.id}@{l.x},{l.y},{l.plane}`
end

local function live_loc(target: NavLoc): Host.Loc?
	for _, loc in ipairs(locs(target.plane) or {}) do
		if loc.id == target.id and loc.x == target.x and loc.y == target.y then
			return loc
		end
	end
	return nil
end

type Using = {
	action: NavAction,
	along: Tile?,
	chat: number,
	clicked_at: number,
	from: NavTile,
	still_since: number?,
	checked_at: number,
	landing: NavTile?,
}

local function walk_plan(to: Tile, opts: WalkOptions): boolean
	local Objects = lazy("./entities/objects")
	local Clickbox = lazy("./clickbox")
	local start = Walker.here()
	if start == nil then
		return false
	end
	local near = opts.near or 2
	local goal: NavTile = { x = to.x, y = to.y, plane = opts.plane or start.plane }
	local timeout = opts.timeout_ms or Walker.TIMEOUT_MS
	local randomize = opts.randomize ~= false and not opts.straight
	local nav: Host.NavOptions = if opts.nav then table.clone(opts.nav) else {}
	nav.near = near
	nav.seed = if randomize then math.random(1, 1000000000) else nil
	if opts.doors == false then
		nav.door_options = {}
	end
	if opts.climbs == false then
		nav.climbs = false
	else
		local Transports = lazy("./transports")
		if nav.allow_climbs == nil then
			nav.allow_climbs = Transports.allowed_climbs({ shortcuts = opts.shortcuts })
		end
		if nav.shortcut_saving == nil then
			nav.shortcut_saving = Transports.SHORTCUT_MIN_SAVING_TILES
		end
	end
	local avoid: { NavLoc } = table.clone(nav.avoid or {})
	nav.avoid = avoid
	local failures: { [string]: number } = {}

	local plan: NavPlan? = nil
	local planned_at, planned_base = 0, ""
	local progress = 1
	local action: NavAction? = nil
	local action_loc: Host.Loc? = nil
	local looked_at = 0
	local using: Using? = nil
	local opened: Using? = nil
	local opened_at = 0
	local clicked_at: NavTile? = nil
	local clicked_tile_at: Tile = start
	local clicked_ms = 0
	local moved_ms: number? = nil
	local last_spot = ""
	local still_clicks = 0
	local ahead_ms = math.random(Walker.CLICK_AHEAD_MIN_MS, Walker.CLICK_AHEAD_MAX_MS)
	local steered_at = 0
	local fidget_at: number? = nil
	local fidget_chance = 0
	local zoom = home_zoom()
	local started = time()
	local resume_at = 0

	local function make_plan(drawn: NavTile): boolean
		local began = time()
		local server = server_tile()
		local here = if server and (server.plane == nil or server.plane == drawn.plane)
			then { x = server.x, y = server.y, plane = drawn.plane }
			else drawn
		if opts.straight then
			local tiles: { NavTile } = {}
			for _, t in ipairs(line(here, to)) do
				table.insert(tiles, { x = t.x, y = t.y, plane = here.plane })
			end
			plan = { tiles = tiles, actions = {}, reached = true, goal = goal }
		else
			local made, err = nav_plan(here, goal, nav)
			local deadline = time() + Walker.SCENE_LOAD_MS
			while made == nil and err == "not logged in" and time() < deadline do
				sleep(Walker.SCENE_LOAD_POLL_MS)
				made, err = nav_plan(here, goal, nav)
			end
			plan = made
			if made == nil then
				Log.log("Walker", `no plan to {to.x}, {to.y} on plane {goal.plane}: {err}`)
				return false
			end
		end
		local made = time()
		local earned = planned_at == 0 or (moved_ms ~= nil and moved_ms > planned_at)
		planned_at, planned_base, progress = made, scene_base(), 1
		if opts.timeout_ms == nil and earned then
			timeout = math.max(timeout, made - started + #(plan :: NavPlan).tiles * Walker.WALK_MS_PER_TILE)
		end
		action = (plan :: NavPlan).actions[1]
		action_loc = if action then live_loc(action.loc) else nil
		debug(
			`planned {#(plan :: NavPlan).tiles} tiles, {#(plan :: NavPlan).actions} actions in {math.floor(made - began)} ms (+{math.floor(
				time() - made
			)} ms loc)`
		)
		return true
	end

	local function stretch_end(p: NavPlan): number
		return if action then action.at else #p.tiles
	end

	local function failed(a: NavAction, why: string)
		local key = loc_key(a.loc)
		failures[key] = (failures[key] or 0) + 1
		Log.log("Walker", `{a.loc.option} on {key} {why} ({failures[key]} of {Walker.ACTION_ATTEMPTS})`)
		if failures[key] >= Walker.ACTION_ATTEMPTS then
			table.insert(avoid, a.loc)
		end
		using, plan = nil, nil
	end

	local function check_using(here: NavTile)
		local u = using :: Using
		local now = time()
		if u.action.kind == "climb" then
			local landed = u.landing ~= nil
				and here.plane == (u.landing :: NavTile).plane
				and Walker.distance(here, u.landing :: NavTile) <= Walker.SHORTCUT_LANDED_NEAR
			if
				landed
				or here.plane ~= u.from.plane
				or (here.y >= Walker.UNDERGROUND) ~= (u.from.y >= Walker.UNDERGROUND)
			then
				debug(
					`climbed to {here.x}, {here.y} on plane {here.plane} {math.floor(now - u.clicked_at)} ms after the click`
				)
				using, plan = nil, nil
				local kept = here.plane == u.from.plane
					and (here.y >= Walker.UNDERGROUND) == (u.from.y >= Walker.UNDERGROUND)
				resume_at = now
					+ (
						if kept
							then Walker.SHORTCUT_PAUSE_MS
							else Random.int(Walker.CLIMB_PAUSE_MIN_MS, Walker.CLIMB_PAUSE_MAX_MS)
					)
				camera_settle()
				return
			end
		elseif now - u.checked_at >= Walker.DOOR_CHECK_MS then
			u.checked_at = now
			if door_stuck(u.chat) then
				failures[loc_key(u.action.loc)] = Walker.ACTION_ATTEMPTS - 1
				failed(u.action, "is stuck")
				return
			end
			if make_plan(here) then
				local next_action = (plan :: NavPlan).actions[1]
				local server = movement()
				local led = server ~= nil and server.moving and Player.destination() == nil
				if (next_action == nil or not same_door(next_action.loc, u.action.loc, u.along)) and not led then
					debug(`door open {math.floor(now - u.clicked_at)} ms after the click`)
					using, opened, opened_at = nil, u, now
					return
				end
			end
		end
		local server = movement()
		local moving = Player.destination() ~= nil
			or here.x ~= u.from.x
			or here.y ~= u.from.y
			or (server ~= nil and server.moving)
			or (Player.animation() or -1) ~= -1
		u.from = { x = here.x, y = here.y, plane = u.from.plane }
		if moving then
			u.still_since = nil
		elseif u.still_since == nil then
			u.still_since = now
		end
		if u.still_since and now - (u.still_since :: number) >= Walker.ACTION_IDLE_MS then
			failed(u.action, "did nothing")
		elseif now - u.clicked_at >= Walker.ACTION_TIMEOUT_MS then
			failed(u.action, "timed out")
		end
	end

	local function use(here: NavTile, a: NavAction, loc: Host.Loc, seen: boolean): boolean
		if opts.before_click and opts.before_click({ x = loc.x, y = loc.y }, here) == false then
			return false
		end
		local began = time()
		local chat = last_chat()
		local way = (plan :: NavPlan).tiles
		local wear_for_climb = lazy("./transports").wear_for_climb
		if a.kind == "climb" and not wear_for_climb(way[a.at], way[math.min(a.at + 1, #way)], a.loc.option) then
			return false
		end
		if not Objects.interact(loc, a.loc.option, false, not seen) then
			debug(`{a.loc.option} on {loc_key(a.loc)} not clicked ({math.floor(time() - began)} ms)`)
			return false
		end
		debug(`{a.loc.option} on {loc_key(a.loc)} clicked in {math.floor(time() - began)} ms`)
		local tiles = (plan :: NavPlan).tiles
		local before, after = tiles[a.at], tiles[math.min(a.at + 1, #tiles)]
		local along = wall_along(loc, { x = after.x - before.x, y = after.y - before.y })
		local stays = a.kind == "climb"
			and after.plane == before.plane
			and (after.y >= Walker.UNDERGROUND) == (before.y >= Walker.UNDERGROUND)
		using = {
			action = a,
			along = along,
			chat = chat,
			clicked_at = time(),
			from = here,
			checked_at = time(),
			landing = if stays then after else nil,
		}
		return true
	end

	local function in_view(here: NavTile, loc: Host.Loc): boolean
		if Objects.distance(loc, here) > Walker.ACTION_RANGE then
			return false
		end
		local box = Objects.clickbox(loc)
		return box ~= nil and Clickbox.target(box, loc.name or tostring(loc.id)) ~= nil
	end

	while true do
		local position = game_state().position
		if position == nil or position.plane == nil then
			return false
		end
		local here: NavTile = { x = position.x, y = position.y, plane = position.plane :: number }
		local spot = `{position.local_x},{position.local_y},{here.plane}`
		if spot ~= last_spot then
			last_spot, moved_ms = spot, time()
		end
		if here.plane == goal.plane and Walker.distance(here, to) <= near then
			return true
		end
		if opts.on_step and opts.on_step({ x = here.x, y = here.y }) == false then
			Log.log("Walker", "stopped")
			return false
		end
		if time() - started > timeout then
			Log.log("Walker", `didn't reach {to.x}, {to.y} on plane {goal.plane} within {timeout} ms`)
			return false
		end
		if scene_base() ~= planned_base and plan ~= nil then
			sleep(Walker.SCENE_SETTLE_MS)
			plan = nil
		end

		if using then
			check_using(here)
		elseif plan == nil or time() - planned_at > Walker.REPLAN_MS then
			if not make_plan(here) then
				return false
			end
		end

		local pause = math.floor(resume_at - time())
		if using == nil and plan ~= nil and pause > 0 then
			debug(`pausing {pause} ms after the climb`)
			sleep(pause)
		end

		local current = plan
		if using == nil and current then
			local p: NavPlan = current
			local last = stretch_end(p)
			local best = math.huge
			for i = progress, last do
				local t = p.tiles[i]
				local d = if t.plane == here.plane then Walker.distance(t, here) else math.huge
				if d < best then
					best, progress = d, i
				end
			end
			local flag = Player.destination()
			if best > Walker.OFF_PATH and flag == nil then
				plan = nil
			elseif action and action_loc then
				local a, loc = action :: NavAction, action_loc :: Host.Loc
				local at_stretch_end = Walker.distance(here, p.tiles[last]) <= 1 and flag == nil
				local reopening = opened ~= nil
					and time() - opened_at < Walker.DOOR_REOPEN_MS
					and same_door(a.loc, (opened :: Using).action.loc, (opened :: Using).along)
				if reopening then
					if time() - looked_at >= Walker.ACTION_CHECK_MS then
						looked_at = time()
						debug("waiting for the door that just opened")
					end
				elseif at_stretch_end or time() - looked_at >= Walker.ACTION_CHECK_MS then
					looked_at = time()
					local seen = in_view(here, loc)
					if at_stretch_end or seen then
						if use(here, a, loc, seen) then
							still_clicks = 0
						elseif at_stretch_end then
							failed(a, "couldn't be clicked")
						end
					end
				end
			elseif action then
				if time() - looked_at >= Walker.ACTION_CHECK_MS then
					looked_at = time()
					action_loc = live_loc((action :: NavAction).loc)
				end
			end
		end

		local walking = plan
		if using == nil and walking then
			local p: NavPlan = walking
			local last = stretch_end(p)
			local flag = Player.destination()
			local flag_at: number? = nil
			if flag then
				local nearest = Walker.FLAG_NEAR + 1
				for i = last, progress, -1 do
					local d = Walker.distance(p.tiles[i], flag :: Tile)
					if d < nearest then
						nearest, flag_at = d, i
						if d == 0 then
							break
						end
					end
				end
			end
			local server = server_tile()
			local lead = if server and server.plane == here.plane then Walker.distance(here, server :: Tile) else 0
			local per_tile = ms_per_tile()
			local left = if flag_at
				then math.max(0, flag_at - progress - lead) * per_tile
				elseif flag then math.max(0, Walker.distance(here, flag :: Tile) - lead) * per_tile
				else 0
			local moving = moved_ms ~= nil and time() - moved_ms < Walker.SETTLE_MS
			local arriving = flag == nil
				and moving
				and clicked_at ~= nil
				and Walker.distance(if server then server :: Tile else here, clicked_tile_at) <= 2
			local need = (flag == nil and not arriving and time() - clicked_ms >= Walker.CLICK_GRACE_MS)
				or (flag ~= nil and left <= ahead_ms and flag_at ~= last)
			if need and flag == nil and clicked_at and clicked_at.x == here.x and clicked_at.y == here.y then
				still_clicks += 1
				if still_clicks >= Walker.STUCK_CLICKS then
					Log.log("Walker", `couldn't get closer to {to.x}, {to.y} than {Walker.distance(here, to)} tiles`)
					return false
				end
				if still_clicks % 2 == 0 then
					plan = nil
					need = false
				end
			end
			if need and plan and last <= progress and flag == nil and Walker.distance(here, p.tiles[last]) == 0 then
				if p.goal.x ~= goal.x or p.goal.y ~= goal.y or p.goal.plane ~= goal.plane then
					plan = nil
				elseif action == nil then
					Log.log("Walker", `couldn't get closer to {to.x}, {to.y} than {Walker.distance(here, to)} tiles`)
					return false
				end
				need = false
			end
			if not need and flag and not Mouse.busy() then
				local now = time()
				if fidget_at and now >= (fidget_at :: number) and left - ahead_ms >= Walker.FIDGET_MIN_LEFT_MS then
					local made = Biometrics.random_boolean(fidget_chance)
					debug(`tiny move roll at {math.round(fidget_chance * 100)}%: {if made then "made" else "missed"}`)
					if made then
						fidget(zoom)
						steered_at = now
					end
					fidget_chance -= Walker.FIDGET_CHANCE_DROP
					fidget_at = if fidget_chance > 0.001
						then now + Random.int(Walker.FIDGET_NEXT_MIN_MS, Walker.FIDGET_NEXT_MAX_MS)
						else nil
				elseif
					flag_at
					and (flag_at :: number) < last
					and now - steered_at >= Walker.STEER_CHECK_MS
					and left - ahead_ms >= Walker.FIDGET_MIN_LEFT_MS
				then
					steered_at = now
					steer(p.tiles, (flag_at :: number) + 1, last, p.tiles[flag_at :: number], Walker.STEER_GAIN, true)
				end
			end
			if need and plan then
				local from = math.max(progress + 1, (flag_at or 0) + 1)
				local view, blockers = walk_view(), Toplevel.blockers()
				local shown_at: { [number]: boolean } = {}
				local shown_without_windows: { [number]: boolean } = {}
				local function look()
					shown_at, shown_without_windows = {}, {}
					local panels = Toplevel.panel_blockers()
					local base = Projection.base()
					local wanted: { number } = {}
					local points: { Host.FinePoint } = {}
					for i = from, last do
						local t = p.tiles[i]
						if
							base
							and t.plane == here.plane
							and Walker.distance(t, here) <= Walker.SCREEN_REACH
							and in_scene(t, base :: Tile)
						then
							local x, y = (t.x - base.x) * Projection.TILE, (t.y - base.y) * Projection.TILE
							local on = { x = t.x - base.x, y = t.y - base.y }
							table.insert(wanted, i)
							table.insert(points, { x = x, y = y, z = 0, tile = on })
							table.insert(points, { x = x, y = y + Projection.TILE, z = 0, tile = on })
							table.insert(points, { x = x + Projection.TILE, y = y + Projection.TILE, z = 0, tile = on })
							table.insert(points, { x = x + Projection.TILE, y = y, z = 0, tile = on })
						end
					end
					local screen = if #points > 0 then Projection.points(points) else nil
					for n, i in ipairs(wanted) do
						local c = if screen then screen[n * 4 - 3] else nil
						if c then
							local corners = screen :: { Geometry.Point }
							local quad = Geometry.Quad.new(c, corners[n * 4 - 2], corners[n * 4 - 1], corners[n * 4])
							shown_at[i] = quad_on_screen(quad, view, blockers)
							shown_without_windows[i] = quad_on_screen(quad, view, panels)
						end
					end
				end
				local function clickable(t: NavTile): boolean
					for i = from, last do
						if p.tiles[i] == t then
							return shown_at[i] == true
						end
					end
					return false
				end
				local function on_map(t: NavTile): boolean
					local base = Projection.base()
					return t.plane == here.plane
						and Walker.distance(t, here) <= Walker.MINIMAP_TILES
						and base ~= nil
						and in_scene(t, base :: Tile)
						and Walker.on_minimap(t)
				end
				local want_map = Biometrics.random_boolean(Walker.MINIMAP_CHANCE)
				local function pick(): (number?, number?)
					look()
					local screen = farthest_shown(p.tiles, from, last, clickable)
					if screen == nil and Toplevel.has_interface() then
						local hidden = false
						for i = from, last do
							hidden = hidden or (shown_without_windows[i] == true and not shown_at[i])
						end
						if hidden then
							Log.log("Walker", `closing the {Toplevel.interface_name() or "window"} that hides the way`)
							if Toplevel.escape_clear() then
								blockers = Toplevel.blockers()
								look()
								screen = farthest_shown(p.tiles, from, last, clickable)
							end
						end
					end
					if screen and screen < last and randomize and Biometrics.random_boolean(Walker.SHORTER_CHANCE) then
						screen = shorter(p.tiles, from, screen, clickable)
					end
					local map = if screen == nil or want_map then farthest_shown(p.tiles, from, last, on_map) else nil
					return screen, map
				end
				local began = time()
				if flag == nil then
					steered_at = time()
					steer(p.tiles, from, last, here, Walker.STEER_GAIN)
				end
				local on_screen, map = pick()
				local shown = on_screen or map
				if shown and moving and Walker.distance(p.tiles[shown :: number], here) <= Walker.SETTLE_TILES then
					shown = nil
				elseif shown == nil and not steer(p.tiles, from, last, here, 1) then
					Camera.face(p.tiles[math.min(progress + 4, last)], true)
				end
				if shown then
					local target = p.tiles[shown :: number]
					if opts.before_click and opts.before_click({ x = target.x, y = target.y }, here) == false then
						Log.log("Walker", "stopped")
						return false
					end
					local clicked: number? = nil
					local use_map = map ~= nil and (on_screen == nil or want_map)
					if use_map and Walker.click_minimap(p.tiles[map :: number]) then
						clicked = map
					end
					if clicked == nil and on_screen then
						local tried = on_screen :: number
						for attempt = 1, Walker.SCREEN_FALLBACKS + 1 do
							local nearer = farthest_shown(p.tiles, from, tried - 1, clickable)
							local menu = nearer == nil or attempt == Walker.SCREEN_FALLBACKS + 1
							if click_projected(p.tiles[tried], opts.accept, menu) then
								clicked = tried
								break
							end
							if nearer == nil then
								break
							end
							tried = nearer :: number
						end
					end
					if clicked == nil and map and not use_map and Walker.click_minimap(p.tiles[map :: number]) then
						clicked = map
					end
					local done = if clicked then p.tiles[clicked :: number] else target
					debug(
						`{if clicked then "clicked" else "didn't click"} {done.x}, {done.y} in {math.floor(
							time() - began
						)} ms, {if flag then "flag left " .. math.floor(left) .. " ms" else "no flag"}`
					)
					if clicked then
						ahead_ms = math.random(Walker.CLICK_AHEAD_MIN_MS, Walker.CLICK_AHEAD_MAX_MS)
						if not (clicked_at and clicked_at.x == here.x and clicked_at.y == here.y) then
							still_clicks = 0
						end
						clicked_at, clicked_ms, clicked_tile_at = here, time(), p.tiles[clicked :: number]
						steered_at = time()
						fidget_chance = Walker.FIDGET_CHANCE
						fidget_at = time() + Random.int(Walker.FIDGET_DELAY_MIN_MS, Walker.FIDGET_DELAY_MAX_MS)
						if (clicked :: number) < last then
							local gain = if on_screen == nil then 1 else Walker.STEER_GAIN
							steer(p.tiles, (clicked :: number) + 1, last, p.tiles[clicked :: number], gain)
						else
							Camera.face(p.tiles[clicked :: number], on_screen == nil)
						end
					end
				end
			end
		end
		sleep(50)
	end
end

function Walker.walk(to: Tile, options: WalkOptions?): boolean
	local opts = options or {}
	if opts.transports == false or opts.straight then
		return walk_plan(to, opts)
	end
	if opts.plane == nil then
		local start = Walker.here()
		if start ~= nil then
			opts = table.clone(opts)
			opts.plane = start.plane
		end
	end
	local Transports = lazy("./transports")
	local choices: { [string]: any } = if type(opts.transports) == "table" then table.clone(opts.transports) else {}
	choices.shortcuts = opts.shortcuts
	local hops, failures = 0, 0
	while hops < Walker.TRANSPORT_HOPS do
		local here = Walker.here()
		if here == nil then
			break
		end
		local goal = { x = to.x, y = to.y, plane = opts.plane or here.plane }
		local used, failed = Transports.travel(here, goal, choices :: any)
		if used then
			hops += 1
		elseif failed then
			failures += 1
			if failures >= Walker.TRANSPORT_FAILURES then
				break
			end
		else
			break
		end
	end
	local here = Walker.here()
	if here ~= nil then
		local goal = { x = to.x, y = to.y, plane = opts.plane or here.plane }
		if not Transports.walkable(here, goal, choices :: any) then
			error(
				`no way from {here.x}, {here.y} (plane {here.plane}) to {goal.x}, {goal.y} (plane {goal.plane}): it can't be walked, and no transport that can be used leads there`
			)
		end
	end
	return walk_plan(to, opts)
end

Walker.TRANSPORT_HOPS = 6
Walker.TRANSPORT_FAILURES = 4

return Walker
