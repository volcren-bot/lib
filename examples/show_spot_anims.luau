--!strict
-- Prints each spot animation once as it appears and marks its tile on screen, for 30 seconds.
local SECONDS = 30

local Draw = require("../utils/draw")
local Host = require("../host")
local Projection = require("../main/projection/projection")
local SpotAnims = require("../main/entities/spot_anims")

local seen: { [string]: boolean } = {}
local start = Host.time()
while Host.time() - start < SECONDS * 1000 do
	Draw.clear()
	for _, s in ipairs(SpotAnims.find() or {}) do
		local key = `{s.id}:{s.start_cycle}:{s.x}:{s.y}`
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
	Host.sleep(20)
end
Draw.clear()
