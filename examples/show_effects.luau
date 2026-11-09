--!strict
local SECONDS = 30

local Draw = require("@lib/utils/draw")
local Host = require("@lib/host")
local Projectiles = require("@lib/main/entities/projectiles")
local Projection = require("@lib/main/projection/projection")
local SpotAnims = require("@lib/main/entities/spot_anims")

local seen: { [string]: boolean } = {}
local start = Host.time()
while Host.time() - start < SECONDS * 1000 do
	Draw.batch(function()
		Draw.clear()
		for _, p in ipairs(Projectiles.find() or {}) do
			local key = `projectile {p.id}:{p.start_cycle}:{p.source_x}:{p.source_y}:{p.target_npc}:{p.target_player}`
			if not seen[key] then
				seen[key] = true
				local at = if p.target_npc >= 0
					then `NPC {p.target_npc}`
					elseif p.target_player >= 0 then `player {p.target_player}`
					else `({p.target_x}, {p.target_y})`
				print(`graphic {p.id} from ({p.source_x}, {p.source_y}) at {at}, flies {Projectiles.flight_ms(p)} ms`)
			end
			local screen = if p.moving then Projectiles.screen(p) else nil
			if screen then
				Draw.rect(screen.x - 5, screen.y - 5, screen.x + 5, screen.y + 5, Draw.color(255, 0, 0))
			end
		end
		for _, s in ipairs(SpotAnims.find() or {}) do
			local key = `spot anim {s.id}:{s.start_cycle}:{s.x}:{s.y}`
			if not seen[key] then
				seen[key] = true
				print(`spot anim {s.id} at ({s.x}, {s.y}) plane {s.plane}, starts in {SpotAnims.starts_in_ms(s)} ms`)
			end
			local points = Projection.points({ { x = s.local_x, y = s.local_y, z = 0 } })
			local screen = if points then points[1] else nil
			if screen then
				Draw.rect(screen.x - 5, screen.y - 5, screen.x + 5, screen.y + 5, Draw.color(255, 0, 255))
			end
		end
	end)
	Host.sleep(20)
end
Draw.clear()
