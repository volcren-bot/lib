--!strict
local Host = require("@lib/host")
local Objects = require("@lib/main/entities/objects")
local Player = require("@lib/main/player")

local Ferox = {}

Ferox.BOUNDS = { x1 = 3123, y1 = 3618, x2 = 3155, y2 = 3639 }
Ferox.POOL = "Pool of Refreshment"
Ferox.POOL_OPTION = "Drink"
Ferox.RESTORE_TIMEOUT_MS = 10000

function Ferox.contains(x: number, y: number): boolean
	local b = Ferox.BOUNDS
	return x >= b.x1 and x <= b.x2 and y >= b.y1 and y <= b.y2
end

function Ferox.inside(): boolean
	local p = Host.game_state().position
	return p ~= nil and Ferox.contains(p.x, p.y)
end

function Ferox.restore(): (boolean, string?)
	local here = Player.position()
	local pool = if here and Ferox.inside() then Objects.nearest(Ferox.POOL, here) else nil
	if pool == nil then
		return false, if Ferox.inside() then "the pool isn't in sight" else "not in the Ferox Enclave"
	end
	return Player.restore_with(function(): boolean
		return Objects.approach(pool, Ferox.POOL_OPTION)
	end, Ferox.RESTORE_TIMEOUT_MS)
end

return Ferox
