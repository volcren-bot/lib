--!strict
-- Walks from wherever you are to the Edgeville bank. The walker takes the best transport toward it first (a teleport, a ship or a lever pull where one saves time)
-- and then plans the rest on foot, opening doors on the way. Needs a logged-in client, and the loader for the transport data (a bare `injector run` has none and only walks).
local Host = require("@lib/host")
local Log = require("@lib/utils/log")
local Player = require("@lib/main/player")
local Walker = require("@lib/main/walker")

local BANK = { x = 3097, y = 3496, plane = 0 }

local start = Player.position()
assert(start, "not logged in")
Log.log("Example", `walking from {start.x}, {start.y} (plane {start.plane}) to the Edgeville bank`)

local began = Host.time()
local reached = Walker.walk(BANK, { plane = BANK.plane, near = 3 })

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
