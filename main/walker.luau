--!strict
local Host = require("../host")
local game_state = Host.game_state
local find_path = Host.find_path
local scene_route = Host.scene_route
local nav_plan = Host.nav_plan
local locs = Host.locs
local sleep = Host.sleep
local time = Host.time
local Projection = require("./projection/projection")
local Mouse = require("../utils/input/mouse")
local Toplevel = require("./interfaces/mainscreen/toplevel")
local Minimenu = require("./interfaces/minimenu")
local Geometry = require("../utils/math/geometry")
local Minimap = require("./interfaces/minimap")
local Player = require("./player")
local Camera = require("./camera")
local Random = require("../utils/math/random")
local Biometrics = require("./antiban/biometrics")
local Log = require("../utils/log")
type Tile = Projection.Tile
type NavTile = Host.NavTile
type NavPlan = Host.NavPlan
type NavAction = Host.NavAction
type NavLoc = Host.NavLoc

local Walker = {}

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
	local start = from
	if start == nil then
		local me = Walker.position()
		if me == nil then
			return nil
		end
		start = me
	end
	return find_path(start :: Tile, to)
end

function Walker.route(to: Tile, from: Tile?): Host.SceneRoute?
	local start = from
	if start == nil then
		local me = Walker.position()
		if me == nil then
			return nil
		end
		start = me
	end
	return scene_route(start :: Tile, to)
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

-- How far (fine units, x and y) the player will have moved `ms` from now along the route; zero when not walking.
function Walker.ahead(ms: number): Host.FinePoint?
	local state = game_state()
	local p = state.position
	if p == nil then
		return nil
	end
	local flag = state.destination
	if flag == nil or ms <= 0 then
		return { x = 0, y = 0 }
	end
	local route = scene_route({ x = p.x, y = p.y }, flag)
	local tiles = if route and #route.tiles > 0 then route.tiles else { flag }
	local base_x = p.x - p.local_x // Projection.TILE
	local base_y = p.y - p.local_y // Projection.TILE
	local function centre(t: Tile): (number, number)
		return (t.x - base_x) * Projection.TILE + Projection.TILE / 2,
			(t.y - base_y) * Projection.TILE + Projection.TILE / 2
	end

	local x, y = p.local_x, p.local_y
	local first = 1
	-- The route starts on the tile the player is drawn on, whose centre is behind them once past it.
	if #tiles >= 2 then
		local ax, ay = centre(tiles[1])
		local bx, by = centre(tiles[2])
		if (ax - x) * (bx - ax) + (ay - y) * (by - ay) < 0 then
			first = 2
		end
	end
	local per_tile = if Player.is_running() then Walker.RUN_MS_PER_TILE else Walker.WALK_MS_PER_TILE
	local budget = ms * Projection.TILE / per_tile
	for i = first, #tiles do
		local tx, ty = centre(tiles[i])
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

function Walker.on_screen(tile: Tile): boolean
	local quad = Projection.tile(tile)
	return quad ~= nil and quad_on_screen(quad, Toplevel.viewport(), Toplevel.blockers())
end

Walker.HOVER_ATTEMPTS = 2
Walker.SCREEN_FALLBACKS = 2
-- "Walk here" further down the menu than this many lines isn't worth the trip: the minimap is used
Walker.WALK_HERE_MAX_ROW = 14

local function is_walk_here(entry: Host.MenuEntry): boolean
	return string.find(string.lower(entry.option), "^walk here") ~= nil
end

-- Right-clicks at the mouse and picks the first "Walk here" unless too far down; whether it was picked.
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

-- how long after the mouse gets there the click lands, for aiming ahead while walking
Walker.CLICK_LEAD_MS = 80

-- The quad of `tile` where the camera, which follows the player, will show it `lead_ms` from now.
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

-- Where to aim for `tile`: while walking the scene slides under the mouse, so where it will be once the mouse is there.
local function aim_quad(tile: Tile): Geometry.Quad?
	local quad = Projection.tile(tile)
	if quad == nil or Player.destination() == nil then
		return quad
	end
	local lead = Mouse.travel_ms(Geometry.Quad.mean(quad)) + Walker.CLICK_LEAD_MS
	return quad_ahead(tile, lead) or quad
end

