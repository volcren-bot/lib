--!strict
local Host = require("@lib/host")
local sleep = Host.sleep
local widget_children = Host.widget_children
type Widget = Host.Widget
type Loc = Host.Loc
local Chat = require("@lib/main/interfaces/chatbox/chat")
local Mouse = require("@lib/utils/input/mouse")
local Objects = require("@lib/main/entities/objects")
local Player = require("@lib/main/player")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Walker = require("@lib/main/walker")
local Widgets = require("@lib/main/interfaces/widgets")

local Obelisk = {}

Obelisk.GROUP = 187
Obelisk.LIST = 3
Obelisk.CLOSE = 4
Obelisk.OBJECT = "Obelisk"
Obelisk.SET = "Set Destination"
Obelisk.TELEPORT = "Teleport to Destination"
Obelisk.RANGE = 8
Obelisk.OPEN_TIMEOUT_MS = 5000
Obelisk.CLOSE_TIMEOUT_MS = 3000
Obelisk.POLL_MS = 50
Obelisk.SETTLE_MS = { 250, 500 }
Obelisk.GRID_TIMEOUT_MS = 4000

export type Level =
	"Level 13 Wilderness"
	| "Level 19 Wilderness"
	| "Level 27 Wilderness"
	| "Level 35 Wilderness"
	| "Level 44 Wilderness"
	| "Level 50 Wilderness"

Obelisk.Level = table.freeze({
	Level13 = "Level 13 Wilderness",
	Level19 = "Level 19 Wilderness",
	Level27 = "Level 27 Wilderness",
	Level35 = "Level 35 Wilderness",
	Level44 = "Level 44 Wilderness",
	Level50 = "Level 50 Wilderness",
}) :: {
	Level13: "Level 13 Wilderness",
	Level19: "Level 19 Wilderness",
	Level27: "Level 27 Wilderness",
	Level35: "Level 35 Wilderness",
	Level44: "Level 44 Wilderness",
	Level50: "Level 50 Wilderness",
}

export type Destination = {
	name: string,
	row: Widget,
}

function Obelisk.stones(): { Loc }
	local here = Player.position()
	local found: { Loc } = {}
	if here == nil then
		return found
	end
	for _, loc in ipairs(Objects.find(Obelisk.OBJECT) or {}) do
		if Objects.distance(loc, here) <= Obelisk.RANGE then
			table.insert(found, loc)
		end
	end
	table.sort(found, function(a: Loc, b: Loc)
		return Objects.distance(a, here) < Objects.distance(b, here)
	end)
	return found
end

function Obelisk.is_open(): boolean
	return Toplevel.is_open(Obelisk.GROUP)
end

function Obelisk.open(): boolean
	if Obelisk.is_open() then
		return true
	end
	local stone = Obelisk.stones()[1]
	if stone == nil or not Objects.interact(stone, Obelisk.SET) then
		return false
	end
	if not Widgets.wait_for(Obelisk.is_open, Obelisk.OPEN_TIMEOUT_MS, Obelisk.POLL_MS) then
		return false
	end
	sleep(Random.int(Obelisk.SETTLE_MS[1], Obelisk.SETTLE_MS[2]))
	return true
end

function Obelisk.destinations(): { Destination }?
	if not Obelisk.is_open() then
		return nil
	end
	local found: { Destination } = {}
	for _, row in ipairs(widget_children(Obelisk.GROUP, Obelisk.LIST) or {}) do
		if row.kind == 4 and not row.hidden and row.text ~= nil then
			local name = string.match(Chat.clean(row.text), "^%w+:%s*(.+)$")
			if name ~= nil then
				table.insert(found, { name = name, row = row })
			end
		end
	end
	return found
end

function Obelisk.select(level: Level): boolean
	for _, d in ipairs(Obelisk.destinations() or {}) do
		if string.lower(d.name) == string.lower(level) then
			Mouse.click(d.row)
			return Widgets.wait_for(function()
				return not Obelisk.is_open()
			end, Obelisk.CLOSE_TIMEOUT_MS, Obelisk.POLL_MS)
		end
	end
	return false
end

function Obelisk.close(): boolean
	return Toplevel.close(Obelisk.GROUP, function(): Widget?
		return Host.widget(Obelisk.GROUP, Obelisk.CLOSE)
	end)
end

function Obelisk.on_grid(): boolean
	local here = Player.position()
	local stones = Obelisk.stones()
	if here == nil or #stones < 4 then
		return false
	end
	local x1, x2, y1, y2 = math.huge, -math.huge, math.huge, -math.huge
	for _, stone in ipairs(stones) do
		x1, x2 = math.min(x1, stone.x), math.max(x2, stone.x)
		y1, y2 = math.min(y1, stone.y), math.max(y2, stone.y)
	end
	return here.x > x1 and here.x < x2 and here.y > y1 and here.y < y2
end

function Obelisk.teleport(): boolean
	local stones = Obelisk.stones()
	if #stones < 4 or not Objects.interact(stones[1], Obelisk.TELEPORT) then
		return false
	end
	if Obelisk.on_grid() then
		return true
	end
	local x, y = 0, 0
	for _, stone in ipairs(stones) do
		x += stone.x
		y += stone.y
	end
	Walker.walk_tile({ x = x // #stones, y = y // #stones }, Obelisk.GRID_TIMEOUT_MS)
	return Obelisk.on_grid()
end

return Obelisk
