--!strict
local Host = require("../host")
local collision = Host.collision
local game_state = Host.game_state
local npcs = Host.npcs
local sleep = Host.sleep
local time = Host.time
type Npc = Host.Npc
type Tile = Host.Tile
local Log = require("../utils/log")
local Player = require("./player")
local Ticks = require("../utils/ticks")
local Walker = require("./walker")

local band = bit32.band

local SafeSpot = {}

-- The client's collision flags. A wall flag is set on both tiles it lies between.
SafeSpot.FLAG = {
	WALL_NORTH_WEST = 0x1,
	WALL_NORTH = 0x2,
	WALL_NORTH_EAST = 0x4,
	WALL_EAST = 0x8,
	WALL_SOUTH_EAST = 0x10,
	WALL_SOUTH = 0x20,
	WALL_SOUTH_WEST = 0x40,
	WALL_WEST = 0x80,
	-- an object, a blocking floor decoration or a floor nothing walks on
	BLOCKED = 0x1240100,
}
local BLOCKED = SafeSpot.FLAG.BLOCKED
-- what a tile outside the map reads as
local OUTSIDE = 0xFFFFFFFF

-- how far a chase is followed before it counts as going on for ever
SafeSpot.MAX_STEPS = 64
-- tiles around you `find` looks at
SafeSpot.RADIUS = 10
-- ticks an NPC must stay put, out of reach, for `trap` to call it trapped
SafeSpot.SETTLE_TICKS = 3
-- walks to a new tile when the NPC wasn't trapped
SafeSpot.ATTEMPTS = 3
-- how long `trap` waits for the walk and for the NPC to settle
SafeSpot.WALK_TIMEOUT_MS = 10000
SafeSpot.SETTLE_TIMEOUT_MS = 8000
SafeSpot.POLL_MS = 50

-- The collision of the loaded scene around you, read once: build one per scene, not per check.
export type Grid = {
	x: number,
	y: number,
	width: number,
	height: number,
	plane: number,
	flags: { number },
	-- the tiles other NPCs stand on, by "x,y" (see `SafeSpot.occupy`): an NPC doesn't walk onto them
	occupied: { [string]: boolean }?,
}

-- An NPC as the pathfinding sees it: south-west tile, size in tiles and, if read from the game, its `index`.
export type Chaser = {
	x: number,
	y: number,
	size: number,
	index: number?,
}

-- How a chase ends: "reached", "stuck", "loop" or "far" (still walking after `MAX_STEPS`); `path` is every tile it stood on.
export type Chase = {
	outcome: "reached" | "stuck" | "loop" | "far",
	path: { Tile },
	at: Tile,
	touched: boolean,
}

export type Spot = {
	tile: Tile,
	-- tiles you walk to get there
	distance: number,
	-- the chase of each NPC while you walk there and after, with the NPCs standing around now
	chases: { Chase },
	-- the same over the walls alone: where each ends up once the NPCs in its way walk off
	walls: { Chase },
	-- whether the walls alone stop every NPC (always, unless `npcs_hold`)
	walls_hold: boolean,
}

export type FindOptions = {
	-- where to look around (default you) and how far (default `RADIUS`)
	around: Tile?,
	radius: number?,
	-- where you start walking from (default you)
	from: Tile?,
	-- tiles you walk per tick on the way (default 2 when running, else 1)
	speed: number?,
	-- true drops spots an NPC reaches on the way there (default false: they come last)
	untouched: boolean?,
	-- true also takes spots held only by NPCs in the way (default false); those have `walls_hold` false
	npcs_hold: boolean?,
	-- tiles you can't stand on, by "x,y"
	exclude: { [string]: boolean }?,
	-- the most spots returned (default all)
	limit: number?,
	-- the collision to use; without one it's read, with the other NPCs around in its `occupied`
	grid: Grid?,
}

export type TrapOptions = {
	-- the NPC's size in tiles (default 1)
	size: number?,
	-- only these tiles, best first
	spots: { Tile }?,
	find: FindOptions?,
	attempts: number?,
}

local function key(x: number, y: number): string
	return `{x},{y}`
end

function SafeSpot.grid(area: Host.Corners?): (Grid?, string?)
	local c, err = collision(area)
	if c == nil then
		return nil, err
	end
	return c :: Grid, nil
end