-- `menu` false gives up on a tile something stands on instead of picking "Walk here" from the menu.
local function click_projected(tile: Tile, accept: ((Host.MenuEntry) -> boolean)?, menu: boolean?): boolean
	local quad = Projection.tile(tile)
	if quad == nil then
		return false
	end
	if not quad_on_screen(quad, Toplevel.viewport(), Toplevel.blockers()) then
		return false
	end
	-- something standing on the tile (a ladder, a mast) can own part of it: try other spots of the quad
	local walkable = false
	for attempt = 1, Walker.HOVER_ATTEMPTS do
		Mouse.move(aim_quad(tile) or quad, attempt > 1)
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
		return false
	end
	if before ~= nil then
		local clicked = Minimenu.wait_click(before)
		if clicked == nil then
			return false
		end
	end
	clicked_tile = tile
	return true
end

function Walker.click_tile(tile: Tile): boolean
	Camera.face(tile)
	return click_projected(tile)
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
	local clicked = Walker.click_tile(tile)
	if not clicked then
		return clicked
	end
	return Walker.wait_arrival(tile, timeout_ms)
end

function Walker.distance(a: Tile, b: Tile): number
	return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

Walker.MINIMAP_REACH = 0.8
Walker.MINIMAP_CHANCE = 0.05
-- the least minimap zoom a minimap walk clicks at, and how often a lower one is raised to a random higher level instead
Walker.MINIMAP_ZOOM_MIN = 4
Walker.MINIMAP_ZOOM_HIGHER_CHANCE = 0.25
-- how often a walk clicks short of the farthest tile it can, and by up to how many route tiles
Walker.SHORTER_CHANCE = 0.2
Walker.SHORTER_MAX = 4
-- the projection and the minimap lag behind a scene that just loaded
Walker.SCENE_SETTLE_MS = 400
-- Game screen clicks set no destination from about 35 tiles away (30 to 34 stop short); the minimap is limited by its radius.
Walker.SCREEN_REACH = 24

-- The tile of the scene the game has loaded at its corner, which changes when it loads another one.
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

-- Raises a minimap zoom below the minimum to it, or sometimes to a higher level; a zoom at or above it stays.
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
		return false
	end
	local p = minimap_point(tile)
	if p == nil then
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

-- The tile `index` steps before `at` (within `from`) that is shown, or `at` when none is.
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

-- Where you are, with your plane.
function Walker.here(): NavTile?
	local p = game_state().position
	if p == nil or p.plane == nil then
		return nil
	end
	return { x = p.x, y = p.y, plane = p.plane :: number }
end

-- Plans a walk from you to `to` on `plane` (yours by default), through doors and over ladders and staircases: `Host.nav_plan`.
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

export type WalkOptions = {
	near: number?,
	timeout_ms: number?,
	on_step: ((Tile) -> boolean?)?,
	-- walk the straight line to `to`, on your plane, without planning
	straight: boolean?,
	-- take a different way each walk (default true)
	randomize: boolean?,
	before_click: ((target: Tile, here: Tile) -> boolean?)?,
	-- a menu entry besides "Walk here" that may sit on the tile: what we walk up to use
	accept: ((entry: Host.MenuEntry) -> boolean)?,
	-- the plane `to` is on (default yours): the ladders and staircases on the way take you there
	plane: number?,
	-- open the closed doors on the way (default true); false walks round them
	doors: boolean?,
	-- climb ladders and staircases (default true); false stays on your plane
	climbs: boolean?,
	-- more for `Host.nav_plan`: door and climb options, locs to avoid, costs
	nav: Host.NavOptions?,
}

-- the farthest a door or ladder on the way is clicked from, and how often the walk looks for it on screen
Walker.ACTION_RANGE = 16
Walker.ACTION_CHECK_MS = 150
-- clicks on a door or ladder that didn't do anything before the walk plans without it
Walker.ACTION_ATTEMPTS = 3
-- a click on one has failed when the player stands still this long without it working, or after the timeout
Walker.ACTION_IDLE_MS = 1800
Walker.ACTION_TIMEOUT_MS = 15000
-- while a door is being opened: how often the walk plans again to see that it is open
Walker.DOOR_CHECK_MS = 200
-- planning again: when this many tiles off the plan, and this often anyway (doors other players open and close)
Walker.OFF_PATH = 3
Walker.REPLAN_MS = 6000
-- the next click goes in when the walk to the last one has between these many ms left
Walker.CLICK_AHEAD_MIN_MS = 450
Walker.CLICK_AHEAD_MAX_MS = 1300
-- walk clicks in a row that didn't move the player before the walk gives up (it plans again every other one)
Walker.STUCK_CLICKS = 6
-- how long after a walk click the next one waits for the flag to show
Walker.CLICK_GRACE_MS = 300
-- the player counts as still moving this long after it last moved; while it moves, tiles this close aren't clicked
Walker.SETTLE_MS = 250
Walker.SETTLE_TILES = 2
-- the farthest tile the minimap is looked at for (it shows fewer)
Walker.MINIMAP_TILES = 20

