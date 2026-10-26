--!strict
local Host = require("../../../host")
local game_state = Host.game_state
local widget = Host.widget
local widget_children = Host.widget_children
local world_select = Host.world_select
local menu = Host.menu
local varp = Host.varp
local sleep = Host.sleep
local time = Host.time
local mouse_down = Host.mouse_down
local mouse_up = Host.mouse_up
type Widget = Host.Widget
local GameState = require("../../game_state")
local SidePanels = require("./side_panels")
local Logout = require("./logout")
local Mouse = require("../../../utils/input/mouse")
local Random = require("../../../utils/math/random")
local Geometry = require("../../../utils/math/geometry")
local Biometrics = require("../../antiban/biometrics")
local RecommendSurvey = require("../chatbox/recommend_survey")
local Log = require("../../../utils/log")
local Box = Geometry.Box
type Box = Geometry.Box

local WorldSwitcher = {
	GROUP = 69,
	TITLE = 3,
	CONFIGURE = 4,
	CLOSE = 5,
	SORT_FAVOURITE = 12,
	SORT_WORLD = 13,
	SORT_PLAYERS = 14,
	SORT_LOCATION = 15,
	SORT_ACTIVITY = 16,
	LIST = 17,
	ROWS = 18,
	CELLS = 19,
	SCROLLBAR = 20,
	LOGOUT = 25,
	SORT_VARP = 477,
	FREE = 0xe0e0e0,
	MEMBERS = 0xf0f000,
	UNAVAILABLE = 0x7f7f7f,
	CONFIRM_GROUP = 193,
	CONFIRM_TEXT = 2,
	CONFIRM_BUTTONS = 0,
}

WorldSwitcher.cooldown_ms = 7000

export type Row = {
	world: number,
	players: number?,
	activity: string?,
	members: boolean,
	available: boolean,
	visible: boolean,
	box: Box,
}

local POLL_MS = 100
local OPEN_TIMEOUT_MS = 1500
local CLOSE_TIMEOUT_MS = 1200
local LOADING_TIMEOUT_MS = 2400
local HOVER_TIMEOUT_MS = 600
local HOP_START_MS = 1800
local HOP_TIMEOUT_MS = 10000
local SORT_TIMEOUT_MS = 1200
local MAX_SCROLLS = 60

local ready_at = 0

local function wait_until(condition: () -> boolean, timeout_ms: number): boolean
	local waited = 0
	while true do
		if condition() then
			return true
		end
		if waited >= timeout_ms then
			return false
		end
		sleep(POLL_MS)
		waited += POLL_MS
	end
end

local function component(child: number): Widget?
	local w = widget(WorldSwitcher.GROUP, child)
	if w == nil then
		return nil
	end
	return w
end

function WorldSwitcher.is_open(): boolean
	return Logout.shows_world_switcher()
end

function WorldSwitcher.current(): number?
	local select = world_select()
	if select ~= nil then
		return select.current
	end
	local title = component(WorldSwitcher.TITLE)
	if title == nil then
		return nil
	end
	local number = title.text and string.match(title.text, "(%d+)")
	return if number then tonumber(number) else nil
end

local function box_of(w: Widget): Box
	return Box.new(w.x, w.y, w.x + w.width - 1, w.y + w.height - 1)
end

function WorldSwitcher.rows(): { Row }?
	local open = WorldSwitcher.is_open()
	if not open then
		return nil
	end
	local list = component(WorldSwitcher.LIST)
	if list == nil then
		return nil
	end
	local rows = widget_children(WorldSwitcher.GROUP, WorldSwitcher.ROWS)
	if rows == nil then
		return nil
	end
	local cells = widget_children(WorldSwitcher.GROUP, WorldSwitcher.CELLS) or {}
	local texts: { [number]: { Widget } } = {}
	for _, cell in cells do
		if not cell.hidden and cell.text ~= nil then
			local line = texts[cell.y]
			if line == nil then
				line = {}
				texts[cell.y] = line
			end
			table.insert(line, cell)
		end
	end

	local result: { Row } = {}
	for _, row in rows do
		if not row.hidden then
			local line: { Widget } = texts[row.y] or {}
			table.sort(line, function(a: Widget, b: Widget)
				return a.x < b.x
			end)
			local number, players, activity = line[1], line[2], line[3]
			local colour = if number then number.text_color else WorldSwitcher.FREE
			table.insert(result, {
				world = row.index,
				players = if players then tonumber(players.text) else nil,
				activity = if activity then activity.text else nil,
				members = colour == WorldSwitcher.MEMBERS,
				available = colour ~= WorldSwitcher.UNAVAILABLE,
				visible = row.y >= list.y and row.y + row.height <= list.y + list.height,
				box = box_of(row),
			})
		end
	end
	table.sort(result, function(a: Row, b: Row)
		return a.box.y1 < b.box.y1
	end)
	return result
