--!strict
local Host = require("../../host")
local menu = Host.menu
local menu_click = Host.menu_click
local menu_open = Host.menu_open
local sleep = Host.sleep
local menu_layout = Host.menu_layout
local game_state = Host.game_state
local connection = Host.connection
type MenuEntry = Host.MenuEntry
type MenuClick = Host.MenuClick
local Geometry = require("../../utils/math/geometry")
local Log = require("../../utils/log")
local Mouse = require("../../utils/input/mouse")
local Random = require("../../utils/math/random")

local Minimenu = {}

export type Target = string | (MenuEntry) -> boolean

Minimenu.MARGIN = 40

function Minimenu.entries(): { MenuEntry }?
	return menu()
end

function Minimenu.text(entry: MenuEntry): string
	return if entry.target ~= "" then `{entry.option} {entry.target}` else entry.option
end

function Minimenu.uptext(): string?
	local entries = menu()
	if entries == nil then
		return nil
	end
	return if entries[1] then Minimenu.text(entries[1]) else ""
end

function Minimenu.matches(entry: MenuEntry, option: string, target: Target?): boolean
	if string.lower(entry.option) ~= string.lower(option) then
		return false
	end
	if type(target) == "function" then
		return target(entry)
	end
	return target == nil or string.find(string.lower(entry.target), string.lower(target), 1, true) ~= nil
end

function Minimenu.find(option: string, target: Target?): (number?, { MenuEntry }?)
	local entries = menu()
	if entries == nil then
		return nil, nil
	end
	for i, entry in ipairs(entries) do
		if Minimenu.matches(entry, option, target) then
			return i, entries
		end
	end
	return nil, nil
end

function Minimenu.has(option: string, target: Target?): boolean
	local i, entries = Minimenu.find(option, target)
	if entries == nil then
		return false
	end
	return i ~= nil
end

-- A menu level as the client lays it out: the menu itself or one of its open submenus.
type Level = {
	x: number,
	y: number,
	width: number,
	height: number,
	rows: Host.MenuRect,
	row_height: number,
	scroll: number,
	margin: number,
}

-- The open menu as the client lays it out and the UI scale from interface units to client pixels.
local function layout(): (Host.MenuLayout?, number?)
	local menu = menu_layout()
	if menu == nil then
		return nil, nil
	end
	local state = game_state()
	return menu, state.ui_scale or 1
end

-- Level `level` of the open menu: 0 is the menu, 1 its submenu, and so on.
local function level_layout(level: number?): (Level?, number?)
	local menu, scale = layout()
	if menu == nil or scale == nil then
		return nil, nil
	end
	local n = level or 0
	if n == 0 then
		return menu :: any, scale
	end
	local sub = menu.submenus[n]
	if sub == nil then
		return nil, nil
	end
	return sub :: any, scale
end

-- Where to click on line `index` of the menu (or submenu `level`), kept near the mouse.
function Minimenu.row(index: number, level: number?): Geometry.Box?
	local menu, scale = level_layout(level)
	if menu == nil or scale == nil then
		return nil
	end
	local rows = menu.rows
	local top = rows.y + menu.row_height * (index - 1) - menu.scroll
	if top < rows.y or top + menu.row_height > rows.y + rows.height then
		return nil
	end
	local half = 12
	local mouse = Mouse.position()
	local x = math.clamp(
		if mouse then mouse.x / scale else rows.x + rows.width / 2,
		rows.x + half,
		rows.x + rows.width - half
	)
	return Geometry.Box.new(
		(x - half) * scale,
		(top + 3) * scale,
		(x + half) * scale,
		(top + menu.row_height - 3) * scale
	)
end

function Minimenu.select(option: string, target: Target?): boolean
	local at = Mouse.position()
	if at == nil then
		return false
	end
	local index, entries = Minimenu.find(option, target)
	if entries == nil then
		return false
	end
	if index == nil then
		return false
	end
	Mouse.click(at, "right")
	Random.sleep(80, 200)
	index, entries = Minimenu.find(option, target)
	if entries == nil then
		return false
	end
	local choice = index or #entries
	local row = Minimenu.row(choice)
	if row == nil then
		return false
	end
	Mouse.click(row)
	if index == nil then
		return false
	end
	return true
end

function Minimenu.clicked(): MenuClick?
	return menu_click()
end

local function is_new(now: MenuClick, before: MenuClick?): boolean
	if before == nil then
		return true
	end
	return now.age < before.age
		or now.x ~= before.x
		or now.y ~= before.y
		or now.entry.option ~= before.entry.option
		or now.entry.raw_target ~= before.entry.raw_target
end

Minimenu.CLICK_TIMEOUT = 600