-- logs what the walk does and how long it takes
Walker.DEBUG = false

local function debug(text: string)
	if Walker.DEBUG then
		Log.log("Walker", text)
	end
end

-- After a plane change the walk waits a random pause in this range (ms; 0 to 1.5 ticks) before its next click, like a
-- player taking in the new floor. Settling the camera and planning happen inside it, so they don't add to it.
Walker.CLIMB_PAUSE_MIN_MS = 0
Walker.CLIMB_PAUSE_MAX_MS = 900

-- after a climb the camera glides to the new floor's height: what is aimed at before it stops moves under the mouse

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

local function same_loc(a: NavLoc, b: NavLoc): boolean
	return a.id == b.id and a.x == b.x and a.y == b.y and a.plane == b.plane
end

local function loc_key(l: NavLoc): string
	return `{l.id}@{l.x},{l.y},{l.plane}`
end

-- The loaded loc a plan's action uses.
local function live_loc(target: NavLoc): Host.Loc?
	for _, loc in ipairs(locs(target.plane) or {}) do
		if loc.id == target.id and loc.x == target.x and loc.y == target.y then
			return loc
		end
	end
	return nil
end

-- What a walk is doing with a door or a ladder it clicked.
type Using = {
	action: NavAction,
	clicked_at: number,
	from: NavTile,
	still_since: number?,
	checked_at: number,
}

