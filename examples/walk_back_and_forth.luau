--!strict
-- Walks back and forth between two tiles on any planes, through the doors, ladders and staircases on the way.
local Host = require("../host")
local form = Host.form
local time = Host.time
local Random = require("../utils/math/random")
local Walker = require("../main/walker")

local values = assert(form({
	title = "Walk back and forth",
	fields = {
		{ kind = "label", text = "First point" },
		{ id = "ax", kind = "number", label = "x", default = 1612, integer = true },
		{ id = "ay", kind = "number", label = "y", default = 3681, integer = true },
		{ id = "aplane", kind = "number", label = "plane", default = 2, integer = true, min = 0, max = 3 },
		{ kind = "label", text = "Second point" },
		{ id = "bx", kind = "number", label = "x", default = 1600, integer = true },
		{ id = "by", kind = "number", label = "y", default = 3660, integer = true },
		{ id = "bplane", kind = "number", label = "plane", default = 0, integer = true, min = 0, max = 3 },
		{ id = "near", kind = "number", label = "near (tiles)", default = 0, integer = true, min = 0, max = 10 },
		{
			id = "laps",
			kind = "number",
			label = "laps (there and back)",
			default = 3,
			integer = true,
			min = 1,
			max = 100,
		},
		{ id = "debug", kind = "check", label = "log every step of the walk", default = false },
	},
}))

Walker.DEBUG = values.debug == true
local points = {
	{ x = values.ax :: number, y = values.ay :: number, plane = values.aplane :: number },
	{ x = values.bx :: number, y = values.by :: number, plane = values.bplane :: number },
}
local near = values.near :: number

-- start with the point farther from where you are
local me = assert(Walker.here())
local function away(p: Host.NavTile): number
	return Walker.distance(me, p) + if p.plane ~= me.plane then 1000 else 0
end
local next_point = if away(points[1]) >= away(points[2]) then 1 else 2

local legs, failed = 0, 0
local started = time()
for lap = 1, values.laps :: number do
	for _ = 1, 2 do
		local to = points[next_point]
		local began = time()
		local ok = Walker.walk({ x = to.x, y = to.y }, { plane = to.plane, near = near })
		local now = Walker.here()
		legs += 1
		if not ok then
			failed += 1
		end
		print(
			`lap {lap}: {if ok then "reached" else "didn't reach"} {to.x}, {to.y} (plane {to.plane}) in {math.floor(
				(time() - began) / 100
			) / 10} s, now at {now and now.x}, {now and now.y} (plane {now and now.plane})`
		)
		next_point = 3 - next_point
		Random.sleep(400, 1500)
	end
end
print(`{legs - failed} of {legs} walks reached their point in {math.floor((time() - started) / 1000)} s`)
