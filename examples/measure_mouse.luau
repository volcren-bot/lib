--!strict
local Host = require("../host")
local connection = Host.connection
local sleep = Host.sleep
local conn = connection()
print(string.format("canvas: %dx%d", conn.width, conn.height))

while true do
	local c = connection()
	print(string.format("mouse: %d, %d", c.mouse_x, c.mouse_y))
	sleep(1000)
end
