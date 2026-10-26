--!strict
local Host = require("../../../host")
local game_state = Host.game_state
local connection = Host.connection
local world_select = Host.world_select
local sleep = Host.sleep
type World = Host.World
type WorldSelect = Host.WorldSelect
local GameState = require("../../game_state")
local Geometry = require("../../../utils/math/geometry")
local Random = require("../../../utils/math/random")
local Mouse = require("../../../utils/input/mouse")
local Log = require("../../../utils/log")
local Box = Geometry.Box
type Box = Geometry.Box

local LoginWorldSwitcher = {}

LoginWorldSwitcher.MEMBERS = 0x1
LoginWorldSwitcher.PVP = 0x4
LoginWorldSwitcher.BOUNTY = 0x20
LoginWorldSwitcher.PVP_ARENA = 0x40
LoginWorldSwitcher.SKILL_TOTAL = 0x80
LoginWorldSwitcher.QUEST_SPEEDRUNNING = 0x100
LoginWorldSwitcher.HIGH_RISK = 0x400
LoginWorldSwitcher.LAST_MAN_STANDING = 0x4000
LoginWorldSwitcher.BETA_WORLD = 0x10000
LoginWorldSwitcher.LEGACY_ONLY = 0x400000
LoginWorldSwitcher.EOC_ONLY = 0x800000
LoginWorldSwitcher.NOSAVE_MODE = 0x2000000
LoginWorldSwitcher.TOURNAMENT_WORLD = 0x4000000
LoginWorldSwitcher.FRESH_START_WORLD = 0x8000000
LoginWorldSwitcher.DEADMAN = 0x20000000
LoginWorldSwitcher.SEASONAL = 0x40000000

LoginWorldSwitcher.DANGEROUS = bit32.bor(
	LoginWorldSwitcher.PVP,
	LoginWorldSwitcher.BOUNTY,
	LoginWorldSwitcher.QUEST_SPEEDRUNNING,
	LoginWorldSwitcher.HIGH_RISK,
	LoginWorldSwitcher.BETA_WORLD,
	LoginWorldSwitcher.NOSAVE_MODE,
	LoginWorldSwitcher.TOURNAMENT_WORLD,
	LoginWorldSwitcher.FRESH_START_WORLD,
	LoginWorldSwitcher.DEADMAN,
	LoginWorldSwitcher.SEASONAL
)

LoginWorldSwitcher.allow_dangerous_worlds = false

LoginWorldSwitcher.OFFLINE = -1
LoginWorldSwitcher.FULL = 1980

export type Layout = {
	columns: number,
	rows: number,
	width: number,
	height: number,
	x_gap: number,
	y_gap: number,
	x: number,
	y: number,
}

export type WorldBox = {
	index: number,
	slot: number,
	world: World,
	box: Box,
}

type Screen = {
	select: WorldSelect,
	panel_x: number,
	width: number,
	height: number,
	scale: number,
}

local PANEL_WIDTH = 765
local PANEL_HEIGHT = 480
local BOX_WIDTH = 88
local BOX_HEIGHT = 19
local MAX_COLUMNS = 7
local MAX_ROWS = 24
local MAX_GAP = 5
local TOP_BAR = 23
local ARROW_WIDTH = 43
local ARROW_HEIGHT = 29

local POLL_MS = 50
local OPEN_TIMEOUT_MS = 5000
local CLOSE_TIMEOUT_MS = 1500
local PAGE_TIMEOUT_MS = 1500
local HOVER_TIMEOUT_MS = 600
local SWITCH_TIMEOUT_MS = 1500
local SWITCH_ATTEMPTS = 5

local trunc = Random.trunc

local function screen(): Screen?
	local state = game_state()
	if state.game_state ~= GameState.LOGIN_SCREEN and state.game_state ~= GameState.LOGIN_SCREEN_AUTHENTICATOR then
		return nil
	end
	local login = state.login
	if login == nil then
		Log.log("LoginWorldSwitcher", "login screen layout unknown")
		return nil
	end
	local select = world_select()
	if select == nil then
		return nil
	end
	local conn = connection()
	return {
		select = select,
		panel_x = login.panel_x,
		width = conn.width,
		height = conn.height,
		scale = login.scale or 1,
	}
end

local function scaled(s: Screen, x1: number, y1: number, x2: number, y2: number): Box
	local function px(v: number): number
		return math.floor(v * s.scale)
	end
	return Box.new(px(x1), px(y1), px(x2), px(y2))
end

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

function LoginWorldSwitcher.state(): WorldSelect?
	local s = screen()
	if s == nil then
		return nil
	end
	return s.select
end

function LoginWorldSwitcher.is_open(): boolean
	local select = LoginWorldSwitcher.state()
	if select == nil then
		return false
	end
	return select.open
end

function LoginWorldSwitcher.wait_open(timeout_ms: number?): boolean
	return wait_until(function()
		return LoginWorldSwitcher.is_open() == true
	end, timeout_ms or OPEN_TIMEOUT_MS)
end

function LoginWorldSwitcher.current(): number?
	local select = LoginWorldSwitcher.state()
	if select == nil then
		return nil
	end
	return select.current
