--!strict
-- Walks from wherever you are to the Barbarian Assault lobby at the Barbarian Outpost (2531, 3577), where the minigame teleport lands.
-- The walker picks the way: teleport spells and charter ships where one saves time, then stairs, ladders, caves and agility shortcuts on the way.
-- To walk without spending runes, pass `transports = false` in the options; to keep off agility shortcuts, `shortcuts = false`.
local Host = require("@lib/host")
local Log = require("@lib/utils/log")
local Player = require("@lib/main/player")
local Walker = require("@lib/main/walker")

local GOAL = { x = 2531, y = 3577 }

local start = Player.position()
assert(start, "not logged in")
Log.log("Example", `walking from {start.x}, {start.y} (plane {start.plane}) to {GOAL.x}, {GOAL.y}`)

local began = Host.time()
local reached = Walker.walk(GOAL, { plane = 0, near = 2 })

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
