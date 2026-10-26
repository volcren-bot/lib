--!strict
-- Loops forever, drawing the bounds of the open minimenu and its submenus plus the hover and keep-out areas.
local Host = require("../host")
local Draw = require("../utils/draw")
local Minimenu = require("../main/interfaces/minimenu")
local sleep = Host.sleep
local clear_overlay = Host.clear_overlay

type Palette = { menu: Draw.Color, hover: Draw.Color, keep_out: Draw.Color }

local palettes: { Palette } = {
	{ menu = Draw.GREEN, hover = Draw.YELLOW, keep_out = Draw.RED },
	{ menu = Draw.CYAN, hover = Draw.MAGENTA, keep_out = Draw.BLUE },
}

local function draw(box: { x1: number, y1: number, x2: number, y2: number }, color: Draw.Color)
	Draw.rect(box.x1, box.y1, box.x2, box.y2, color)
end

local drawn = false
while true do
	local open = Minimenu.is_open()
	if open then
		clear_overlay()
		local level = 0
		while true do
			local menu = Minimenu.bounds(0, level)
			local hover = Minimenu.hover_bounds(level)
			local keep_out = Minimenu.bounds(Minimenu.MARGIN, level)
			if not (menu and hover and keep_out) then
				break
			end
			local palette = palettes[(level % #palettes) + 1]
			draw(keep_out, palette.keep_out)
			draw(hover, palette.hover)
			draw(menu, palette.menu)
			level += 1
		end
		drawn = true
	elseif drawn then
		clear_overlay()
		drawn = false
	end
	sleep(50)
end