end

function LoginWorldSwitcher.worlds(): { World }?
	local select = LoginWorldSwitcher.state()
	if select == nil then
		return nil
	end
	return select.worlds
end

function LoginWorldSwitcher.world(id: number): World?
	local worlds = LoginWorldSwitcher.worlds()
	if worlds == nil then
		return nil
	end
	for _, world in worlds do
		if world.id == id then
			return world
		end
	end
	return nil
end

function LoginWorldSwitcher.has_type(world: World, types: number): boolean
	return bit32.band(world.types, types) ~= 0
end

function LoginWorldSwitcher.is_dangerous(world: World): boolean
	return LoginWorldSwitcher.has_type(world, LoginWorldSwitcher.DANGEROUS)
end

function LoginWorldSwitcher.is_available(world: World): boolean
	return world.players ~= LoginWorldSwitcher.OFFLINE and world.players <= LoginWorldSwitcher.FULL
end

function LoginWorldSwitcher.layout(count: number): Layout?
	if count < 1 then
		return nil
	end
	local columns, rows = MAX_COLUMNS, MAX_ROWS
	repeat
		local last_columns, last_rows = columns, rows
		if (columns - 1) * rows >= count then
			columns -= 1
		end
		if columns * (rows - 1) >= count then
			rows -= 1
		end
		if columns * (rows - 1) >= count then
			rows -= 1
		end
	until last_columns == columns and last_rows == rows
	local x_gap = math.min(MAX_GAP, trunc((PANEL_WIDTH - columns * BOX_WIDTH) / (columns + 1)))
	local y_gap = math.min(MAX_GAP, trunc((PANEL_HEIGHT - rows * BOX_HEIGHT) / (rows + 1)))
	return {
		columns = columns,
		rows = rows,
		width = BOX_WIDTH,
		height = BOX_HEIGHT,
		x_gap = x_gap,
		y_gap = y_gap,
		x = trunc((PANEL_WIDTH - columns * BOX_WIDTH - (columns - 1) * x_gap) / 2),
		y = trunc((PANEL_HEIGHT - rows * BOX_HEIGHT - (rows - 1) * y_gap) / 2),
	}
end

local function world_button(s: Screen): Box
	local bottom = math.min(s.height, s.select.background_height or s.height)
	return scaled(s, s.panel_x + 20, bottom - 55, s.panel_x + 120, bottom - 20)
end

local function cancel_button(s: Screen): Box
	return scaled(s, s.panel_x + 708, 4, s.panel_x + 758, 20)
end

local function arrow_y(s: Screen): number
	return s.height // 2 - ARROW_HEIGHT // 2
end

local function left_button(s: Screen, l: Layout): Box
	local x2 = s.panel_x + l.x - 2 * l.x_gap - 1
	local y = arrow_y(s)
	return scaled(s, x2 - ARROW_WIDTH + 1, y, x2, y + ARROW_HEIGHT - 1)
end

local function right_button(s: Screen, l: Layout): Box
	local sprite_x = s.panel_x + l.x + l.columns * (l.width + l.x_gap) + l.x_gap
	local clickable_x = s.width - s.panel_x - l.x + 2 * l.x_gap
	local y = arrow_y(s)
	return scaled(s, math.max(sprite_x, clickable_x), y, sprite_x + ARROW_WIDTH - 1, y + ARROW_HEIGHT - 1)
end