local function walk_plan(to: Tile, opts: WalkOptions): boolean
	-- required here, untyped: objects and clickboxes need the walker
	local Objects = (require :: any)("./entities/objects")
	local Clickbox = (require :: any)("./clickbox")
	local start = Walker.here()
	if start == nil then
		return false
	end
	local near = opts.near or 2
	local goal: NavTile = { x = to.x, y = to.y, plane = opts.plane or start.plane }
	local timeout = opts.timeout_ms or 90000
	local randomize = opts.randomize ~= false and not opts.straight
	local nav: Host.NavOptions = if opts.nav then table.clone(opts.nav) else {}
	nav.near = near
	-- one seed per walk: planning again keeps the same noise
	nav.seed = if randomize then math.random(1, 1000000000) else nil
	if opts.doors == false then
		nav.door_options = {}
	end
	if opts.climbs == false then
		nav.climb_options = {}
	end
	local avoid: { NavLoc } = table.clone(nav.avoid or {})
	nav.avoid = avoid
	local failures: { [string]: number } = {}

	local plan: NavPlan? = nil
	local planned_at, planned_base = 0, ""
	local progress = 1
	-- the plan's next door or ladder, and the loaded loc it is (looked up once per plan)
	local action: NavAction? = nil
	local action_loc: Host.Loc? = nil
	local looked_at = 0
	local using: Using? = nil
	local clicked_at: NavTile? = nil
	local clicked_tile_at: Tile = start
	local clicked_ms = 0
	-- when the player was last seen moving (its tile or its spot in it changed)
	local moved_ms: number? = nil
	local last_spot = ""
	local still_clicks = 0
	local ahead_ms = math.random(Walker.CLICK_AHEAD_MIN_MS, Walker.CLICK_AHEAD_MAX_MS)
	local started = time()
	-- no click before this: the pause after a plane change
	local resume_at = 0

	local function make_plan(here: NavTile): boolean
		local began = time()
		if opts.straight then
			local tiles: { NavTile } = {}
			for _, t in ipairs(line(here, to)) do
				table.insert(tiles, { x = t.x, y = t.y, plane = here.plane })
			end
			plan = { tiles = tiles, actions = {}, reached = true, goal = goal }
		else
			local made, err = nav_plan(here, goal, nav)
			plan = made
			if made == nil then
				Log.log("Walker", `no plan to {to.x}, {to.y} on plane {goal.plane}: {err}`)
				return false
			end
		end
		local made = time()
		planned_at, planned_base, progress = made, scene_base(), 1
		action = (plan :: NavPlan).actions[1]
		action_loc = if action then live_loc(action.loc) else nil
		debug(
			`planned {#(plan :: NavPlan).tiles} tiles, {#(plan :: NavPlan).actions} actions in {math.floor(made - began)} ms (+{math.floor(
				time() - made
			)} ms loc)`
		)
		return true
	end

	-- the end of the stretch walked before the next door or ladder
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

	-- whether the door or ladder in use did its thing, failed, or is still being walked to
	local function check_using(here: NavTile)
		local u = using :: Using
		local now = time()
		if u.action.kind == "climb" then
			if here.plane ~= u.from.plane then
				debug(`climbed to plane {here.plane} {math.floor(now - u.clicked_at)} ms after the click`)
				using, plan = nil, nil
				resume_at = now + Random.int(Walker.CLIMB_PAUSE_MIN_MS, Walker.CLIMB_PAUSE_MAX_MS)
				camera_settle()
				return
			end
		elseif now - u.checked_at >= Walker.DOOR_CHECK_MS then
			u.checked_at = now
			-- open (or through it): the plan doesn't use it any more, and is the next one
			if make_plan(here) then
				local next_action = (plan :: NavPlan).actions[1]
				if next_action == nil or not same_loc(next_action.loc, u.action.loc) then
					debug(`door open {math.floor(now - u.clicked_at)} ms after the click`)
					using = nil
					return
				end
			end
		end
		local moving = Player.destination() ~= nil or here.x ~= u.from.x or here.y ~= u.from.y
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

	-- `seen` when it is on screen already: then the camera isn't turned to it first
	local function use(here: NavTile, a: NavAction, loc: Host.Loc, seen: boolean): boolean
		if opts.before_click and opts.before_click({ x = loc.x, y = loc.y }, here) == false then
			return false
		end
		local began = time()
		if not Objects.interact(loc, a.loc.option, false, not seen) then
			debug(`{a.loc.option} on {loc_key(a.loc)} not clicked ({math.floor(time() - began)} ms)`)
			return false
		end
		debug(`{a.loc.option} on {loc_key(a.loc)} clicked in {math.floor(time() - began)} ms`)
		using = { action = a, clicked_at = time(), from = here, checked_at = time() }
		return true
	end

	-- the door or ladder ahead can be clicked from here: close enough and on screen
	local function in_view(here: NavTile, loc: Host.Loc): boolean
		if Objects.distance(loc, here) > Walker.ACTION_RANGE then
			return false
		end
		local box = Objects.clickbox(loc)
		return box ~= nil and Clickbox.target(box, loc.name or tostring(loc.id)) ~= nil
	end

	while true do
		local here = Walker.here()
		if here == nil then
			return false
		end
		local position = game_state().position
		local spot = if position then `{position.local_x},{position.local_y},{here.plane}` else ""
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
			-- planned already: the rest of the pause after a plane change
			debug(`pausing {pause} ms after the plane change`)
			sleep(pause)
		end

		local current = plan
		if using == nil and current then
			local p: NavPlan = current
			local last = stretch_end(p)
			-- how far along the plan we are
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
				if at_stretch_end or time() - looked_at >= Walker.ACTION_CHECK_MS then
					looked_at = time()
					local seen = in_view(here, loc)
					if at_stretch_end or seen then
						if use(here, a, loc, seen) then
							still_clicks = 0
						elseif at_stretch_end then
							-- next to it and it still can't be clicked
							failed(a, "couldn't be clicked")
						end
					end
				end
			elseif action then
				-- the plan's door or ladder isn't loaded any more
				plan = nil
			end
		end

		local walking = plan
		if using == nil and walking then
			local p: NavPlan = walking
			local last = stretch_end(p)
			local flag = Player.destination()
			-- the index of the flag on the plan, when it is on it
			local flag_at: number? = nil
			if flag then
				for i = last, progress, -1 do
					if p.tiles[i].x == flag.x and p.tiles[i].y == flag.y then
						flag_at = i
						break
					end
				end
			end
			local ms_per_tile = if Player.is_running() then Walker.RUN_MS_PER_TILE else Walker.WALK_MS_PER_TILE
			local left = if flag_at
				then (flag_at - progress) * ms_per_tile
				elseif flag then Walker.distance(here, flag :: Tile) * ms_per_tile
				else 0
			-- the game takes the flag away when the server is there, a tile or so before the player is shown there
			local moving = moved_ms ~= nil and time() - moved_ms < Walker.SETTLE_MS
			local arriving = flag == nil
				and moving
				and clicked_at ~= nil
				and Walker.distance(here, clicked_tile_at) <= 2
			local need = (flag == nil and not arriving and time() - clicked_ms >= Walker.CLICK_GRACE_MS)
				or (flag ~= nil and left <= ahead_ms and flag_at ~= last)
			if need and flag == nil and clicked_at and clicked_at.x == here.x and clicked_at.y == here.y then
				-- the last click didn't move us
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
				-- at the end of the plan: done planning toward a far goal, or no closer to get
				if p.goal.x ~= goal.x or p.goal.y ~= goal.y or p.goal.plane ~= goal.plane then
					plan = nil
				elseif action == nil then
					Log.log("Walker", `couldn't get closer to {to.x}, {to.y} than {Walker.distance(here, to)} tiles`)
					return false
				end
				need = false
			end
			if need and plan then
				local from = math.max(progress + 1, (flag_at or 0) + 1)
				local view, blockers = Toplevel.viewport(), Toplevel.blockers()
				-- which tiles ahead are on screen, projected in one go; the game doesn't walk to a tile much farther than
				-- SCREEN_REACH from a click on the screen
				local shown_at: { [number]: boolean } = {}
				local function look()
					shown_at = {}
					local base = Projection.base()
					local wanted: { number } = {}
					local points: { Host.FinePoint } = {}
					for i = from, last do
						local t = p.tiles[i]
						if base and t.plane == here.plane and Walker.distance(t, here) <= Walker.SCREEN_REACH then
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
					return t.plane == here.plane
						and Walker.distance(t, here) <= Walker.MINIMAP_TILES
						and Walker.on_minimap(t)
				end
				-- the minimap is the rare alternative, and the way when nothing ahead is on screen
				local want_map = Biometrics.random_boolean(Walker.MINIMAP_CHANCE)
				local function pick(): (number?, number?)
					look()
					local screen = farthest_shown(p.tiles, from, last, clickable)
					if screen and screen < last and randomize and Biometrics.random_boolean(Walker.SHORTER_CHANCE) then
						screen = shorter(p.tiles, from, screen, clickable)
					end
					local map = if screen == nil or want_map then farthest_shown(p.tiles, from, last, on_map) else nil
					return screen, map
				end
				local began = time()
				local on_screen, map = pick()
				local shown = on_screen or map
				if shown and moving and Walker.distance(p.tiles[shown :: number], here) <= Walker.SETTLE_TILES then
					-- so close the scene still slides under it: let the player stop first
					shown = nil
				elseif shown == nil then
					-- nothing ahead is shown: turn to the next tile
					Camera.face(p.tiles[math.min(progress + 4, last)], true)
				end
				if shown then
					local target = p.tiles[shown :: number]
					if opts.before_click and opts.before_click({ x = target.x, y = target.y }, here) == false then
						Log.log("Walker", "stopped")
						return false
					end
					-- the plan's index of the tile clicked
					local clicked: number? = nil
					local use_map = map ~= nil and (on_screen == nil or want_map)
					if use_map and Walker.click_minimap(p.tiles[map :: number]) then
						clicked = map
					end
					if clicked == nil and on_screen then
						-- something stands on the tile (a door, a ladder): try the ones before it, and only then
						-- "Walk here" from the menu
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
						-- turned while the player walks, not before the click: off screen only because the camera
						-- points elsewhere, the next clicks go on the screen again
						Camera.face(p.tiles[clicked :: number], on_screen == nil)
					end
				end
			end
		end
		sleep(50)
	end
end

-- Walks to `to`, on `opts.plane` when given: plans with `Host.nav_plan` and plans again as it goes. Closed doors on the
-- way are clicked as soon as they show on screen, then the walk goes on once they are open; ladders and staircases the
-- same, once nothing closed is left between. A door or ladder that doesn't do anything is tried a few times, then
-- planned around.
function Walker.walk(to: Tile, options: WalkOptions?): boolean
	return walk_plan(to, options or {})
end

return Walker
