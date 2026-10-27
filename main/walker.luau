local Host = require("../host")
local game_state = Host.game_state
local find_path = Host.find_path
local scene_route = Host.scene_route
local sleep = Host.sleep
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

local function click_projected(tile: Tile, accept: ((Host.MenuEntry) -> boolean)?): boolean
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
		Mouse.move(quad, attempt > 1)
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
	elseif not select_walk_here() then
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
-- how far ahead on the world path a walk plans in one go (the injector routes up to about 400 tiles)
Walker.ROUTE_REACH = 150
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

-- A tile a few steps before `tile` on the route that is shown too, or `tile` when there isn't one.
local function shorter(tiles: { Tile }, from: number, tile: Tile, shown: (Tile) -> boolean?): Tile
	local at = #tiles
	while at > from and tiles[at] ~= tile do
		at -= 1
	end
	for i = math.max(from, at - math.random(1, Walker.SHORTER_MAX)), at - 1 do
		if shown(tiles[i]) then
			return tiles[i]
		end
	end
	return tile
end

local function farthest_shown(tiles: { Tile }, from: number, shown: (Tile) -> boolean?): Tile?
	for i = #tiles, from, -1 do
		if shown(tiles[i]) then
			return tiles[i]
		end
	end
	return nil
end

export type WalkOptions = {
	near: number?,
	timeout_ms: number?,
	on_step: ((Tile) -> boolean?)?,
	straight: boolean?,
	-- take a different route each walk (default true; `straight` walks are never randomized)
	randomize: boolean?,
	before_click: ((target: Tile, here: Tile) -> boolean?)?,
	-- a menu entry besides "Walk here" that may sit on the tile: what we walk up to use
	accept: ((entry: Host.MenuEntry) -> boolean)?,
	-- the plane `to` is on, when not the one we are on: ladders and stairs from `Transports` take us there
	plane: number?,
	-- when the walk can't get closer, plan again through the doors of the map (default true)
	doors: boolean?,
}

-- set by a walk that gave up because the way is blocked (not because it timed out or was stopped)
local blocked = false