local function boxes(s: Screen): { WorldBox }?
	if not s.select.open then
		return nil
	end
	local worlds = s.select.worlds
	local l = LoginWorldSwitcher.layout(#worlds)
	if l == nil then
		return nil
	end
	local result: { WorldBox } = {}
	for i = s.select.offset * l.rows, #worlds - 1 do
		local column = i // l.rows - s.select.offset
		if column >= l.columns then
			break
		end
		local row = i % l.rows
		local x1 = s.panel_x + l.x + column * (l.width + l.x_gap)
		local y1 = TOP_BAR + l.y + row * (l.height + l.y_gap)
		table.insert(result, {
			index = i + 1,
			slot = #result + 1,
			world = worlds[i + 1],
			box = scaled(s, x1, y1, x1 + l.width - 1, y1 + l.height - 1),
		})
	end
	return result
end

export type Buttons = {
	world: Box,
	cancel: Box,
	left: Box?,
	right: Box?,
}

function LoginWorldSwitcher.buttons(): Buttons?
	local s = screen()
	if s == nil then
		return nil
	end
	local l = LoginWorldSwitcher.layout(#s.select.worlds)
	local can_scroll = s.select.open and l ~= nil
	return {
		world = world_button(s),
		cancel = cancel_button(s),
		left = if can_scroll and l and s.select.offset > 0 then left_button(s, l) else nil,
		right = if can_scroll and l and s.select.offset < s.select.max_offset then right_button(s, l) else nil,
	}
end

function LoginWorldSwitcher.boxes(): { WorldBox }?
	local s = screen()
	if s == nil then
		return nil
	end
	return boxes(s)
end

function LoginWorldSwitcher.read(slot: number): number?
	local shown = LoginWorldSwitcher.boxes()
	if shown == nil then
		return nil
	end
	local b = shown[slot]
	return b and b.world.id
end

function LoginWorldSwitcher.open(): boolean
	local s = screen()
	if s == nil then
		return false
	end
	if s.select.open then
		return true
	end
	Mouse.click(world_button(s))
	if not LoginWorldSwitcher.wait_open() then
		Log.log("LoginWorldSwitcher", `the world switcher didn't open within {OPEN_TIMEOUT_MS} ms`)
		return false
	end
	return true
end

function LoginWorldSwitcher.close(): boolean
	local s = screen()
	if s == nil then
		return false
	end
	if not s.select.open then
		return true
	end
	Mouse.click(cancel_button(s))
	local closed = wait_until(function()
		return LoginWorldSwitcher.is_open() == false
	end, CLOSE_TIMEOUT_MS)
	if not closed then
		Log.log("LoginWorldSwitcher", `the world switcher didn't close within {CLOSE_TIMEOUT_MS} ms`)
		return false
	end
	return true
end

local function scroll(step: number): boolean
	local s = screen()
	if s == nil then
		return false
	end
	if not s.select.open then
		return false
	end
	local l = LoginWorldSwitcher.layout(#s.select.worlds)
	if l == nil then
		return false
	end
	local from = s.select.offset
	if (step < 0 and from <= 0) or (step > 0 and from >= s.select.max_offset) then
		return false
	end
	Mouse.click(if step < 0 then left_button(s, l) else right_button(s, l))
	local moved = wait_until(function()
		local select = LoginWorldSwitcher.state()
		return select ~= nil and select.offset ~= from
	end, PAGE_TIMEOUT_MS)
	if not moved then
		Log.log("LoginWorldSwitcher", `the world list didn't scroll within {PAGE_TIMEOUT_MS} ms`)
		return false
	end
	Random.sleep(400, 1200)
	return true
end

function LoginWorldSwitcher.previous_page(): boolean
	return scroll(-1)
end

function LoginWorldSwitcher.next_page(): boolean
	return scroll(1)
end

function LoginWorldSwitcher.find(id: number): WorldBox?
	local opened = LoginWorldSwitcher.open()
	if not opened then
		return nil
	end
	for _ = 1, MAX_COLUMNS * 4 do
		local s = screen()
		if s == nil then
			return nil
		end
		local worlds = s.select.worlds
		local l = LoginWorldSwitcher.layout(#worlds)
		if l == nil then
			return nil
		end
		local index: number? = nil
		for i, world in worlds do
			if world.id == id then
				index = i
				break
			end
		end
		if index == nil then
			LoginWorldSwitcher.close()
			return nil
		end
		local column = (index - 1) // l.rows
		local offset = s.select.offset
		if column < offset then
			local scrolled = scroll(-1)
			if not scrolled then
				return nil
			end
		elseif column >= offset + l.columns then
			local scrolled = scroll(1)
			if not scrolled then
				return nil
			end
		else
			local shown = boxes(s)
			if shown == nil then
				return nil
			end
			for _, b in shown do
				if b.index == index then
					return b
				end
			end
			return nil
		end
	end
	return nil
end

local function hovering(index: number): boolean
	return wait_until(function()
		local select = LoginWorldSwitcher.state()
		return select ~= nil and select.hovered == index - 1
	end, HOVER_TIMEOUT_MS)
end

function LoginWorldSwitcher.switch(id: number): boolean
	local current = LoginWorldSwitcher.current()
	if current == nil then
		return false
	end
	if current == id then
		return true
	end

	local found = LoginWorldSwitcher.find(id)
	if found == nil then
		return false
	end
	local world = found.world
	if not LoginWorldSwitcher.allow_dangerous_worlds and LoginWorldSwitcher.is_dangerous(world) then
		Log.log(
			"LoginWorldSwitcher",
			`world {id} is a dangerous world ({world.activity}): set LoginWorldSwitcher.allow_dangerous_worlds if this is intentional`
		)
		return false
	end
	if not LoginWorldSwitcher.is_available(world) then
		return false
	end

	Mouse.move(found.box)
	if not hovering(found.index) then
		return false
	end
	Mouse.click()
	local switched = wait_until(function()
		local select = LoginWorldSwitcher.state()
		return select ~= nil and not select.open and select.current == id
	end, SWITCH_TIMEOUT_MS)
	if not switched then
		Log.log("LoginWorldSwitcher", `didn't switch to world {id} within {SWITCH_TIMEOUT_MS} ms`)
		return false
	end
	return true
end

function LoginWorldSwitcher.switch_random(ids: { number }): boolean
	if #ids == 0 then
		return false
	end
	local current = LoginWorldSwitcher.current()
	if current == nil then
		return false
	end
	if table.find(ids, current) then
		return true
	end
	for _ = 1, SWITCH_ATTEMPTS do
		local switched = LoginWorldSwitcher.switch(ids[math.random(#ids)])
		if switched then
			return true
		end
	end
	Log.log("LoginWorldSwitcher", `couldn't switch to any of the worlds after {SWITCH_ATTEMPTS} attempts`)
	return false
end

return LoginWorldSwitcher
