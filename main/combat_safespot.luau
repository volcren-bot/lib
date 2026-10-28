--!strict
-- Safe spots to fight from: tiles where a melee NPC gets stuck where it can't hit you, but where you can still
-- hit it from range (a bow, a crossbow, a spell). Built on `SafeSpot`, which works out how NPCs chase you.
local Host = require("../host")
local game_state = Host.game_state
local item_container = Host.item_container
local item_params = Host.item_params
local npcs = Host.npcs
local players = Host.players
local varp = Host.varp
type Npc = Host.Npc
type Tile = Host.Tile
local Log = require("../utils/log")
local Npcs = require("./entities/npcs")
local SafeSpot = require("./safespot")
local Ticks = require("../utils/ticks")
local Walker = require("./walker")
type Grid = SafeSpot.Grid
type Chaser = SafeSpot.Chaser
type Chase = SafeSpot.Chase

local band, bor = bit32.band, bit32.bor

local CombatSafeSpot = {}

-- The collision flags that stop a projectile: walls (the wall flags shifted up 9 bits) and objects.
CombatSafeSpot.FLAG = {
	SIGHT_NORTH = 0x400,
	SIGHT_EAST = 0x1000,
	SIGHT_SOUTH = 0x4000,
	SIGHT_WEST = 0x10000,
	SIGHT_FULL = 0x20000,
}
local F = CombatSafeSpot.FLAG

-- the worn items container, the weapon's slot, and its attack range param
CombatSafeSpot.WORN = 94
CombatSafeSpot.WEAPON_SLOT = 3
CombatSafeSpot.RANGE_PARAM = 13
-- the attack style varp, the style that adds `LONGRANGE_BONUS`, and the farthest anything attacks from
CombatSafeSpot.STYLE_VARP = 43
CombatSafeSpot.LONGRANGE_STYLE = 3
CombatSafeSpot.LONGRANGE_BONUS = 2
CombatSafeSpot.MAX_RANGE = 10
-- tiles around the NPC other NPCs are looked at for `avoid`
CombatSafeSpot.AVOID_RADIUS = 16
-- ticks `fight` gives an attack to show before clicking again
CombatSafeSpot.ATTACK_TICKS = 3
-- ticks `fight` waits on its spot for the NPC to come in range before the fight started, and reads it may be
-- missing for before it counts as gone
CombatSafeSpot.ENGAGE_TICKS = 15
CombatSafeSpot.GONE_READS = 2
-- how long `fight` goes on for at most
CombatSafeSpot.FIGHT_TIMEOUT_MS = 10 * 60 * 1000
-- walks to a new spot before `fight` gives up
CombatSafeSpot.REPOSITIONS = 6

export type CombatSpot = {
	tile: Tile,
	-- tiles you walk to get there
	distance: number,
	-- where the NPC ends up stuck with the NPCs around standing still, and once they walked off (nil when then
	-- it reaches you: only the NPCs in its way hold it)
	at: Tile,
	at_walls: Tile?,
	-- how far you are from it once it's stuck
	gap: number,
	spot: SafeSpot.Spot,
}

export type CombatFindOptions = {
	-- your attack range (default `CombatSafeSpot.weapon_range()`)
	range: number?,
	-- the least distance it may be stuck at (default 2: never next to you, even across a wall)
	min_gap: number?,
	-- other NPCs the spot must keep away from too, besides the target
	others: { Chaser }?,
	-- false only takes spots the walls alone hold it at (default true: an NPC stuck behind other NPCs counts,
	-- and those spots come after the ones the walls hold)
	npcs_hold: boolean?,
	-- you can hit it where it is now too, so the fight starts from the spot: attacking something out of range
	-- walks you up to it
	attack_now: boolean?,
	-- passed on to `SafeSpot.find`: where to look, from where, how fast you walk...
	around: Tile?,
	radius: number?,
	from: Tile?,
	speed: number?,
	untouched: boolean?,
	exclude: { [string]: boolean }?,
	limit: number?,
	grid: Grid?,
}

