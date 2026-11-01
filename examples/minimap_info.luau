--!strict
local Host = require("@lib/host")
local sleep = Host.sleep
local Camera = require("@lib/main/camera")
local Minimap = require("@lib/main/interfaces/minimap")

while true do
	local minimap = Minimap.state()
	if minimap then
		print(`zoom: {minimap.zoom}, compass: {Camera.yaw_degrees()}`)
	else
		print("waiting for the minimap")
	end
	sleep(500)
end