function Minimenu.wait_click(before: MenuClick?, timeout_ms: number?): MenuClick?
	local timeout = timeout_ms or Minimenu.CLICK_TIMEOUT
	local waited = 0
	while true do
		local now = menu_click()
		if now == nil then
			return nil
		end
		if is_new(now, before) then
			return now
		end
		if waited >= timeout then
			return nil
		end
		sleep(25)
		waited += 25
	end
end

function Minimenu.is_open(): boolean
	return menu_open()
end

local function wait_open(want: boolean, timeout_ms: number): boolean
	local waited = 0
	while true do
		local open = menu_open()
		if open == nil then
			return false
		end
		if open == want then
			return true
		end
		if waited >= timeout_ms then
			return false
		end
		sleep(25)
		waited += 25
	end
end

function Minimenu.open(timeout_ms: number?): boolean
	local open = menu_open()
	if open == nil then
		return false
	end
	if open then
		return true
	end
	Mouse.click(nil, "right")
	return wait_open(true, timeout_ms or 600)
end

-- The area the menu (or submenu `level`) covers, grown by `margin` client pixels at UI scale 1.
function Minimenu.bounds(margin: number?, level: number?): (Geometry.Box?, Host.Connection?)
	local menu, scale = level_layout(level)
	local conn = connection()
	if menu == nil or scale == nil then
		return nil, nil
	end
	local grow = (margin or 0) * scale
	return Geometry.Box.new(
		menu.x * scale - grow,
		menu.y * scale - grow,
		(menu.x + menu.width) * scale + grow,
		(menu.y + menu.height) * scale + grow
	),
		conn
end

-- The area around the menu (or submenu `level`) the mouse can move in without closing it; any open level keeps it open.
function Minimenu.hover_bounds(level: number?): Geometry.Box?
	local menu, scale = level_layout(level)
	if menu == nil or scale == nil then
		return nil
	end
	local grow = menu.margin + 0.5
	return Geometry.Box.new(
		(menu.x - grow) * scale,
		(menu.y - grow) * scale,
		(menu.x + menu.width + grow) * scale,
		(menu.y + menu.height + grow) * scale
	)
end

-- Whether an open menu or submenu covers or sits close enough to `area` to keep the mouse from moving freely.
function Minimenu.overlaps(area: Geometry.Box): boolean
	if not menu_open() then
		return false
	end
	local level = 0
	while true do
		local box = Minimenu.hover_bounds(level)
		if box == nil then
			return false
		end
		if area.x1 <= box.x2 and area.x2 >= box.x1 and area.y1 <= box.y2 and area.y2 >= box.y1 then
			return true
		end
		level += 1
	end
end

function Minimenu.close(timeout_ms: number?): boolean
	local menu, scale = layout()
	if menu == nil or scale == nil then
		local open = menu_open()
		if open == false then
			return true
		end
		return false
	end
	local conn = connection()

	-- away from the menu and every open submenu
	local keep_out: { Geometry.Box } = {}
	local grow = Minimenu.MARGIN
	for _, level in { menu :: any, table.unpack(menu.submenus :: { any }) } do
		table.insert(
			keep_out,
			Geometry.Box.new(
				(level.x - grow) * scale,
				(level.y - grow) * scale,
				(level.x + level.width + grow) * scale,
				(level.y + level.height + grow) * scale
			)
		)
	end
	local function near(p: Geometry.Point): boolean
		for _, box in keep_out do
			if Geometry.Box.contains(box, p) then
				return true
			end
		end
		return false
	end

	local away: Geometry.Point
	local tries = 0
	repeat
		tries += 1
		if tries > 100 then
			return false
		end
		away = Geometry.Point.new(Random.int(10, conn.width - 10), Random.int(10, conn.height - 10))
	until not near(away)
	Mouse.move(away)
	return wait_open(false, timeout_ms or 600)
end

-- Submenus open when the mouse rests on a row with `entry.submenu`; level 1 opens from the menu, 2 from that.

Minimenu.SUBMENU_TIMEOUT = 600