export type FightOptions = {
	range: number?,
	min_gap: number?,
	-- names of NPCs to stay safe from as well (any case), like the other monsters of the area
	avoid: { string }?,
	-- see `CombatFindOptions.npcs_hold`
	npcs_hold: boolean?,
	radius: number?,
	-- called every tick with the NPC and your tile; return false to stop (eat, flee...)
	on_tick: ((npc: Chaser, me: Tile) -> boolean?)?,
	timeout_ms: number?,
}

-- Whether a projectile flies from `from` to `to`, as the game checks it: a line over the tiles between, stopped
-- by walls across it and by objects that block it. Water and other floors don't.
function CombatSafeSpot.line_of_sight(grid: Grid, from: Tile, to: Tile): boolean
	if from.x == to.x and from.y == to.y then
		return true
	end
	local flags = SafeSpot.flags
	local dx, dy = to.x - from.x, to.y - from.y
	local adx, ady = math.abs(dx), math.abs(dy)
	local x_flags = bor(F.SIGHT_FULL, if dx < 0 then F.SIGHT_EAST else F.SIGHT_WEST)
	local y_flags = bor(F.SIGHT_FULL, if dy < 0 then F.SIGHT_NORTH else F.SIGHT_SOUTH)
	-- fixed point, 16 bits of fraction, divisions rounded towards zero
	local function slope(d: number, over: number): number
		local v = d * 65536
		return if v < 0 then -(-v // over) else v // over
	end
	if adx > ady then
		local x = from.x
		local y_big = from.y * 65536 + 0x8000 - (if dy < 0 then 1 else 0)
		local step = slope(dy, adx)
		local direction = if dx < 0 then -1 else 1
		while x ~= to.x do
			x += direction
			local y = y_big // 65536
			if band(flags(grid, x, y), x_flags) ~= 0 then
				return false
			end
			y_big += step
			local next_y = y_big // 65536
			if next_y ~= y and band(flags(grid, x, next_y), y_flags) ~= 0 then
				return false
			end
		end
	else
		local y = from.y
		local x_big = from.x * 65536 + 0x8000 - (if dx < 0 then 1 else 0)
		local step = slope(dx, ady)
		local direction = if dy < 0 then -1 else 1
		while y ~= to.y do
			y += direction
			local x = x_big // 65536
			if band(flags(grid, x, y), y_flags) ~= 0 then
				return false
			end
			x_big += step
			local next_x = x_big // 65536
			if next_x ~= x and band(flags(grid, next_x, y), x_flags) ~= 0 then
				return false
			end
		end
	end
	return true
end

-- The NPC's tile nearest to `me`: the one distances and lines of sight are measured to.
function CombatSafeSpot.nearest_tile(npc: Chaser, me: Tile): Tile
	return {
		x = math.clamp(me.x, npc.x, npc.x + npc.size - 1),
		y = math.clamp(me.y, npc.y, npc.y + npc.size - 1),
	}
end

-- How many tiles from `me` the NPC is, to its nearest tile (diagonal steps count as one).
function CombatSafeSpot.distance(npc: Chaser, me: Tile): number
	local t = CombatSafeSpot.nearest_tile(npc, me)
	return math.max(math.abs(t.x - me.x), math.abs(t.y - me.y))
end

-- Whether you can hit the NPC from `me` with an attack range of `range`: within range, in sight, not under it.
function CombatSafeSpot.can_attack(grid: Grid, me: Tile, npc: Chaser, range: number): boolean
	if SafeSpot.under(npc, me) then
		return false
	end
	local t = CombatSafeSpot.nearest_tile(npc, me)
	if math.max(math.abs(t.x - me.x), math.abs(t.y - me.y)) > range then
		return false
	end
	return CombatSafeSpot.line_of_sight(grid, me, t)
end

-- Your attack range with the weapon you wear and the style you fight with: the weapon's own, plus
-- `LONGRANGE_BONUS` on longrange, at most `MAX_RANGE`. 1 with nothing in your hands. Nil when it can't be read.
function CombatSafeSpot.weapon_range(): number?
	local worn = item_container(CombatSafeSpot.WORN)
	if worn == nil then
		return nil
	end
	local weapon: number? = nil
	for _, item in ipairs(worn) do
		if item.slot == CombatSafeSpot.WEAPON_SLOT and item.id > 0 then
			weapon = item.id
		end
	end
	if weapon == nil then
		return 1
	end
	local params = item_params({ weapon })
	local range = params and params[1] and params[1][CombatSafeSpot.RANGE_PARAM]
	if type(range) ~= "number" then
		return nil
	end
	if range > 1 and varp(CombatSafeSpot.STYLE_VARP) == CombatSafeSpot.LONGRANGE_STYLE then
		range += CombatSafeSpot.LONGRANGE_BONUS
	end
	return math.min(range, CombatSafeSpot.MAX_RANGE)
end

-- Tiles to fight `target` from, nearest walk first: it chases you there and gets stuck (see `SafeSpot.find`)
-- within your range and in sight, at least `min_gap` tiles away, while `others` can't reach you either. Where
-- it ends up is played out twice, with the NPCs around standing still and over the walls alone, and you
-- have to be able to hit it either way.
function CombatSafeSpot.find(target: Chaser, options: CombatFindOptions?): ({ CombatSpot }?, string?)
	local o = options or {}
	local range = o.range or CombatSafeSpot.weapon_range()
	if range == nil then
		return nil, "the weapon's range can't be read"
	end
	local r = range :: number
	local min_gap = o.min_gap or 2
	local me = o.from or Walker.position()
	if me == nil then
		return nil, "not logged in"
	end
	local chasers: { Chaser } = { target }
	for _, other in ipairs(o.others or {}) do
		table.insert(chasers, other)
	end
	local grid = o.grid
	local radius = o.radius or (r + 4)
	if grid == nil then
		local around = o.around or me :: Tile
		local err
		grid, err = SafeSpot.grid_around(around, radius + Walker.distance(around, me :: Tile))
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
	local spots, err = SafeSpot.find(chasers, {
		around = o.around,
		radius = radius,
		from = me,
		speed = o.speed,
		untouched = o.untouched,
		exclude = o.exclude,
		npcs_hold = o.npcs_hold ~= false,
		grid = g,
	})
	if spots == nil then
		return nil, err
	end
	local found: { CombatSpot } = {}
	for _, spot in ipairs(spots) do
		local crowded, alone = spot.chases[1], spot.walls[1]
		local a = { x = crowded.at.x, y = crowded.at.y, size = target.size }
		local b = { x = alone.at.x, y = alone.at.y, size = target.size }
		local gap = CombatSafeSpot.distance(a, spot.tile)
		if spot.walls_hold then
			gap = math.min(gap, CombatSafeSpot.distance(b, spot.tile))
		end
		if
			gap >= min_gap
			and CombatSafeSpot.can_attack(g, spot.tile, a, r)
			and (not spot.walls_hold or CombatSafeSpot.can_attack(g, spot.tile, b, r))
			and (not o.attack_now or CombatSafeSpot.can_attack(g, spot.tile, target, r))
		then
			table.insert(found, {
				tile = spot.tile,
				distance = spot.distance,
				at = crowded.at,
				at_walls = if spot.walls_hold then alone.at else nil,
				gap = gap,
				spot = spot,
			})
		end
	end
	-- spots the walls hold first, then the nearest walk
	table.sort(found, function(x, y)
		if x.spot.walls_hold ~= y.spot.walls_hold then
			return x.spot.walls_hold
		end
		return x.distance < y.distance
	end)
	if o.limit then
		while #found > o.limit do
			table.remove(found)
		end
	end
	return found, nil
end

local function npc_by_index(index: number): Npc?
	for _, npc in ipairs(npcs() or {}) do
		if npc.index == index then
			return npc
		end
	end
	return nil
end

-- The NPCs called one of `names` around `center`, as chasers, leaving out `except`.
function CombatSafeSpot.chasers(names: { string }, center: Tile, except: number?): { Chaser }
	local wanted: { [string]: boolean } = {}
	for _, name in ipairs(names) do
		wanted[string.lower(name)] = true
	end
	local picked: { Npc } = {}
	local indices: { number } = {}
	for _, npc in ipairs(npcs() or {}) do
		if
			npc.index ~= except
			and wanted[string.lower(Npcs.clean_name(npc.name))]
			and Walker.distance(npc, center) <= CombatSafeSpot.AVOID_RADIUS
		then
			table.insert(picked, npc)
			table.insert(indices, npc.index)
		end
	end
	local sizes = Host.npc_sizes(indices) or {}
	local out: { Chaser } = {}
	for _, npc in ipairs(picked) do
		table.insert(out, SafeSpot.chaser(npc, sizes[npc.index] or SafeSpot.guess_size(npc)))
	end
	return out
end

-- The name of another player fighting the NPC with `index` (it's their target), or nil. Leave those alone.
function CombatSafeSpot.fought_by(index: number): string?
	local name = game_state().player_name
	for _, p in ipairs(players() or {}) do
		if p.name ~= name and p.target_state == 0 and p.target_npc == index then
			return p.name
		end
	end
	return nil
end

-- The nearest NPC called `name` (any case) that no other player is fighting, from `from` (default you).
function CombatSafeSpot.free_target(name: string, from: Tile?): Npc?
	local origin = from or Walker.position()
	if origin == nil then
		return nil
	end
	local busy: { [number]: boolean } = {}
	local mine = game_state().player_name
	for _, p in ipairs(players() or {}) do
		if p.name ~= mine and p.target_state == 0 then
			busy[p.target_npc] = true
		end
	end
	local best: Npc? = nil
	local best_distance = math.huge
	for _, npc in ipairs(Npcs.find(name) or {}) do
		local d = Walker.distance(npc, origin :: Tile)
		if not busy[npc.index] and d < best_distance then
			best, best_distance = npc, d
		end
	end
	return best
end

-- Whether you are attacking the NPC with `index`: your target, and swinging at it lately.
local function my_target(): (number?, number)
	local name = game_state().player_name
	for _, p in ipairs(players() or {}) do
		if p.name == name then
			return (if p.target_state == 0 then p.target_npc else nil), p.animation
		end
	end
	return nil, -1
end

-- Whether standing on `me` holds against the NPC as things are: it gets stuck (behind walls or the NPCs in
-- its way) at least `min_gap` away, where you can hit it. When an NPC it's stuck behind walks off, this turns
-- false and `fight` finds another spot.
local function holds(grid: Grid, npc: Chaser, me: Tile, range: number, min_gap: number): boolean
	local chase = SafeSpot.chase(grid, npc, me)
	if chase.outcome ~= "stuck" and chase.outcome ~= "loop" then
		return false
	end
	local at = { x = chase.at.x, y = chase.at.y, size = npc.size }
	return CombatSafeSpot.distance(at, me) >= min_gap and CombatSafeSpot.can_attack(grid, me, at, range)
end

local function walk_exact(tile: Tile)
	Walker.walk(tile, { near = 0, randomize = false, timeout_ms = SafeSpot.WALK_TIMEOUT_MS })
	local at = Walker.position()
	if at and (at.x ~= tile.x or at.y ~= tile.y) then
		Walker.walk_tile(tile, SafeSpot.WALK_TIMEOUT_MS)
	end
end

-- Fights the NPC with `index` from a safe spot until it's gone (dead) or `on_tick` says stop. It won't start
-- on an NPC another player is fighting (see `fought_by`). Before the fight
-- starts it walks to a spot `find` gives where the NPC is in range already, so attacking it doesn't walk you
-- up to it (or waits there `ENGAGE_TICKS` for it to come in range); then it attacks, and walks to another spot
-- whenever the NPC isn't stuck where you can hit it any more. The NPC's size is read from the game. Returns
-- true when it's gone, else false and why.
function CombatSafeSpot.fight(index: number, options: FightOptions?): (boolean, string?)
	local o = options or {}
	local range = o.range or CombatSafeSpot.weapon_range()
	if range == nil then
		return false, "the weapon's range can't be read"
	end
	local r = range :: number
	local min_gap = o.min_gap or 2
	local first = npc_by_index(index)
	if first == nil then
		return true, nil
	end
	local size = SafeSpot.size(first)
	local started = Host.time()
	local timeout = o.timeout_ms or CombatSafeSpot.FIGHT_TIMEOUT_MS
	local spot: Tile? = nil
	local exclude: { [string]: boolean } = {}
	local repositions = 0
	local attacked_tick = -math.huge
	local engaged = false
	local waited = 0
	local missing = 0
	while Host.time() - started < timeout do
		local npc = SafeSpot.locate(index, size)
		local me = Walker.position()
		if me == nil then
			return false, "not logged in"
		end
		if npc == nil then
			missing += 1
			if missing >= CombatSafeSpot.GONE_READS then
				return true, nil
			end
		else
			missing = 0
			local n = npc :: Chaser
			local m = me :: Tile
			if o.on_tick and o.on_tick(n, m) == false then
				return false, "stopped"
			end
			local target = my_target()
			engaged = engaged or target == index
			if not engaged then
				local other = CombatSafeSpot.fought_by(index)
				if other then
					return false, `{other} is fighting it`
				end
			end
			local grid = assert(SafeSpot.grid_around(m, r + 4))
			SafeSpot.occupy(grid, { index })
			local others = if o.avoid then CombatSafeSpot.chasers(o.avoid, m, index) else {}
			local on_spot = spot ~= nil and spot.x == m.x and spot.y == m.y
			local good = on_spot and holds(grid, n, m, r, min_gap)
			for _, other in ipairs(others) do
				good = good and SafeSpot.is_safe(grid, other, m)
			end
			if not good then
				if on_spot then
					-- it didn't work out here: somewhere else next time
					exclude[`{m.x},{m.y}`] = true
				end
				repositions += 1
				if repositions > CombatSafeSpot.REPOSITIONS then
					return false, `no spot held after {CombatSafeSpot.REPOSITIONS} walks`
				end
				local find_options: CombatFindOptions = {
					range = r,
					min_gap = min_gap,
					others = others,
					radius = o.radius,
					exclude = exclude,
					npcs_hold = o.npcs_hold,
					attack_now = not engaged,
					limit = 1,
				}
				local spots, err = CombatSafeSpot.find(n, find_options)
				if (spots == nil or spots[1] == nil) and not engaged then
					-- nowhere to hit it from yet: a spot to wait on for it to come
					find_options.attack_now = false
					spots, err = CombatSafeSpot.find(n, find_options)
				end
				if spots == nil or spots[1] == nil then
					return false, err or `no spot to fight it from near {m.x},{m.y}`
				end
				local best = spots[1]
				spot = best.tile
				Log.log(
					"CombatSafeSpot",
					`NPC on {n.x},{n.y}: fighting from {best.tile.x},{best.tile.y}, it should stop on {best.at.x},{best.at.y}`
				)
				if not on_spot or m.x ~= best.tile.x or m.y ~= best.tile.y then
					walk_exact(best.tile)
				end
				attacked_tick = -math.huge
			elseif target ~= index then
				local tick = game_state().tick_count or 0
				if not engaged and not CombatSafeSpot.can_attack(grid, m, n, r) then
					-- attacking from out of range walks us up to it: wait for it to come
					waited += 1
					if waited > CombatSafeSpot.ENGAGE_TICKS then
						return false, "it doesn't come in range of the spot"
					end
				elseif tick - attacked_tick >= CombatSafeSpot.ATTACK_TICKS then
					local now = npc_by_index(index)
					if now then
						local clicked = Npcs.interact(now, "Attack", false)
						attacked_tick = tick
						-- a click that missed it walks us off the spot, maybe up to it: straight back
						local s = spot :: Tile
						local to = game_state().destination
						if not clicked and to and (to.x ~= s.x or to.y ~= s.y) then
							Log.log("CombatSafeSpot", "the attack missed and walks us off the spot, going back")
							Walker.walk_tile(s, SafeSpot.WALK_TIMEOUT_MS)
						end
					end
				end
			end
		end
		Ticks.wait(1)
	end
	return false, "timed out"
end

return CombatSafeSpot
