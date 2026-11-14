--!strict
local Host = require("@lib/host")
local Log = require("@lib/utils/log")
local Player = require("@lib/main/player")
local Walker = require("@lib/main/walker")

local DESTINATIONS: { [string]: { x: number, y: number, plane: number, near: number } } = {
	["Edgeville bank"] = { x = 3097, y = 3496, plane = 0, near = 3 },
	["Barbarian Assault lobby"] = { x = 2531, y = 3577, plane = 0, near = 2 },
	["Varrock sewers, by the pipe"] = { x = 3146, y = 9906, plane = 0, near = 1 },
	["Lumbridge castle, top floor"] = { x = 3209, y = 3220, plane = 2, near = 1 },
}
local me = assert(Player.position(), "not logged in")
local values = Host.settings()
local custom = if values.x == 0 and values.y == 0
	then { x = me.x, y = me.y, plane = me.plane, near = values.near :: number }
	else {
		x = values.x :: number,
		y = values.y :: number,
		plane = values.plane :: number,
		near = values.near :: number,
	}
local goal = DESTINATIONS[values.where :: string] or custom
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
