--!strict
-- Walks to a tile on another plane through the ladders and staircases added to `Transports`.
local Host = require("../host")
local form = Host.form
local Player = require("../main/player")
local Transports = require("../main/transports")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local plane = assert(Player.plane())

-- Add the ladders and staircases the walk may use; each is the tile in front of it and where it takes you.
Transports.add_two_way(
	"Staircase",
	{ x = me.x, y = me.y, plane = plane },
	{ x = me.x, y = me.y + 3, plane = plane + 1 },
	"Climb-up",
	"Climb-down"
)

local values = assert(form({
	title = "Walk to another plane",
	fields = {
		{ id = "x", kind = "number", label = "x", default = me.x, integer = true },
		{ id = "y", kind = "number", label = "y", default = me.y + 3, integer = true },
		{ id = "plane", kind = "number", label = "plane", default = plane + 1, integer = true },
	},
}))
local target = { x = values.x :: number, y = values.y :: number }
print(Walker.walk(target, { plane = values.plane :: number }))
