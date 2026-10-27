--!strict
local Host = require("../host")
local sleep = Host.sleep
local time = Host.time
type Tile = Host.Tile
local Objects = require("./entities/objects")
local Player = require("./player")
local Transports = require("./transports")
local Walker = require("./walker")
local Log = require("../utils/log")
type Transport = Transports.Transport

local PlaneWalker = {}

-- how close to its tile a transport's object has to be to be the one we want
PlaneWalker.OBJECT_RADIUS = 3
-- how far from the tile of a transport the walk to it may stop
PlaneWalker.NEAR = 1
PlaneWalker.PLANE_TIMEOUT_MS = 6000
PlaneWalker.DOOR_TIMEOUT_MS = 8000
-- uses of transports that didn't get us anywhere before the walk gives up
PlaneWalker.MAX_FAILURES = 3
-- look the ladders and staircases up in the game cache before planning (`Transports.discover`), besides the added ones
PlaneWalker.DISCOVER = true

local function find_object(transport: Transport, stand: Transports.Location): Host.Loc?
	local plane = Player.plane()
	local best: Host.Loc? = nil
	local best_distance = math.huge
	local found: { Host.Loc } = Objects.find(transport.name) or {}
	for _, loc in ipairs(found) do
		if loc.plane == plane then
			local d = Objects.distance(loc, stand)
			if d <= PlaneWalker.OBJECT_RADIUS and d < best_distance then
				best, best_distance = loc, d
			end
		end
	end
	return best
end

-- The closed door of a transport that is loaded, if it is: a closed door is a loc of its id on its tile, open ones are
-- another loc or none.
local function closed_door(door: { id: number, x: number, y: number }, plane: number): Host.Loc?
	local found: { Host.Loc } = Objects.find(door.id) or {}
	for _, loc in ipairs(found) do
		if loc.plane == plane and loc.x == door.x and loc.y == door.y then
			return loc
		end
	end
	return nil
end

-- Gets through a door from the tile beside it: opens it when it is closed, which is read now that it is loaded (it is
-- skipped when it already is open), and walks to the tile on the other side.
function PlaneWalker.cross(transport: Transport): boolean
	local door = transport.door
	local plane = Player.plane()
	if door == nil or plane == nil then
		return false
	end
	local loc = closed_door(door, plane)
	if loc then
		if not Objects.approach(loc, transport.option) then
			return false
		end
		local started = time()
		while closed_door(door, plane) ~= nil do
			if time() - started > PlaneWalker.DOOR_TIMEOUT_MS then
				Log.log("PlaneWalker", `the door at {door.x}, {door.y} didn't open`)
				return false
			end
			sleep(100)
		end
	end
	local across = { x = transport.to.x, y = transport.to.y }
	return Walker.walk(across, { near = 0, timeout_ms = PlaneWalker.DOOR_TIMEOUT_MS, doors = false })
end

-- Uses a transport from the tile in front of it; whether the player ended up on its plane.
function PlaneWalker.use(transport: Transport, stand: Transports.Location?): boolean
	if transport.door then
		return PlaneWalker.cross(transport)
	end
	local loc = find_object(transport, stand or transport.from)
	if loc == nil then
		Log.log("PlaneWalker", `no {transport.name} near {transport.from.x}, {transport.from.y}`)
		return false
	end
	if not Objects.approach(loc, transport.option) then
		return false
	end
	local started = time()
	while time() - started < PlaneWalker.PLANE_TIMEOUT_MS do
		if Player.plane() == transport.to.plane then
			return true
		end
		sleep(100)
	end
	Log.log("PlaneWalker", `still on plane {Player.plane()} after using {transport.name}`)
	return false
end

-- Walks to a tile, on another plane or past doors: to the closest transport that leads there, uses it, and plans again from where it
-- lands, as often as it takes. Walks on the plane we are on are `Walker.walk`s.
function PlaneWalker.walk(to: Tile, plane: number, options: Walker.WalkOptions?): boolean
	local opts: Walker.WalkOptions = table.clone(options or {})
	opts.plane = nil
	opts.doors = false
	local deadline = time() + (opts.timeout_ms or 60000) * 4
	local failures = 0
	while time() < deadline do
		local me = Walker.position()
		local here = Player.plane()
		if me == nil or here == nil then
			return false
		end
		local from = { x = me.x, y = me.y, plane = here }
		local goal = { x = to.x, y = to.y, plane = plane }
		if PlaneWalker.DISCOVER then
			Transports.discover_around(from, goal)
		end
		local plan = Transports.plan(from, goal)
		if plan and #plan.transports == 0 and here == plane then
			-- nothing left in the way: the rest is a walk (doors are ignored here, they were planned for)
			return Walker.walk(to, opts)
		end
		if plan == nil or #plan.transports == 0 then
			Log.log("PlaneWalker", `no way from plane {here} to plane {plane}`)
			return false
		end
		local transport = plan.transports[1]
		local leg: Walker.WalkOptions = table.clone(opts)
		leg.near = if transport.door then 0 else PlaneWalker.NEAR
		local stand = plan.stands[1]
		local at = { x = stand.x, y = stand.y }
		if Walker.walk(at, leg) and PlaneWalker.use(transport, stand) then
			failures = 0
		else
			failures += 1
			if failures >= PlaneWalker.MAX_FAILURES then
				Log.log("PlaneWalker", `couldn't use {transport.name} at {at.x}, {at.y}`)
				return false
			end
		end
	end
	Log.log("PlaneWalker", `didn't reach {to.x}, {to.y} on plane {plane} in time`)
	return false
end

return PlaneWalker