-- The grid around a tile, `radius` tiles each way plus room for NPCs walking in from further.
function SafeSpot.grid_around(center: Tile, radius: number): (Grid?, string?)
	local r = radius + SafeSpot.MAX_STEPS // 2
	return SafeSpot.grid({ x1 = center.x - r, y1 = center.y - r, x2 = center.x + r, y2 = center.y + r })
end

function SafeSpot.flags(grid: Grid, x: number, y: number): number
	local i, j = x - grid.x, y - grid.y
	if i < 0 or j < 0 or i >= grid.width or j >= grid.height then
		return OUTSIDE
	end
	return grid.flags[i * grid.height + j + 1]
end

local flags = SafeSpot.flags

-- An NPC's size in tiles, as the game has it, or guessed (see `guess_size`) when it can't be read.
function SafeSpot.size(npc: Npc): number
	local sizes = Host.npc_sizes({ npc.index })
	return (sizes and sizes[npc.index]) or SafeSpot.guess_size(npc)
end

-- NPC size when nothing says: a standing one is drawn at the middle of its tiles, a walking one is taken as 1.
function SafeSpot.guess_size(npc: Npc): number
	if npc.local_x % 128 == 0 and npc.local_y % 128 == 0 then
		return 2
	end
	return 1
end

-- Marks the tiles NPCs stand on in `grid.occupied`, except `except` (indices); sizes from the game, `sizes`, or guessed.
function SafeSpot.occupy(grid: Grid, except: { number }?, sizes: { [string]: number }?): Grid
	local occupied: { [string]: boolean } = {}
	local all = npcs() or {}
	local indices: { number } = {}
	for _, npc in ipairs(all) do
		table.insert(indices, npc.index)
	end
	local known = Host.npc_sizes(indices) or {}
	for _, npc in ipairs(all) do
		if not (except and table.find(except, npc.index)) then
			local n = (sizes and sizes[npc.name]) or known[npc.index] or SafeSpot.guess_size(npc)
			local c = SafeSpot.chaser(npc, n)
			for i = 0, n - 1 do
				for j = 0, n - 1 do
					occupied[key(c.x + i, c.y + j)] = true
				end
			end
		end
	end
	grid.occupied = occupied
	return grid
end

local function free(grid: Grid, x: number, y: number, mask: number): boolean
	return band(flags(grid, x, y), bit32.bor(mask, BLOCKED)) == 0
end

-- Wall masks as the game checks them: a step checks the tile entered, a diagonal the two it cuts past.
local CORNER = { [-1] = { [-1] = 0x0e, [1] = 0x38 }, [1] = { [-1] = 0x83, [1] = 0xe0 } }
local SIDE_X = { [-1] = 0x08, [1] = 0x80 }
local SIDE_Y = { [-1] = 0x02, [1] = 0x20 }
-- a big NPC's column (stepping west or east) and row (south or north) entered: its two ends and the tiles between
local COLUMN = { [-1] = { low = 0x0e, high = 0x38, mid = 0x3e }, [1] = { low = 0x83, high = 0xe0, mid = 0xe3 } }
local ROW = { [-1] = { low = 0x0e, high = 0x83, mid = 0x8f }, [1] = { low = 0x38, high = 0xe0, mid = 0xf8 } }

-- Whether something of `size` with its south-west tile on `x, y` can take one step of `dx, dy` (-1, 0 or 1).
function SafeSpot.can_step(grid: Grid, x: number, y: number, dx: number, dy: number, size: number?): boolean
	local n = size or 1
	if dx == 0 and dy == 0 then
		return true
	end
	if n == 1 then
		if dy == 0 then
			return free(grid, x + dx, y, SIDE_X[dx])
		elseif dx == 0 then
			return free(grid, x, y + dy, SIDE_Y[dy])
		end
		return free(grid, x + dx, y + dy, CORNER[dx][dy])
			and free(grid, x + dx, y, SIDE_X[dx])
			and free(grid, x, y + dy, SIDE_Y[dy])
	end
	if dy == 0 then
		local cx, m = if dx < 0 then x - 1 else x + n, COLUMN[dx]
		if not free(grid, cx, y, m.low) or not free(grid, cx, y + n - 1, m.high) then
			return false
		end
		for k = 1, n - 2 do
			if not free(grid, cx, y + k, m.mid) then
				return false
			end
		end
		return true
	elseif dx == 0 then
		local ry, m = if dy < 0 then y - 1 else y + n, ROW[dy]
		if not free(grid, x, ry, m.low) or not free(grid, x + n - 1, ry, m.high) then
			return false
		end
		for k = 1, n - 2 do
			if not free(grid, x + k, ry, m.mid) then
				return false
			end
		end
		return true
	end
	local cx = if dx < 0 then x - 1 else x + n
	local ry = if dy < 0 then y - 1 else y + n
	if not free(grid, cx, ry, CORNER[dx][dy]) then
		return false
	end
	-- the column and row entered besides the corner
	local column_from = if dy < 0 then y else y + 1
	local row_from = if dx < 0 then x else x + 1
	local column_mask = COLUMN[dx].mid
	local row_mask = ROW[dy].mid
	for k = 0, n - 2 do
		if not free(grid, cx, column_from + k, column_mask) or not free(grid, row_from + k, ry, row_mask) then
			return false
		end
	end
	return true
