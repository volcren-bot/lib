--!strict
-- Draws the walking path from the player to a tile on the minimap and in view.
local Host = require("../host")
local form = Host.form
local Draw = require("../utils/draw")
local Minimap = require("../main/interfaces/minimap")
local Projection = require("../main/projection/projection")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local values = assert(form({
	title = "Show path",
	fields = {
		{ id = "x", kind = "number", label = "x", default = me.x + 10, integer = true },
		{ id = "y", kind = "number", label = "y", default = me.y - 10, integer = true },
	},
}))
local target = { x = values.x :: number, y = values.y :: number }

local path = Walker.path(target)
if path == nil then
	print(`no path to {target.x}, {target.y}`)
	return
end
print(`{#path - 1} steps to {target.x}, {target.y}`)

-- the whole path in one overlay update
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
