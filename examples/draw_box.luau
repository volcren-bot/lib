--!strict
local Host = require("../host")
local draw_rect = Host.draw_rect
local clear_overlay = Host.clear_overlay
clear_overlay()
draw_rect(100, 100, 200, 200, 255, 0, 0)
print("drew a red box at (100, 100)-(200, 200)")