end

-- Whether an NPC on `npc` is in melee reach of `target`: orthogonally adjacent with no wall between.
function SafeSpot.reached(grid: Grid, npc: Chaser, target: Tile): boolean
	local x, y, n = npc.x, npc.y, npc.size
	local tx, ty = target.x, target.y
	local in_x = tx >= x and tx < x + n
	local in_y = ty >= y and ty < y + n
	if in_x and in_y then
		return false
	end
	local F = SafeSpot.FLAG
	if in_x then
		if ty == y + n then
			return band(flags(grid, tx, ty), F.WALL_SOUTH) == 0
		elseif ty == y - 1 then
			return band(flags(grid, tx, ty), F.WALL_NORTH) == 0
		end
	elseif in_y then
		if tx == x + n then
			return band(flags(grid, tx, ty), F.WALL_WEST) == 0
		elseif tx == x - 1 then
			return band(flags(grid, tx, ty), F.WALL_EAST) == 0
		end
	end
	return false
end

-- Whether `target` is one of the NPC's tiles.
function SafeSpot.under(npc: Chaser, target: Tile): boolean
	return target.x >= npc.x and target.x < npc.x + npc.size and target.y >= npc.y and target.y < npc.y + npc.size
end

-- The tile the NPC heads for: the side of `target` it is on, split by the diagonals through it.
function SafeSpot.destination(npc: Chaser, target: Tile): Tile
	local n = npc.size
	local diagonal = (npc.x - target.x) + (npc.y - target.y)
	local anti = (npc.x - target.x) - (npc.y - target.y)
	local south_west = anti < 0
	local north_west = diagonal >= -(n - 1)
	local north_east = anti > 0
	local south_east = diagonal <= -(n - 1)
	if south_west and not north_west then
		-- west side
		local off = 0
		if diagonal >= -n then
			off = math.min(diagonal + n, 0)
		elseif anti > -n then
			off = -(n + anti)
		end
		return { x = target.x - n, y = target.y + off }
	elseif north_west and not north_east then
		-- north side
		local off = 0
		if anti >= -1 then
			off = math.min(anti + 1, 0)
		elseif diagonal < 1 then
			off = math.max(diagonal - 1, -(n - 1))
		end
		return { x = target.x + off, y = target.y + 1 }
	elseif north_east and not south_east then
		-- east side
		local off = 0
		if anti <= 1 then
			off = 1 - anti
		elseif diagonal < 1 then
			off = math.max(diagonal - 1, -(n - 1))
		end
		return { x = target.x + 1, y = target.y + off }
	end
	-- south side
	local off = 0
	if diagonal > -n then
		off = math.min(diagonal + n, 0)
	elseif anti < n then
		off = math.max(anti - n, -(n - 1))
	end
	return { x = target.x + off, y = target.y - n }
end

local function sign(v: number): number
	return if v > 0 then 1 elseif v < 0 then -1 else 0
end

-- Whether the NPC can step by `dx, dy`: no wall in the way and no other NPC on the tiles it steps onto.
local function can_move(grid: Grid, npc: Chaser, dx: number, dy: number): boolean
	if not SafeSpot.can_step(grid, npc.x, npc.y, dx, dy, npc.size) then
		return false
	end
	local occupied = grid.occupied
	if occupied then
		local n = npc.size
		for i = 0, n - 1 do
			for j = 0, n - 1 do
				if occupied[key(npc.x + dx + i, npc.y + dy + j)] then
					return false
				end
			end
		end
	end
	return true