end

function WorldSwitcher.worlds(): { Row }?
	local rows = WorldSwitcher.rows()
	if rows == nil then
		return nil
	end
	local shown: { Row } = {}
	for _, row in rows do
		if row.visible then
			table.insert(shown, row)
		end
	end
	return shown
end

function WorldSwitcher.find(world: number): Row?
	local rows = WorldSwitcher.rows()
	if rows == nil then
		return nil
	end
	for _, row in rows do
		if row.world == world then
			return row
		end
	end
	return nil
end

function WorldSwitcher.is_loading(): boolean
	local rows = WorldSwitcher.rows()
	if rows == nil then
		return false
	end
	return #rows == 0
end

function WorldSwitcher.wait_loading(timeout_ms: number?): boolean
	return wait_until(function()
		return WorldSwitcher.is_loading() == false
	end, timeout_ms or LOADING_TIMEOUT_MS)
end

function WorldSwitcher.open(wait_load: boolean?): boolean
	local opened = SidePanels.open(SidePanels.LOGOUT)
	if not opened then
		return opened
	end
	local open = WorldSwitcher.is_open()
	if not open then
		local button = widget(Logout.GROUP, Logout.WORLD_SWITCHER)
		if button == nil then
			return false
		end
		Mouse.move(button)
		mouse_down("left")
		local appeared = wait_until(function()
			return WorldSwitcher.is_open() == true
		end, OPEN_TIMEOUT_MS)
		local title = component(WorldSwitcher.TITLE)
		if title ~= nil then
			local margin = math.floor(title.width / 4)
			Mouse.move(
				Box.new(title.x + margin, title.y + 2, title.x + title.width - margin, title.y + title.height - 3)
			)
		end
		mouse_up("left")
		if not appeared then
			if RecommendSurvey.is_open() then
				return false
			end
			Log.log("WorldSwitcher", `the world switcher didn't open within {OPEN_TIMEOUT_MS} ms`)
			return false
		end
	end
	if wait_load ~= false and not WorldSwitcher.wait_loading() then
		return false
	end
	return true
end

function WorldSwitcher.close(): boolean
	local open = WorldSwitcher.is_open()
	if not open then
		return true
	end
	local close = component(WorldSwitcher.CLOSE)
	if close == nil then
		return false
	end
	Mouse.click(close)
	if not wait_until(function()
		return WorldSwitcher.is_open() == false
	end, CLOSE_TIMEOUT_MS) then
		Log.log("WorldSwitcher", `the world switcher didn't close within {CLOSE_TIMEOUT_MS} ms`)
		return false
	end
	return true
end

function WorldSwitcher.logout(attempts: number?, time_ms: number?): boolean
	return Logout.logout_from_world_switcher(attempts, time_ms)
end

export type Buttons = {
	configure: Widget,
	close: Widget,
	logout: Widget,
	sort_world: Widget,
}

function WorldSwitcher.buttons(): Buttons?
	local configure = component(WorldSwitcher.CONFIGURE)
	local close = component(WorldSwitcher.CLOSE)
	local logout = component(WorldSwitcher.LOGOUT)
	local sort_world = component(WorldSwitcher.SORT_WORLD)
	if configure == nil or close == nil or logout == nil or sort_world == nil then
		return nil
	end
	return { configure = configure, close = close, logout = logout, sort_world = sort_world }
end

function WorldSwitcher.is_sorted(): boolean
	local order = varp(WorldSwitcher.SORT_VARP)
	if order == nil then
		return false
	end
	return order == 0
end

function WorldSwitcher.sort(): boolean
	local open = WorldSwitcher.is_open()
	if not open then
		return false
	end
	for _ = 1, 2 do
		if WorldSwitcher.is_sorted() then
			return true
		end
		local header = component(WorldSwitcher.SORT_WORLD)
		if header == nil then
			return false
		end
		local before = varp(WorldSwitcher.SORT_VARP)
		Mouse.click(header)
		wait_until(function()
			return varp(WorldSwitcher.SORT_VARP) ~= before
		end, SORT_TIMEOUT_MS)
	end
	if WorldSwitcher.is_sorted() then
		return true
	end
	return false
