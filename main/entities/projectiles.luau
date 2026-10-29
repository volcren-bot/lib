--!strict
local Host = require("../../host")
local projectiles = Host.projectiles
type Projectile = Host.Projectile
type Npc = Host.Npc
type PlayerInfo = Host.PlayerInfo
type Tile = Host.Tile
local Geometry = require("../../utils/math/geometry")
type Point = Geometry.Point
local Players = require("./players")
local Projection = require("../projection/projection")
local Projectiles = {}

-- the client cycle is 50 a second
Projectiles.CYCLE_MS = 20

local function matches(projectile: Projectile, what: number | { number }): boolean
	if type(what) == "number" then
		return projectile.id == what
	end
	return table.find(what, projectile.id) ~= nil
end

function Projectiles.find(what: (number | { number })?): { Projectile }?
	local all = projectiles()
	if all == nil then
		return nil
	end
	if what == nil then
		return all
	end
	local found: { Projectile } = {}
	for _, projectile in ipairs(all) do
		if matches(projectile, what) then
			table.insert(found, projectile)
		end
	end
	return found
end

function Projectiles.at_npc(npc: Npc, what: (number | { number })?): { Projectile }?
	local found = Projectiles.find(what)
	if found == nil then
		return nil
	end
	local at: { Projectile } = {}
	for _, projectile in ipairs(found) do
		if projectile.target_npc == npc.index then
			table.insert(at, projectile)
		end
	end
	return at
end

function Projectiles.at_player(player: PlayerInfo, what: (number | { number })?): { Projectile }?
	local found = Projectiles.find(what)
	if found == nil then
		return nil
	end
	local at: { Projectile } = {}
	for _, projectile in ipairs(found) do
		if projectile.target_player == player.index then
			table.insert(at, projectile)
		end
	end
	return at
end

function Projectiles.at_me(what: (number | { number })?): { Projectile }?
	local me = Players.me()
	if me == nil then
		return nil
	end
	return Projectiles.at_player(me, what)
end

function Projectiles.from_npc(npc: Npc, what: (number | { number })?): { Projectile }?
	local found = Projectiles.find(what)
	if found == nil then
		return nil
	end
	local from: { Projectile } = {}
	for _, projectile in ipairs(found) do
		if projectile.source_npc == npc.index then
			table.insert(from, projectile)
		end
	end
	return from
end

function Projectiles.remaining_ms(projectile: Projectile): number
	return math.max(0, projectile.end_cycle - projectile.cycle) * Projectiles.CYCLE_MS
end

function Projectiles.departs_in_ms(projectile: Projectile): number
	return math.max(0, projectile.start_cycle - projectile.cycle) * Projectiles.CYCLE_MS
end

function Projectiles.flight_ms(projectile: Projectile): number
	return math.max(0, projectile.end_cycle - projectile.start_cycle) * Projectiles.CYCLE_MS
end

function Projectiles.progress(projectile: Projectile): number
	local total = projectile.end_cycle - projectile.start_cycle
	if total <= 0 then
		return if projectile.cycle >= projectile.end_cycle then 1 else 0
	end
	return math.clamp((projectile.cycle - projectile.start_cycle) / total, 0, 1)
end

function Projectiles.tile(projectile: Projectile): Tile
	return { x = projectile.x, y = projectile.y }
end

function Projectiles.target(projectile: Projectile): Tile
	return { x = projectile.target_x, y = projectile.target_y }
end

function Projectiles.screen(projectile: Projectile): Point?
	local points = Projection.points({ { x = projectile.local_x, y = projectile.local_y, z = -projectile.height } })
	return if points then points[1] else nil
end

function Projectiles.first_landing(what: (number | { number })?): Projectile?
	local found = Projectiles.find(what)
	if found == nil then
		return nil
	end
	local best: Projectile? = nil
	for _, projectile in ipairs(found) do
		if best == nil or projectile.end_cycle < (best :: Projectile).end_cycle then
			best = projectile
		end
	end
	return best
end

return Projectiles