end

-- The NPC's next south-west tile chasing `target`, or nil when it doesn't move.
function SafeSpot.step(grid: Grid, npc: Chaser, target: Tile): Tile?
	if SafeSpot.reached(grid, npc, target) then
		return nil
	end
	local to = SafeSpot.destination(npc, target)
	local dx, dy = sign(to.x - npc.x), sign(to.y - npc.y)
	if dx ~= 0 and dy ~= 0 and can_move(grid, npc, dx, dy) then
		return { x = npc.x + dx, y = npc.y + dy }
	end
	if dx ~= 0 and can_move(grid, npc, dx, 0) then
		return { x = npc.x + dx, y = npc.y }
	end
	if dy ~= 0 and can_move(grid, npc, 0, dy) then
		return { x = npc.x, y = npc.y + dy }
	end
	return nil
end

-- Plays out an NPC chasing you one step a tick along `route` (default: you stand on `target`).
function SafeSpot.chase(grid: Grid, npc: Chaser, target: Tile, route: { Tile }?, speed: number?): Chase
	local path: { Tile } = { { x = npc.x, y = npc.y } }
	local seen: { [string]: number } = {}
	local walk = route or { target }
	local per_tick = speed or 1
	local at = 1
	local touched = false
	local here: Chaser = { x = npc.x, y = npc.y, size = npc.size }
	for tick = 1, SafeSpot.MAX_STEPS + #walk do
		local me = walk[at]
		local walking = at < #walk
		local reached = SafeSpot.reached(grid, here, me)
		-- standing under it is no hiding: it steps off and hits
		if (reached or SafeSpot.under(here, me)) and not walking then
			return { outcome = "reached", path = path, at = path[#path], touched = touched }
		end
		-- next to you as it starts is not being reached on the way
		touched = touched or (reached and tick > 1)
		local next_tile = if reached then nil else SafeSpot.step(grid, here, me)
		if next_tile == nil and not walking then
			return { outcome = "stuck", path = path, at = path[#path], touched = touched }
		end
		if next_tile then
			here.x, here.y = next_tile.x, next_tile.y
			table.insert(path, next_tile)
		end
		at = math.min(at + per_tick, #walk)
		if not walking then
			-- you stand still from here: the same tile twice is a loop
			local k = key(here.x, here.y)
			if seen[k] then
				return { outcome = "loop", path = path, at = path[#path], touched = touched }
			end
			seen[k] = tick
		end
	end
	return { outcome = "far", path = path, at = path[#path], touched = touched }
end

-- Whether an NPC on `npc` can never reach you standing on `target`.
function SafeSpot.is_safe(grid: Grid, npc: Chaser, target: Tile): boolean
	local chase = SafeSpot.chase(grid, npc, target)
	return chase.outcome == "stuck" or chase.outcome == "loop"
end

local function npc_by_index(index: number): Npc?
	for _, npc in ipairs(npcs() or {}) do
		if npc.index == index then
			return npc
		end
	end
	return nil
end

-- The chaser of an NPC: its south-west tile, worked out from where it's drawn; `before` gives the tile it walks to.
function SafeSpot.chaser(npc: Npc, size: number?, before: Npc?): Chaser
	local n = size or 1
	local half = n * 64
	local function axis(fine: number, was: number?): number
		local t = (fine - half) / 128
		if was and fine > was then
			return math.ceil(t)
		elseif was and fine < was then
			return math.floor(t)
		end
		return math.floor(t + 0.5)
	end
	local base_x, base_y = npc.x - (npc.local_x // 128), npc.y - (npc.local_y // 128)
	return {
		x = base_x + axis(npc.local_x, before and before.local_x),
		y = base_y + axis(npc.local_y, before and before.local_y),
		size = n,
		index = npc.index,
	}
end

-- how far apart the two looks of `SafeSpot.locate` are: about two frames
SafeSpot.LOCATE_MS = 40

-- The chaser of the NPC with `index`, looked at twice to tell where it walks to. Nil when it's gone.
function SafeSpot.locate(index: number, size: number?): Chaser?
	local before = npc_by_index(index)
	if before == nil then
		return nil
	end
	sleep(SafeSpot.LOCATE_MS)
	local now = npc_by_index(index)
	if now == nil then
		return nil
	end
	return SafeSpot.chaser(now, size, before)
end

-- Walking distances from `from` over the grid within `radius` of `around`: the distance and previous tile by "x,y".
local DIRECTIONS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }

local function walks(grid: Grid, from: Tile, around: Tile, radius: number): ({ [string]: number }, { [string]: Tile })
	local distance: { [string]: number } = { [key(from.x, from.y)] = 0 }
	local previous: { [string]: Tile } = {}
	local queue: { Tile } = { from }
	local head = 1
	-- the walk may leave the area a little to get round things
	local limit = radius + 6
	while head <= #queue do
		local t = queue[head]
		head += 1
		local d = distance[key(t.x, t.y)]
		for _, dir in ipairs(DIRECTIONS) do
			local nx, ny = t.x + dir[1], t.y + dir[2]
			local k = key(nx, ny)
			if
				distance[k] == nil
				and math.max(math.abs(nx - around.x), math.abs(ny - around.y)) <= limit
				and SafeSpot.can_step(grid, t.x, t.y, dir[1], dir[2], 1)
			then
				distance[k] = d + 1
				previous[k] = t
				table.insert(queue, { x = nx, y = ny })
			end
		end
	end
	return distance, previous
end

local function route_to(previous: { [string]: Tile }, from: Tile, to: Tile): { Tile }
	local route: { Tile } = { to }
	local t = to
	while t.x ~= from.x or t.y ~= from.y do
		t = previous[key(t.x, t.y)]
		table.insert(route, 1, t)
	end
	return route
end

-- Tiles you can walk to where none of `chasers` can reach you, nearest first.
function SafeSpot.find(chasers: { Chaser }, options: FindOptions?): ({ Spot }?, string?)
	local o = options or {}
	local from = o.from or Walker.position()
	if from == nil then
		return nil, "not logged in"
	end
	local around = o.around or from
	local radius = o.radius or SafeSpot.RADIUS
	local grid = o.grid
	if grid == nil then
		local err
		grid, err =
			SafeSpot.grid_around(around, radius + math.max(math.abs(from.x - around.x), math.abs(from.y - around.y)))
		if grid == nil then
			return nil, err
		end
		local except: { number } = {}
		for _, c in ipairs(chasers) do
			if c.index then
				table.insert(except, c.index)
			end
		end
		SafeSpot.occupy(grid :: Grid, except)
	end
	local g = grid :: Grid
	local speed = o.speed or (if Player.is_running() then 2 else 1)
	local untouched = o.untouched == true
	local distance, previous = walks(g, from, around, radius)
	local walls: Grid = { x = g.x, y = g.y, width = g.width, height = g.height, plane = g.plane, flags = g.flags }
	local function holds(c: Chase): boolean
		return c.outcome == "stuck" or c.outcome == "loop"
	end
	local spots: { Spot } = {}
	for x = around.x - radius, around.x + radius do
		for y = around.y - radius, around.y + radius do
			local k = key(x, y)
			local d = distance[k]
			if d and not (o.exclude and o.exclude[k]) then
				local tile = { x = x, y = y }
				local route = route_to(previous, from, tile)
				local chases: { Chase } = {}
				local alone: { Chase } = {}
				local safe = true
				for _, npc in ipairs(chasers) do
					-- the walls have to hold it: the NPCs in its way now may walk off
					local chase = SafeSpot.chase(walls, npc, tile, route, speed)
					local crowded = if g.occupied then SafeSpot.chase(g, npc, tile, route, speed) else chase
					if
						(not holds(chase) and not o.npcs_hold)
						or not holds(crowded)
						or (untouched and (chase.touched or crowded.touched))
					then
						safe = false
						break
					end
					table.insert(chases, crowded)
					table.insert(alone, chase)
				end
				if safe then
					local walls_hold = true
					for _, c in ipairs(alone) do
						walls_hold = walls_hold and holds(c)
					end
					table.insert(
						spots,
						{ tile = tile, distance = d, chases = chases, walls = alone, walls_hold = walls_hold }
					)
				end
			end
		end
	end
	table.sort(spots, function(a, b)
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end
		local function touched(s: Spot): boolean
			for _, c in ipairs(s.chases) do
				if c.touched then
					return true
				end
			end
			return false
		end
		if touched(a) ~= touched(b) then
			return touched(b)
		end
		-- the same walk: the one the NPCs end furthest from is safer when they move a little differently
		local function gap(s: Spot): number
			local nearest = math.huge
			for _, c in ipairs(s.chases) do
				nearest = math.min(nearest, math.max(math.abs(c.at.x - s.tile.x), math.abs(c.at.y - s.tile.y)))
			end
			return nearest
		end
		return gap(a) > gap(b)
	end)
	if o.limit then
		while #spots > o.limit do
			table.remove(spots)
		end
	end
	return spots, nil
end

-- Waits until the NPC has stood on one tile for `SETTLE_TICKS` ticks; returns it, or nil and why not.
function SafeSpot.wait_trapped(index: number, size: number?, timeout_ms: number?): (Chaser?, string?)
	local started = time()
	local timeout = timeout_ms or SafeSpot.SETTLE_TIMEOUT_MS
	local last: Chaser? = nil
	local since_tick: number? = nil
	local grid: Grid? = nil
	while time() - started < timeout do
		local npc = npc_by_index(index)
		local state = game_state()
		local me = state.position
		if npc == nil or me == nil then
			return nil, "the NPC is gone"
		end
		local here = SafeSpot.chaser(npc, size)
		-- drawn on a tile edge it's still walking
		local moving = npc.local_x % 128 ~= (here.size * 64) % 128 or npc.local_y % 128 ~= (here.size * 64) % 128
		if grid == nil then
			grid = SafeSpot.grid_around(me, SafeSpot.RADIUS)
		end
		if grid and SafeSpot.reached(grid, here, me) and not moving then
			return nil, "the NPC reached you"
		end
		local tick = state.tick_count or 0
		if moving or last == nil or last.x ~= here.x or last.y ~= here.y then
			last, since_tick = here, tick
		elseif since_tick and tick - since_tick >= SafeSpot.SETTLE_TICKS then
			return last, nil
		end
		sleep(SafeSpot.POLL_MS)
	end
	return nil, "the NPC kept moving"
end

-- Gets the NPC with `index` stuck out of reach and waits for it to settle; returns your tile and the NPC's, or nil and why.
function SafeSpot.trap(index: number, options: TrapOptions?): (Tile?, Chaser? | string)
	local o = options or {}
	local size = o.size or 1
	local attempts = o.attempts or SafeSpot.ATTEMPTS
	local failure = "no attempts"
	for attempt = 1, attempts do
		local found = SafeSpot.locate(index, size)
		local me = Walker.position()
		if found == nil or me == nil then
			return nil, "the NPC is gone"
		end
		local chaser = found :: Chaser
		local spot: Tile? = nil
		if o.spots then
			local grid = SafeSpot.grid_around(me, SafeSpot.RADIUS)
			if grid then
				SafeSpot.occupy(grid, { index })
			end
			for _, tile in ipairs(o.spots) do
				if grid and SafeSpot.is_safe(grid, chaser, tile) then
					spot = tile
					break
				end
			end
		else
			local spots, err = SafeSpot.find({ chaser }, o.find)
			if spots == nil then
				return nil, err or "no spots"
			end
			spot = if spots[1] then spots[1].tile else nil
		end
		if spot == nil then
			return nil, `no tile near you keeps the NPC on {chaser.x},{chaser.y} away`
		end
		local s = spot :: Tile
		if me.x ~= s.x or me.y ~= s.y then
			Log.log("SafeSpot", `attempt {attempt}: NPC on {chaser.x},{chaser.y}, walking to {s.x},{s.y}`)
			Walker.walk(s, { near = 0, randomize = false, timeout_ms = SafeSpot.WALK_TIMEOUT_MS })
			-- one tile off is no safe spot: the walk can end next to it
			local at = Walker.position()
			if at and (at.x ~= s.x or at.y ~= s.y) then
				Walker.walk_tile(s, SafeSpot.WALK_TIMEOUT_MS)
				at = Walker.position()
			end
			if at == nil or at.x ~= s.x or at.y ~= s.y then
				failure = `couldn't walk to {s.x},{s.y}`
				continue
			end
		end
		local trapped, err = SafeSpot.wait_trapped(index, size)
		if trapped then
			return s, trapped
		end
		failure = err or "not trapped"
		Log.log("SafeSpot", `attempt {attempt}: {failure}`)
		Ticks.wait(1)
	end
	return nil, failure
end

return SafeSpot
