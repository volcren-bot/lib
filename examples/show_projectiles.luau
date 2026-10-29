--!strict
-- Prints each projectile once as it appears and marks the ones in flight on screen, for 30 seconds.
local SECONDS = 30

local Draw = require("../utils/draw")
local Host = require("../host")
local Projectiles = require("../main/entities/projectiles")

local seen: { [string]: boolean } = {}
local start = Host.time()
while Host.time() - start < SECONDS * 1000 do
	-- every mark of this pass in one overlay update
	Draw.batch(function()
		Draw.clear()
		for _, p in ipairs(Projectiles.find() or {}) do
			local key = `{p.id}:{p.start_cycle}:{p.source_x}:{p.source_y}:{p.target_npc}:{p.target_player}`
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
	end)
	Host.sleep(20)
end
Draw.clear()
