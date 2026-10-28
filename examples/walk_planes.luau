--!strict
-- Walks to a tile on another plane: the ladders, staircases and doors on the way are found in the scene.
local Host = require("../host")
local form = Host.form
local Player = require("../main/player")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local plane = assert(Player.plane())

local values = assert(form({
	title = "Walk to another plane",
	fields = {
		{ id = "x", kind = "number", label = "x", default = me.x, integer = true },
		{ id = "y", kind = "number", label = "y", default = me.y, integer = true },
		{
			id = "plane",
			kind = "number",
			label = "plane",
			default = if plane > 0 then plane - 1 else 1,
			integer = true,
		},
	},
}))
local target = { x = values.x :: number, y = values.y :: number }
print(Walker.walk(target, { plane = values.plane :: number, near = 0 }))