local function walk_scene(to: Tile, opts: WalkOptions): boolean
	blocked = false
	local near = opts.near or 2
	local timeout = opts.timeout_ms or 60000
	local me = Walker.position()
	if me == nil then
		return false
	end
	-- one seed per walk: planning again from where the player is keeps the same noise
	local randomize = opts.randomize ~= false and not opts.straight
	local seed = math.random(1, 1000000000)
	-- what the current plan walks to: `to`, or a stop along the way when it is too far to route in one go
	local goal = to
	local function plan(from: Tile): { Tile }
		goal = to
		if opts.straight then
			return line(from, to)
		end
		local route_options = if randomize then { seed = seed } else nil
		local route = scene_route(from, to, route_options)
		if route and route.reached then
			return route.tiles
		end
		local world = find_path(from, to)
		if world and #world > Walker.ROUTE_REACH then
			-- plan to a tile along the world path and again when we get there
			local stop = world[Walker.ROUTE_REACH]
			local part = scene_route(from, stop, route_options)
			if part and part.reached then
				goal = stop
				return part.tiles
			end
		end
		return world or (route and route.tiles) or line(from, to)
	end
	local tiles = plan(me)
	-- the scene the game has loaded moves when we walk near its edge: plan again over the new one
	local base = scene_base()

	local started = Host.time()
	local progress = 1
	local failures = 0
	local clicked_at: Tile? = nil
	local stuck = 0
	local reclick = math.random(3, 6)
	while true do
		local here = Walker.position()
		if here == nil then
			return false
		end
		if Walker.distance(here, to) <= near then
			return true
		end
		if opts.on_step and opts.on_step(here) == false then
			Log.log("Walker", "stopped")
			return false
		end
		local scene = scene_base()
		if scene ~= base or (goal ~= to and Walker.distance(here, goal) <= near) then
			if scene ~= base then
				-- the projection and the minimap lag behind a scene that just loaded
				sleep(Walker.SCENE_SETTLE_MS)
				stuck = 0
			end
			base = scene
			tiles, progress = plan(here), 1
		end
		if Host.time() - started > timeout then
			Log.log("Walker", `didn't reach {to.x}, {to.y} within {timeout} ms`)
			return false
		end

		local best = math.huge
		for i = progress, #tiles do
			local d = Walker.distance(tiles[i], here)
			if d < best then
				best, progress = d, i
			end
		end

		local flag = Player.destination()
		if flag == nil or (Walker.distance(here, flag) <= reclick and Walker.distance(flag, goal) > near) then
			if flag == nil and clicked_at and Walker.distance(clicked_at :: Tile, here) == 0 then
				stuck += 1
				if stuck >= 2 then
					Log.log("Walker", `couldn't get closer to {to.x}, {to.y} than {Walker.distance(here, to)} tiles`)
					blocked = true
					return false
				end
			else
				stuck = 0
			end
			clicked_at = here
			local clicked = false
			for attempt = 1, 2 do
				local view, blockers = Toplevel.viewport(), Toplevel.blockers()
				-- the game doesn't walk to a tile much farther than this from a click on the screen
				local function clickable(t: Tile): boolean
					if Walker.distance(t, here) > Walker.SCREEN_REACH then
						return false
					end
					local quad = Projection.tile(t)
					return quad ~= nil and quad_on_screen(quad, view, blockers)
				end
				local function pick(): (Tile?, Tile?)
					local screen_tile = farthest_shown(tiles, progress, clickable)
					if screen_tile and randomize and Biometrics.random_boolean(Walker.SHORTER_CHANCE) then
						screen_tile = shorter(tiles, progress, screen_tile :: Tile, clickable)
					end
					return screen_tile, farthest_shown(tiles, progress, Walker.on_minimap)
				end
				local on_screen, on_map = pick()
				local shown = on_screen or on_map
				if shown then
					if opts.before_click and opts.before_click(shown :: Tile, here) == false then
						Log.log("Walker", "stopped")
						return false
					end
					-- off screen only because the camera points elsewhere: turn to it before using the minimap
					if Camera.face(shown :: Tile, on_screen == nil) == true then
						on_screen, on_map = pick()
					end
					-- the game screen is preferred; the minimap is the rare alternative
					local use_map = on_map ~= nil
						and (on_screen == nil or Biometrics.random_boolean(Walker.MINIMAP_CHANCE))
					if use_map then
						clicked = Walker.click_minimap(on_map :: Tile) == true
					end
					if not clicked and on_screen then
						-- a tile that can't be walked on from here (something stands on it): try the ones before it
						local tried = on_screen :: Tile
						for _ = 1, Walker.SCREEN_FALLBACKS + 1 do
							clicked = click_projected(tried, opts.accept) == true
							if clicked then
								break
							end
							local before = tried
							local nearer = farthest_shown(tiles, progress, function(t: Tile): boolean
								return Walker.distance(t, here) < Walker.distance(before, here) and clickable(t)
							end)
							if nearer == nil then
								break
							end
							tried = nearer :: Tile
						end
					end
					if not clicked and on_map and not use_map then
						clicked = Walker.click_minimap(on_map :: Tile) == true
					end
					break
				end
				if attempt == 1 then
					tiles, progress = plan(here), 1
				end
			end
			if clicked then
				failures = 0
				reclick = math.random(3, 6)
			else
				failures += 1
				if failures >= 5 then
					Log.log("Walker", `couldn't click the way to {to.x}, {to.y} on the minimap`)
					blocked = true
					return false
				end
			end
		end
		sleep(100)
	end
end

-- whether the world path finds a way to `to` or to a tile around it, `near` away at most: the tile itself may be one
-- nothing can stand on (the one a bank chest is on, say), which isn't a closed door in the way
local function has_way(from: Tile, to: Tile, near: number): boolean
	if find_path(from, to) ~= nil then
		return true
	end
	for _, d in ipairs({ 1, math.max(near, 1) }) do
		for dx = -1, 1 do
			for dy = -1, 1 do
				if (dx ~= 0 or dy ~= 0) and find_path(from, { x = to.x + dx * d, y = to.y + dy * d }) ~= nil then
					return true
				end
			end
		end
	end
	return false
end

function Walker.walk(to: Tile, options: WalkOptions?): boolean
	local opts: WalkOptions = options or {}
	if opts.plane ~= nil and opts.plane ~= Player.plane() then
		-- required here because the plane walker needs the walker, and objects need it too
		return require("./planewalker").walk(to, opts.plane, opts)
	end
	if opts.doors ~= false and not opts.straight then
		-- a way the planner can't find before the first step is a closed door in it (the live scene sees open ones, the
		-- world path takes them for walls): go through the doors of the map without walking up to it to find out
		local from = Walker.position()
		local here = Player.plane()
		if from and here then
			local route = scene_route(from, to)
			if not (route and route.reached) and not has_way(from, to, opts.near or 2) then
				Log.log("Walker", "no way found: planning through the doors")
				return require("./planewalker").walk(to, here, opts)
			end
		end
	end
	local walked = walk_scene(to, opts)
	if walked or not blocked or opts.doors == false or opts.straight then
		return walked
	end
	-- the doors of the map are closed to the planner until the walk is there to see them, so a way that is blocked may
	-- have one in it
	local here = Player.plane()
	if here == nil then
		return false
	end
	Log.log("Walker", "blocked: planning through the doors")
	return require("./planewalker").walk(to, here, opts)
end

return Walker
