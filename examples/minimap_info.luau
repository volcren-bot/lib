--!strict
local Host = require("../host")
local sleep = Host.sleep
local Camera = require("../main/camera")
local Minimap = require("../main/interfaces/minimap")

while true do
	local minimap = Minimap.state()
	if minimap then
		print(`zoom: {minimap.zoom}, compass: {Camera.yaw_degrees()}`)
	else
		print("waiting for the minimap")
	end
	sleep(500)
end
