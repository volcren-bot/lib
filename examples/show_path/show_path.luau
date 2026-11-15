--!strict
local Draw = require("@lib/utils/draw")
local Host = require("@lib/host")
local Minimap = require("@lib/main/interfaces/minimap")
local Projection = require("@lib/main/projection/projection")
local Walker = require("@lib/main/walker")

local me = assert(Walker.position())
local values = Host.settings()
local target = if values.x == 0 and values.y == 0
	then { x = me.x + 10, y = me.y - 10 }
	else { x = values.x :: number, y = values.y :: number }

local path = Walker.path(target)
if path == nil then
	print(`no path to {target.x}, {target.y}`)
	return
end
print(`{#path - 1} steps to {target.x}, {target.y}`)

Draw.batch(function()
	Draw.clear()
	local segments = {}
	local previous = nil
	for _, tile in path do
		local point = Minimap.tile_to_point(tile)
		if point and previous then
			table.insert(segments, { previous, point })
		end
		previous = point
		local quad = Projection.tile(tile)
		if quad and Projection.on_screen(quad) then
			Draw.quad(quad, Draw.YELLOW)
		end
	end
	Draw.lines(segments, Draw.GREEN)
end)
