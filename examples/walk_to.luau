--!strict
-- Walks from wherever you are to a chosen place: one of the destinations below, or a tile you type in. The walker takes the best
-- transport toward it first (a teleport, a ship, a lever pull where one saves time), then plans the rest on foot through doors, stairs,
-- ladders, caves and agility shortcuts. Needs a logged-in client, and the loader for the transport data (a bare `injector run` only walks).
local Host = require("@lib/host")
local Log = require("@lib/utils/log")
local Player = require("@lib/main/player")
local Walker = require("@lib/main/walker")

-- The underground is the same map as the surface, 6,400 tiles north, on plane 0.
local DESTINATIONS: { [string]: { x: number, y: number, plane: number, near: number } } = {
	["Edgeville bank"] = { x = 3097, y = 3496, plane = 0, near = 3 },
	["Barbarian Assault lobby"] = { x = 2531, y = 3577, plane = 0, near = 2 },
	["Varrock sewers, by the pipe"] = { x = 3146, y = 9906, plane = 0, near = 1 },
	["Lumbridge castle, top floor"] = { x = 3209, y = 3220, plane = 2, near = 1 },
}
local names: { string } = {}
for name in pairs(DESTINATIONS) do
	table.insert(names, name)
end
table.sort(names)
table.insert(names, "Custom tile")

local me = assert(Player.position(), "not logged in")
local values = Host.form({
	title = "Walk to",
	submit = "Walk",
	fields = {
		{ id = "where", kind = "choice", label = "Destination", options = names },
		{ kind = "label", text = "Custom tile:" },
		{ id = "x", kind = "number", label = "x", default = me.x, integer = true },
		{ id = "y", kind = "number", label = "y", default = me.y, integer = true },
		{ id = "plane", kind = "number", label = "plane", default = me.plane, integer = true, min = 0, max = 3 },
		{ id = "near", kind = "number", label = "near (tiles)", default = 1, integer = true, min = 0, max = 10 },
		{ id = "transports", kind = "check", label = "Use transports (may spend runes or coins)", default = true },
		{ id = "shortcuts", kind = "check", label = "Use agility shortcuts", default = true },
		{ id = "debug", kind = "check", label = "Log every step of the walk", default = false },
	},
})
if values == nil then
	print("form cancelled")
	return
end
local goal = DESTINATIONS[values.where :: string]
	or { x = values.x :: number, y = values.y :: number, plane = values.plane :: number, near = values.near :: number }
Walker.DEBUG = values.debug == true

Log.log("Example", `walking from {me.x}, {me.y} (plane {me.plane}) to {goal.x}, {goal.y} (plane {goal.plane})`)
local began = Host.time()
local reached = Walker.walk({ x = goal.x, y = goal.y }, {
	plane = goal.plane,
	near = goal.near,
	transports = values.transports == true,
	shortcuts = values.shortcuts == true,
})
local now = Player.position()
local seconds = math.floor((Host.time() - began) / 1000)
if reached then
	Log.log("Example", `arrived at {now and now.x}, {now and now.y} after {seconds} s`)
else
	Log.log(
		"Example",
		`didn't get there: stopped at {now and now.x}, {now and now.y} (plane {now and now.plane}) after {seconds} s`
	)
end