-- The open submenu `level` levels deep, the deepest open one by default.
function Minimenu.submenu(level: number?): Host.MenuSubmenu?
	local menu = layout()
	if menu == nil then
		return nil
	end
	local sub = menu.submenus[level or #menu.submenus]
	if sub == nil then
		return nil
	end
	return sub
end

-- Whether the open menu has a submenu row (matching `option` and `target` when given).
function Minimenu.has_submenu(option: string?, target: Target?): boolean
	local open = menu_open()
	if open == nil then
		return false
	end
	if not open then
		return false
	end
	local entries = menu()
	if entries == nil then
		return false
	end
	for _, entry in entries do
		if entry.submenu and (option == nil or Minimenu.matches(entry, option, target)) then
			return true
		end
	end
	return false
end

function Minimenu.is_submenu_open(level: number?): boolean
	local open = menu_open()
	if open == nil then
		return false
	end
	if not open then
		return false
	end
	local menu = layout()
	if menu == nil then
		return false
	end
	return #menu.submenus >= (level or 1)
end

-- Moves without deliberate misses, which could close the menu or open another row's submenu.
local function move_steady(target: Geometry.Box)
	local miss = Mouse.miss_chance
	Mouse.miss_chance = 0
	local ok, err = pcall(Mouse.move, target, true, nil)
	Mouse.miss_chance = miss
	if not ok then
		error(err, 0)
	end
end

-- Waits for the submenu one level deeper to be the one the row `index` of level `level` opens.
local function wait_submenu(level: number, index: number, timeout_ms: number): boolean
	local waited = 0
	while true do
		local menu = layout()
		if menu == nil then
			return false
		end
		local sub = menu.submenus[level + 1]
		if sub and sub.row == index then
			return true
		end
		if waited >= timeout_ms then
			Log.log("Minimenu", "the submenu didn't open")
			return false
		end
		sleep(25)
		waited += 25
	end
end

-- Opens the submenu of the first row with one (or matching `option` and `target`), right clicking first if closed.
function Minimenu.open_submenu(option: string?, target: Target?, timeout_ms: number?): boolean
	local open = Minimenu.open()
	if open == nil then
		return false
	end
	if not open then
		Log.log("Minimenu", "the menu didn't open")
		return false
	end
	local entries = menu()
	if entries == nil then
		return false
	end
	local index: number? = nil
	for i, entry in entries do
		if entry.submenu and (option == nil or Minimenu.matches(entry, option, target)) then
			index = i
			break
		end
	end
	if index == nil then
		return false
	end
	local menu = layout()
	if menu == nil then
		return false
	end
	if menu.submenus[1] and menu.submenus[1].row == index then
		return true
	end
	local row = Minimenu.row(index)
	if row == nil then
		return false
	end
	move_steady(row)
	return wait_submenu(0, index, timeout_ms or Minimenu.SUBMENU_TIMEOUT)
end

-- The entries of the open submenu, opening it first when none is (see `open_submenu`).
function Minimenu.submenu_entries(option: string?, target: Target?): { MenuEntry }?
	local open = Minimenu.is_submenu_open()
	if not open then
		local opened = Minimenu.open_submenu(option, target)
		if not opened then
			return nil
		end
	end
	local sub = Minimenu.submenu()
	if sub == nil then
		return nil
	end
	return sub.entries
end

-- The line of the open submenu (the deepest one) matching `option` and `target`.
function Minimenu.find_submenu(option: string, target: Target?): (number?, { MenuEntry }?)
	local sub = Minimenu.submenu()
	if sub == nil then
		return nil, nil
	end
	for i, entry in sub.entries do
		if Minimenu.matches(entry, option, target) then
			return i, sub.entries
		end
	end
	return nil, nil
end

-- Moves onto the matching submenu line, first sideways along the opening row so no other row's submenu opens.
function Minimenu.hover_submenu(option: string, target: Target?): boolean
	local menu, scale = layout()
	if menu == nil or scale == nil then
		return false
	end
	local level = #menu.submenus
	local sub = menu.submenus[level]
	if sub == nil then
		return false
	end
	local index = Minimenu.find_submenu(option, target)
	if index == nil then
		return false
	end
	local mouse = Mouse.position()
	local inside = Geometry.Box.new(
		(sub.x + 4) * scale,
		(sub.y + 4) * scale,
		(sub.x + sub.width - 4) * scale,
		(sub.y + sub.height - 4) * scale
	)
	if mouse and not Geometry.Box.contains(inside, mouse) then
		-- the edge of the submenu next to the menu above it, at the mouse's height
		local parent: Level = if level == 1 then menu :: any else menu.submenus[level - 1] :: any
		local left = sub.x < parent.x
		local x = if left then sub.x + sub.width - 12 else sub.x + 12
		local y = math.clamp(mouse.y / scale, sub.y + 6, sub.y + sub.height - 6)
		move_steady(Geometry.Box.new((x - 4) * scale, (y - 2) * scale, (x + 4) * scale, (y + 2) * scale))
	end
	local row = Minimenu.row(index, level)
	if row == nil then
		return false
	end
	move_steady(row)
	return true
end

-- Clicks the matching line in the submenu opened from the row matching `parent` (any submenu row when nil), opening menus as needed.
function Minimenu.select_submenu(option: string, target: Target?, parent: string?): boolean
	local opened = Minimenu.open_submenu(parent)
	if not opened then
		return opened
	end
	local hovered = Minimenu.hover_submenu(option, target)
	if not hovered then
		return hovered
	end
	Mouse.click()
	return true
end

return Minimenu
