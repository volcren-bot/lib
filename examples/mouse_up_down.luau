--!strict
local Geometry = require("@lib/utils/math/geometry")
local Host = require("@lib/host")
local Mouse = require("@lib/utils/input/mouse")
local Point = Geometry.Point

local conn = assert(Host.connection())
local x = conn.width // 2
local top = Point.new(x, 0)
local bottom = Point.new(x, conn.height - 1)

while true do
	Mouse.move(top)
	Mouse.move(bottom)
end
