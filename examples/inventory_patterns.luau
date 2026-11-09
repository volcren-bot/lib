--!strict
local Biometrics = require("@lib/main/antiban/biometrics")
local Draw = require("@lib/utils/draw")
local Host = require("@lib/host")
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

local RUN_MS = 180 * 1000
local STEP_MS = 45
local HOLD_MS = 1200
local ACCOUNT_HABIT = false
local ORDERS_PER_HABIT = 3

local SNAKE_COLOR, SPIRAL_COLOR = Draw.color(0, 220, 255), Draw.color(255, 60, 220)

local function shade(step: number, count: number): Draw.Color
	local t = if count > 1 then (step - 1) / (count - 1) else 0
	return Draw.color(math.floor(255 * t), math.floor(255 * (1 - t)), 60)
end

local function centre(box: Host.Widget): { x: number, y: number }
	return { x = box.x + box.width // 2, y = box.y + box.height // 2 }
end

local function paint(
	order: { number },
	modes: { boolean },
	shown: number,
	boxes: { [number]: Host.Widget },
	title: string
)
	Draw.batch(function()
		Draw.clear()
		local first = boxes[0]
		if first then
			Draw.text(title, first.x, first.y - 18, 12, Draw.WHITE)
		end
		for i = 2, shown do
			local a, b = boxes[order[i - 1]], boxes[order[i]]
			if a and b then
				Draw.line(centre(a), centre(b), if modes[i] then SNAKE_COLOR else SPIRAL_COLOR)
			end
		end
		for i = 1, shown do
			local box = boxes[order[i]]
			if box then
				local at = centre(box)
				Draw.text(tostring(i), at.x - 6, at.y - 6, 12, shade(i, #order))
			end
		end
	end)
end

if ACCOUNT_HABIT then
	Biometrics.setup_player()
end

local started = Host.time()
local habit, in_habit = 1, 0
local said_closed = false
while Host.time() - started < RUN_MS do
	local boxes = if Inventory.is_open() then Inventory.boxes() else nil
	if boxes == nil then
		if not said_closed then
			said_closed = true
			print("Open the inventory tab to see the orders")
		end
		Draw.clear()
		Host.sleep(300)
		continue
	end
	said_closed = false
	if not ACCOUNT_HABIT and in_habit == ORDERS_PER_HABIT then
		Biometrics.setup(nil)
		habit, in_habit = habit + 1, 0
	end
	in_habit += 1
	local order, modes = Inventory.pattern()
	local title = if ACCOUNT_HABIT
		then `This account's habit, order {in_habit}: cyan snake, magenta spiral`
		else `Habit {habit}, order {in_habit} of {ORDERS_PER_HABIT}: cyan snake, magenta spiral`
	print(`{title}: {table.concat(order, ",")}`)
	for shown = 1, #order do
		paint(order, modes, shown, boxes, title)
		Host.sleep(STEP_MS)
	end
	Host.sleep(HOLD_MS)
end
Draw.clear()
