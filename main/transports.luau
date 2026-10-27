--!strict
local Host = require("../host")
local find_path = Host.find_path
local cache_locs = Host.cache_locs

export type Location = {
	x: number,
	y: number,
	plane: number,
}

-- An object that takes you from one tile to another, usually on another plane: a ladder, a staircase, a trapdoor.
export type Transport = {
	-- the name or id of the object to click
	name: string | number,
	-- the menu option that uses it ("Climb-up", "Climb-down", "Climb", ...)
	option: string,
	-- the tile you stand on to use it, and where you end up
	from: Location,
	to: Location,
	-- every tile it can be used from and every tile it may put you on, `from` and `to` included; the closest is used
	reach: { Location }?,
	lands: { Location }?,
	-- what using it adds to the cost of a route, in tiles of walking (default `Transports.USE_COST`)
	cost: number?,
	-- set for a door: the id of its closed form and its tile. It joins the tiles on both sides of it, `from` and `to`
	door: { id: number, x: number, y: number }?,
}

export type Plan = {
	-- the transports to use, in order; walking to the next one is implied
	transports: { Transport },
	-- the tile to use each of them from
	stands: { Location },
	-- the estimated length in tiles, uses included
	cost: number,
}

local Transports = {}

Transports.USE_COST = 5

local registry: { Transport } = {}
local known_stands: { [string]: boolean } = {}
local discovered: { [string]: boolean } = {}

function Transports.add(transport: Transport)
	table.insert(registry, transport)
end

-- Adds both directions of a ladder or staircase: `up` from `lower` to `upper`, `down` back.
function Transports.add_two_way(name: string | number, lower: Location, upper: Location, up: string, down: string)
	Transports.add({ name = name, option = up, from = lower, to = upper })
	Transports.add({ name = name, option = down, from = upper, to = lower })
end

function Transports.all(): { Transport }
	return table.clone(registry)
end

function Transports.clear()
	table.clear(registry)
	table.clear(discovered)
end

-- how far apart (tiles between the two) the objects of a staircase or ladder may be on their planes
Transports.PAIR_RADIUS = 6
-- the most tiles around an object kept to use it from and to land on
Transports.MAX_REACH = 6
Transports.MAX_LANDS = 4
-- the area (in tiles) added around the tiles to walk between when looking for transports
Transports.DISCOVER_MARGIN = 48
-- the menu options that climb a plane, and by how many
local CLIMBS: { [string]: number } = { ["climb-up"] = 1, ["climb-down"] = -1 }

local function footprint_distance(a: Host.CacheLoc, b: Host.CacheLoc): number
	local dx = math.max(a.x - (b.x + b.size_x - 1), b.x - (a.x + a.size_x - 1), 0)
	local dy = math.max(a.y - (b.y + b.size_y - 1), b.y - (a.y + a.size_y - 1), 0)
	return math.max(dx, dy)
end

local function standable(x: number, y: number, plane: number): boolean
	local id = `{x},{y},{plane}`
	if known_stands[id] == nil then
		known_stands[id] = find_path({ x = x, y = y }, { x = x, y = y }, plane, 1) ~= nil
	end
	return known_stands[id]
end

-- The tiles next to an object that can be stood on, nearest to its middle first.
local function standable_around(loc: Host.CacheLoc, limit: number): { Location }
	local cx, cy = loc.x + (loc.size_x - 1) / 2, loc.y + (loc.size_y - 1) / 2
	local ring: { Location } = {}
	for x = loc.x - 1, loc.x + loc.size_x do
		for y = loc.y - 1, loc.y + loc.size_y do
			if x < loc.x or x >= loc.x + loc.size_x or y < loc.y or y >= loc.y + loc.size_y then
				if standable(x, y, loc.plane) then
					table.insert(ring, { x = x, y = y, plane = loc.plane })
				end
			end
		end
	end
	table.sort(ring, function(a, b)
		return math.max(math.abs(a.x - cx), math.abs(a.y - cy)) + (a.x + a.y) * 1e-6
			< math.max(math.abs(b.x - cx), math.abs(b.y - cy)) + (b.x + b.y) * 1e-6
	end)
	while #ring > limit do
		table.remove(ring)
	end
	return ring
end

