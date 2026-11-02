--!strict
-- Walks from wherever you are to 3146, 9906: the Varrock sewers, a few tiles west of the squeeze-through pipe (3149, 9906).
-- The walker picks the way: teleport spells and charter ships where one saves time, then stairs, ladders and caves down into the sewers.
-- It stops at the tile; the pipe itself (51 Agility) isn't used. To walk without spending runes, pass `transports = false` in the options.
local Host = require("@lib/host")
local Log = require("@lib/utils/log")
local Player = require("@lib/main/player")
local Walker = require("@lib/main/walker")

-- the underground is the same map as the surface, 6,400 tiles north, on plane 0
local GOAL = { x = 3146, y = 9906 }

local start = Player.position()
assert(start, "not logged in")
Log.log("Example", `walking from {start.x}, {start.y} (plane {start.plane}) to {GOAL.x}, {GOAL.y}`)

local began = Host.time()
local reached = Walker.walk(GOAL, { plane = 0, near = 1 })

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