end

function WorldSwitcher.cooldown(): number
	return math.max(0, ready_at - time())
end

local function scroll_to(world: number): Row?
	for _ = 1, MAX_SCROLLS do
		local row = WorldSwitcher.find(world)
		if row == nil then
			return nil
		end
		if row.visible then
			return row
		end
		local list = component(WorldSwitcher.LIST)
		if list == nil then
			return nil
		end
		local down = row.box.y1 > list.y
		Mouse.scroll(Biometrics.random_mode_integer(2, 1, 3), down, box_of(list))
		Random.sleep(80, 250)
	end
	return nil
end

local function hopping(): boolean
	local state = game_state()
	return state.game_state ~= GameState.LOGGED_IN
end

function WorldSwitcher.wait_switch(world: number, fail_cooldown: boolean?): boolean
	if not wait_until(hopping, HOP_START_MS) then
		if fail_cooldown ~= false then
			ready_at = time() + WorldSwitcher.cooldown_ms
		end
		return false
	end
	local arrived = wait_until(function()
		local state = game_state()
		return state.game_state == GameState.LOGGED_IN and WorldSwitcher.current() == world
	end, HOP_TIMEOUT_MS)
	if not arrived then
		Log.log("WorldSwitcher", `didn't arrive on world {world} within {HOP_TIMEOUT_MS} ms`)
		return false
	end
	return true
end

local function hovering(world: number): boolean
	return wait_until(function()
		local entries = menu()
		local top = entries and entries[1]
		return top ~= nil and top.option == "Switch" and top.index == world
	end, HOVER_TIMEOUT_MS)
end

local CONFIRM_TIMEOUT_MS = 1800

local function confirm_button(world: number): Widget?
	local text = widget(WorldSwitcher.CONFIRM_GROUP, WorldSwitcher.CONFIRM_TEXT)
	if
		text == nil
		or text.hidden
		or text.text == nil
		or not string.find(text.text, `switch to World {world}`, 1, true)
	then
		return nil
	end
	for _, button in widget_children(WorldSwitcher.CONFIRM_GROUP, WorldSwitcher.CONFIRM_BUTTONS) or {} do
		if button.text == "Switch world" and not button.hidden then
			return button
		end
	end
	return nil
end

local function confirm(world: number)
	local button: Widget? = nil
	wait_until(function()
		button = confirm_button(world)
		return button ~= nil or hopping()
	end, CONFIRM_TIMEOUT_MS)
	if button then
		Random.sleep(150, 500)
		Mouse.click(box_of(button))
	end
end

local function hop(world: number): boolean
	local row = scroll_to(world)
	if row == nil then
		return false
	end
	if not row.available then
		return false
	end
	Mouse.move(row.box)
	if not hovering(world) then
		return false
	end
	Mouse.click()
	confirm(world)
	return WorldSwitcher.wait_switch(world)
end

function WorldSwitcher.switch(world: number): boolean
	if WorldSwitcher.cooldown() > 0 then
		return false
	end
	local current = WorldSwitcher.current()
	if current == nil then
		return false
	end
	if current == world then
		return true
	end
	local opened = WorldSwitcher.open()
	if not opened then
		return opened
	end
	return hop(world)
end

local function pick(worlds: { number }, choose: (current: number, at: number?) -> number): boolean
	if #worlds == 0 then
		return false
	end
	if WorldSwitcher.cooldown() > 0 then
		return false
	end
	local current = WorldSwitcher.current()
	if current == nil then
		return false
	end
	if #worlds == 1 and worlds[1] == current then
		return true
	end
	return WorldSwitcher.switch(choose(current, table.find(worlds, current)))
end

function WorldSwitcher.next(worlds: { number }): boolean
	return pick(worlds, function(_, at)
		return worlds[if at and at < #worlds then at + 1 else 1]
	end)
end

function WorldSwitcher.previous(worlds: { number }): boolean
	return pick(worlds, function(_, at)
		return worlds[if at and at > 1 then at - 1 else #worlds]
	end)
end

function WorldSwitcher.random(worlds: { number }): boolean
	return pick(worlds, function(current)
		local others: { number } = {}
		for _, w in worlds do
			if w ~= current then
				table.insert(others, w)
			end
		end
		return others[math.random(#others)]
	end)
end

return WorldSwitcher