-- Registers the staircases and ladders of the game cache inside an area, loaded or not: every object with a "Climb-up"
-- or "Climb-down" option, paired with the closest one on the plane it leads to that has the opposite option. Where the
-- other end lands is a guess (the tiles around that object), which is enough because a walk plans again from where it
-- ends up. Returns how many transports it added.
function Transports.discover(area: Host.Corners): number
	local pad = Transports.PAIR_RADIUS
	local locs = cache_locs(
		{ x1 = math.max(area.x1 - pad, 0), y1 = math.max(area.y1 - pad, 0), x2 = area.x2 + pad, y2 = area.y2 + pad },
		{ actions = { "Climb-up", "Climb-down" } }
	)
	if locs == nil then
		return 0
	end
	local by_plane: { [number]: { Host.CacheLoc } } = {}
	for _, loc in ipairs(locs) do
		by_plane[loc.plane] = by_plane[loc.plane] or {}
		table.insert(by_plane[loc.plane], loc)
	end
	local added = 0
	for _, loc in ipairs(locs) do
		if loc.x >= area.x1 and loc.x <= area.x2 and loc.y >= area.y1 and loc.y <= area.y2 then
			for _, action in ipairs(loc.actions) do
				local climb = CLIMBS[string.lower(action)]
				local id = `{loc.id}@{loc.x},{loc.y},{loc.plane}:{action}`
				if climb and not discovered[id] then
					discovered[id] = true
					local opposite = if climb > 0 then "climb-down" else "climb-up"
					local partner: Host.CacheLoc? = nil
					local best = Transports.PAIR_RADIUS + 1
					for _, other in ipairs(by_plane[loc.plane + climb] or {}) do
						local d = footprint_distance(loc, other)
						local has = false
						for _, a in ipairs(other.actions) do
							has = has or string.lower(a) == opposite
						end
						if has and d < best then
							partner, best = other, d
						end
					end
					if partner then
						local reach = standable_around(loc, Transports.MAX_REACH)
						local lands = standable_around(partner, Transports.MAX_LANDS)
						if #reach > 0 and #lands > 0 then
							Transports.add({
								name = loc.name,
								option = action,
								from = reach[1],
								to = lands[1],
								reach = reach,
								lands = lands,
							})
							added += 1
						end
					end
				end
			end
		end
	end
	return added
end

-- what crossing a door adds to a route, in tiles
Transports.DOOR_COST = 2
-- the tile on the far side of a wall piece (a door) for each rotation: the wall is on the west, north, east or south edge
local WALL_SIDES: { { number } } = { { -1, 0 }, { 0, 1 }, { 1, 0 }, { 0, -1 } }

-- Registers the doors of the game cache inside an area, loaded or not, as ways between the two tiles beside them (one for
-- each direction). The cache has them closed, which is how the planner takes them; a walk looks at the live door when it
-- gets there (see `PlaneWalker.cross`). Returns how many were added.
function Transports.discover_doors(area: Host.Corners): number
	local locs = cache_locs(area, { names = { "door", "gate" }, actions = { "Open" } })
	if locs == nil then
		return 0
	end
	local added = 0
	for _, loc in ipairs(locs) do
		local id = `door {loc.id}@{loc.x},{loc.y},{loc.plane}`
		local side = WALL_SIDES[loc.rotation + 1]
		if loc.shape == 0 and side and not discovered[id] then
			discovered[id] = true
			local a = { x = loc.x, y = loc.y, plane = loc.plane }
			local b = { x = loc.x + side[1], y = loc.y + side[2], plane = loc.plane }
			if standable(a.x, a.y, a.plane) and standable(b.x, b.y, b.plane) then
				local door = { id = loc.id, x = loc.x, y = loc.y }
				for _, ends in ipairs({ { a, b }, { b, a } }) do
					Transports.add({
						name = loc.id,
						option = "Open",
						from = ends[1],
						to = ends[2],
						cost = Transports.DOOR_COST,
						door = door,
					})
				end
				added += 1
			end
		end
	end
	return added
end

