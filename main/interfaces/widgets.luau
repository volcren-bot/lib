--!strict
local Host = require("../../host")
local widget = Host.widget
type Widget = Host.Widget
type Area = Host.Area
local Mouse = require("../../utils/input/mouse")
type Button = Mouse.Button
local Widgets = {}

Widgets.LAYER = 0
Widgets.RECTANGLE = 3
Widgets.TEXT = 4
Widgets.SPRITE = 5
Widgets.MODEL = 6

Widgets.CHECKBOX_SPRITE = 1215
local CHECKBOX_STATES = { "unticked", "crossed", "ticked" }

function Widgets.get(group: number, child: number): Widget?
	return widget(group, child)
end

function Widgets.is_open(group: number, child: number): boolean
	local w = widget(group, child)
	return w ~= nil
end

function Widgets.center(w: Area): (number, number)
	return w.x + w.width // 2, w.y + w.height // 2
end

function Widgets.contains(w: Area, x: number, y: number): boolean
	return x >= w.x and y >= w.y and x < w.x + w.width and y < w.y + w.height
end

function Widgets.click(group: number, child: number, button: Button?): boolean
	local w = widget(group, child)
	if w == nil then
		return false
	end
	Mouse.click(w, button)
	return true
end

-- Queues the click and returns at once; false if the widget isn't there.
function Widgets.click_async(group: number, child: number, button: Button?): boolean
	local w = widget(group, child)
	if w == nil then
		return false
	end
	return Mouse.click_async(w, button)
end

function Widgets.checkbox(w: Widget): string?
	if w.sprite == -1 then
		return nil
	end
	local frame = w.sprite - Widgets.CHECKBOX_SPRITE
	if frame < 0 or frame > 5 then
		return nil
	end
	return CHECKBOX_STATES[frame % 3 + 1]
end

return Widgets
