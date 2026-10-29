--!strict
-- Loops forever, drawing the bounds of the open minimenu and its submenus plus the hover and keep-out areas.
local Draw = require("../utils/draw")
local Host = require("../host")
local Minimenu = require("../main/interfaces/minimenu")
local sleep = Host.sleep

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
		-- every level's boxes in one overlay update
		Draw.batch(function()
			Draw.clear()
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
		end)
		drawn = true
	elseif drawn then
		Draw.clear()
		drawn = false
	end
	sleep(50)
end