-- Registers the transports and doors around two tiles and between them (not farther than a few map squares from either).
function Transports.discover_around(a: Location, b: Location): number
	local margin = Transports.DISCOVER_MARGIN
	local x1, x2 = math.min(a.x, b.x) - margin, math.max(a.x, b.x) + margin
	local y1, y2 = math.min(a.y, b.y) - margin, math.max(a.y, b.y) + margin
	local squares = ((x2 // 64) - (math.max(x1, 0) // 64) + 1) * ((y2 // 64) - (math.max(y1, 0) // 64) + 1)
	if squares <= 36 then
		local all = { x1 = math.max(x1, 0), y1 = math.max(y1, 0), x2 = x2, y2 = y2 }
		return Transports.discover(all) + Transports.discover_doors(all)
	end
	-- too much between them: just around each
	local added = 0
	for _, at in ipairs({ a, b }) do
		local reach = margin * 2
		local around = {
			x1 = math.max(at.x - reach, 0),
			y1 = math.max(at.y - reach, 0),
			x2 = at.x + reach,
			y2 = at.y + reach,
		}
		added += Transports.discover(around) + Transports.discover_doors(around)
	end
	return added
end

local function key(l: Location): string
	return `{l.x},{l.y},{l.plane}`
end

local function distance(a: Location, b: Location): number
	return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

type Node = {
	loc: Location,
	g: number,
	prev: Node?,
	via: Transport?,
	stand: Location?,
}

-- `arrived` entries are reached positions; the rest are walks not worked out yet, priced at their lower bound.
type Entry = {
	cost: number,
	arrived: boolean,
	node: Node,
	-- for a walk: the transport to walk to, or nil for the destination
	edge: Transport?,
}

local function push(heap: { Entry }, entry: Entry)
	table.insert(heap, entry)
	local i = #heap
	while i > 1 do
		local parent = i // 2
		if heap[parent].cost <= heap[i].cost then
			break
		end
		heap[parent], heap[i] = heap[i], heap[parent]
		i = parent
	end
end

local function pop(heap: { Entry }): Entry?
	local n = #heap
	if n == 0 then
		return nil
	end
	local top = heap[1]
	heap[1] = heap[n]
	heap[n] = nil
	n -= 1
	local i = 1
	while true do
		local l, r, smallest = i * 2, i * 2 + 1, i
		if l <= n and heap[l].cost < heap[smallest].cost then
			smallest = l
		end
		if r <= n and heap[r].cost < heap[smallest].cost then
			smallest = r
		end
		if smallest == i then
			break
		end
		heap[smallest], heap[i] = heap[i], heap[smallest]
		i = smallest
	end
	return top
end

-- how many tiles one walk between two tiles may look at: a tile that can't be reached would otherwise search the whole plane
Transports.WALK_LIMIT = 30000
-- what a walk that the cache says is blocked (a closed door, say) costs in the lenient plan: per tile of distance, and extra
Transports.BLOCKED_FACTOR = 2
Transports.BLOCKED_COST = 20

-- Plans the cheapest way between two tiles that may be on different planes, over the registered transports.
-- Walks on a plane are priced by the world path (`Host.find_path`), which is only asked for the edges that could win.
-- That path takes closed doors for walls: when it finds no way, the plan is made again with such walks priced by their
-- distance instead, as the walk itself (which sees opened doors) may still get through.
function Transports.plan(from: Location, to: Location): Plan?
	local by_plane: { [number]: { Transport } } = {}
	for _, t in ipairs(registry) do
		local list = by_plane[t.from.plane]
		if list == nil then
			list = {}
			by_plane[t.from.plane] = list
		end
		table.insert(list, t)
	end

	local walks: { [string]: number } = {}
	-- the length of the walk between two tiles of a plane; nil when there is no way
	local function walk(a: Location, b: Location, lenient: boolean): number?
		if a.x == b.x and a.y == b.y then
			return 0
		end
		local id = `{key(a)}>{key(b)}`
		local known = walks[id]
		if known == nil then
			local path = find_path({ x = a.x, y = a.y }, { x = b.x, y = b.y }, a.plane, Transports.WALK_LIMIT)
			known = if path then #path - 1 else -1
			walks[id] = known
		end
		if known >= 0 then
			return known
		end
		if lenient then
			return distance(a, b) * Transports.BLOCKED_FACTOR + Transports.BLOCKED_COST
		end
		return nil
	end

	local function search(lenient: boolean): Plan?
		local heap: { Entry } = {}
		local visited: { [string]: boolean } = {}

		-- entries are ordered by the cost so far plus the distance still to go from where they end up
		local function expand(node: Node)
			local plane = node.loc.plane
			if plane == to.plane then
				push(heap, { cost = node.g + distance(node.loc, to), arrived = false, node = node, edge = nil })
			end
			for _, t in ipairs(by_plane[plane] or {}) do
				local closest = math.huge
				for _, r in ipairs(t.reach or { t.from }) do
					closest = math.min(closest, distance(node.loc, r))
				end
				local cost = node.g + closest + (t.cost or Transports.USE_COST) + distance(t.to, to)
				push(heap, { cost = cost, arrived = false, node = node, edge = t })
			end
		end

		push(heap, { cost = 0, arrived = true, node = { loc = from, g = 0 }, edge = nil })
		while true do
			local entry = pop(heap)
			if entry == nil then
				return nil
			end
			local node = entry.node
			if entry.arrived then
				if node.via == nil and node.prev ~= nil then
					-- the destination
					local transports: { Transport } = {}
					local stands: { Location } = {}
					local at: Node? = node
					while at ~= nil do
						if at.via and at.stand then
							table.insert(transports, 1, at.via)
							table.insert(stands, 1, at.stand)
						end
						at = at.prev
					end
					return { transports = transports, stands = stands, cost = node.g }
				end
				local id = key(node.loc)
				if not visited[id] then
					visited[id] = true
					expand(node)
				end
			else
				local edge = entry.edge
				local length: number? = nil
				local stand: Location? = nil
				if edge then
					for _, r in ipairs(edge.reach or { edge.from }) do
						if length == nil or distance(node.loc, r) < length then
							local w = walk(node.loc, r, lenient)
							if w ~= nil and (length == nil or w < length) then
								length, stand = w, r
							end
						end
					end
				else
					length = walk(node.loc, to, lenient)
				end
				if length ~= nil then
					local arrival = node.g + length
					if edge then
						arrival += edge.cost or Transports.USE_COST
						for _, land in ipairs(edge.lands or { edge.to }) do
							if not visited[key(land)] then
								push(heap, {
									cost = arrival + distance(land, to),
									arrived = true,
									node = { loc = land, g = arrival, prev = node, via = edge, stand = stand },
									edge = nil,
								})
							end
						end
					else
						push(heap, {
							cost = arrival,
							arrived = true,
							node = { loc = to, g = arrival, prev = node },
							edge = nil,
						})
					end
				end
			end
		end
	end

	return search(false) or search(true)
end

return Transports
