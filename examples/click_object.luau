--!strict
local NAME = "Bank chest"
local OPTION = "Use"

local Host = require("../host")
local sleep = Host.sleep
local Draw = require("../utils/draw")
local Clickbox = require("../main/clickbox")
local Objects = require("../main/entities/objects")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local loc = Objects.nearest(NAME, me)
if loc == nil then
	print(`no {NAME} around`)
	return
end
print(`nearest {loc.name} ({loc.id}) at {loc.x}, {loc.y}, {Objects.distance(loc, me)} tiles away`)

-- The client's own clickbox: the loc's triangles, outlined in yellow.
local function highlight()
	local box = Objects.clickbox(loc)
	Draw.clear()
	if box then
		for _, t in ipairs(box.triangles or {}) do
			Draw.polygon(t, Draw.color(255, 255, 0, 90))
		end
		Clickbox.draw(box)
	end
end

highlight()
local ok = Objects.interact(loc, OPTION)
print(if ok then `{OPTION} {loc.name}` else `couldn't {OPTION} {loc.name}`)

for _ = 1, 30 do
	highlight()
	sleep(100)
end
Draw.clear()
