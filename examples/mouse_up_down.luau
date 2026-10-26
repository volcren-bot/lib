--!strict
local Host = require("../host")
local Mouse = require("../utils/input/mouse")
local Geometry = require("../utils/math/geometry")
local Point = Geometry.Point

local conn = assert(Host.connection())
local x = conn.width // 2
local top = Point.new(x, 0)
local bottom = Point.new(x, conn.height - 1)

while true do
	Mouse.move(top)
	Mouse.move(bottom)
end
