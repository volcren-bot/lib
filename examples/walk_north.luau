--!strict
local Host = require("../host")
local sleep = Host.sleep
local Draw = require("../utils/draw")
local Projection = require("../main/projection/projection")
local Walker = require("../main/walker")

local target = assert(Walker.relative(0, 5))
print(`walking to {target.x}, {target.y}`)

local function highlight()
	local quad = Projection.tile(target)
	Draw.clear()
	if quad then
		Draw.quad(quad, Draw.YELLOW)
	end
end

highlight()
assert(Walker.click_tile(target))

local arrived = false
for _ = 1, 100 do
	highlight()
	local me = assert(Walker.position())
	if me.x == target.x and me.y == target.y then
		arrived = true
		break
	end
	sleep(100)
end
Draw.clear()
print(if arrived then "arrived" else "didn't arrive within 10 s")
