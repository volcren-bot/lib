--!strict
local Host = require("@lib/host")
local game_state = Host.game_state
local widget = Host.widget
local widget_children = Host.widget_children
local world_select = Host.world_select
local menu = Host.menu
local chat_messages = Host.chat_messages
local varp = Host.varp
local sleep = Host.sleep
local time = Host.time
local mouse_down = Host.mouse_down
local mouse_up = Host.mouse_up
type Widget = Host.Widget
local Biometrics = require("@lib/main/antiban/biometrics")
local GameState = require("@lib/main/game_state")
local Geometry = require("@lib/utils/math/geometry")
local Keyboard = require("@lib/utils/input/keyboard")
local Log = require("@lib/utils/log")
local LoginWorldSwitcher = require("@lib/main/interfaces/login/login_world_switcher")
local Logout = require("@lib/main/interfaces/gametabs/logout")
local Mouse = require("@lib/utils/input/mouse")
local Random = require("@lib/utils/math/random")
local RecommendSurvey = require("@lib/main/interfaces/chatbox/recommend_survey")
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")
local Stats = require("@lib/main/interfaces/gametabs/stats")
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

-- worlds the game refused to let us into (a warning or "Please choose a different world."): kept until the script ends, always skipped
local blocked: { [number]: boolean } = {}

function WorldSwitcher.is_blocked(world: number): boolean
	return blocked[world] == true
end

function WorldSwitcher.blocked_worlds(): { number }
	local worlds: { number } = {}
	for world in blocked do
		table.insert(worlds, world)
	end
	table.sort(worlds)
	return worlds
end

local function block(world: number, why: string)
	if not blocked[world] then
		blocked[world] = true
		Log.log("WorldSwitcher", `world {world} {why}, never hopping there`)
	end
end

-- world type flags the client itself reads from the world list (PvP, bounty, high risk, deadman, ...)
WorldSwitcher.UNSAFE_TYPES = LoginWorldSwitcher.DANGEROUS

-- activities that are PvP but carry no type flag (lowercase, matched as substrings)
WorldSwitcher.UNSAFE_ACTIVITIES = { "pvp", "wilderness", "clan wars", "last man standing", "lms" }

export type Row = {
	world: number,
	players: number?,
	activity: string?,
	types: number,
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

-- the total level a skill total world asks for (its activity reads like "1500 skill total")
local function required_total(types: number, activity: string?): number?
	if bit32.band(types, LoginWorldSwitcher.SKILL_TOTAL) == 0 or activity == nil then
		return nil
	end
	local number = string.match(activity, "(%d+)")
	return if number then tonumber(number) else nil
end

-- whether your total level lets you into a world; unknown levels don't. `total` gives the level without a read, or reads it once
local function meets_total(types: number, activity: string?, total: (() -> number?)?): boolean
	local required = required_total(types, activity)
	if required == nil then
		return true
	end
	local have = if total then total() else Stats.total_level(game_state().skills)
	return have ~= nil and have >= required
end

-- reads the total level on the first call and keeps it
local function total_once(): () -> number?
	local read, total = false, nil :: number?
	return function()
		if not read then
			read, total = true, Stats.total_level(game_state().skills)
		end
		return total
	end
end

local function is_safe(types: number, activity: string?): boolean
	if bit32.band(types, WorldSwitcher.UNSAFE_TYPES) ~= 0 then
		return false
	end
	if activity == nil then
		return true
	end
	activity = string.lower(activity)
	for _, unsafe in WorldSwitcher.UNSAFE_ACTIVITIES do
		if string.find(activity, unsafe, 1, true) then
			return false
		end
	end
	return true
end

-- the type flags of every world, by number
-- drops the dangerous worlds from a list of world numbers
local function only_safe(worlds: { number }): { number }
	local info: { [number]: { types: number, activity: string } } = {}
	local select = world_select()
	if select ~= nil then
		for _, w in select.worlds do
			info[w.id] = w
		end
	end
	local result: { number } = {}
	for _, world in worlds do
		local w = info[world]
		if not blocked[world] and (w == nil or is_safe(w.types, w.activity)) then
			table.insert(result, world)
		end
	end
	return result
end

local function list_rows(): { Row }?
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

	local select = world_select()
	local types: { [number]: number } = {}
	if select ~= nil then
		for _, w in select.worlds do
			types[w.id] = w.types
		end
	end
	local current = if select ~= nil then select.current else WorldSwitcher.current()
	local total = total_once()
	local result: { Row } = {}
	for _, row in rows do
		if not row.hidden then
			local line: { Widget } = texts[row.y] or {}
			table.sort(line, function(a: Widget, b: Widget)
				return a.x < b.x
			end)
			local number, players, activity = line[1], line[2], line[3]
			local colour = if number then number.text_color else WorldSwitcher.FREE
			-- the world you are on is drawn grey like an unavailable one, so its colour says nothing
			local here = row.index == current
			table.insert(result, {
				world = row.index,
				players = if players then tonumber(players.text) else nil,
				activity = if activity then activity.text else nil,
				types = types[row.index] or 0,
				members = if types[row.index]
					then bit32.band(types[row.index], LoginWorldSwitcher.MEMBERS) ~= 0
					else colour == WorldSwitcher.MEMBERS,
				available = (here or colour ~= WorldSwitcher.UNAVAILABLE)
					and meets_total(types[row.index] or 0, activity and activity.text, total),
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

function WorldSwitcher.rows(safe: boolean?): { Row }?
	local rows = list_rows()
	if rows == nil then
		return nil
	end
	local filtered: { Row } = {}
	for _, row in rows do
		if not blocked[row.world] and (safe == false or is_safe(row.types, row.activity)) then
			table.insert(filtered, row)
		end
	end
	return filtered
end

function WorldSwitcher.worlds(safe: boolean?): { Row }?
	local rows = WorldSwitcher.rows(safe)
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
	local rows = list_rows()
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
	local rows = list_rows()
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
local DISMISS_TIMEOUT_MS = 1200
local REFUSED = "Please choose a different world."

-- the newest chat message's uid, to tell the messages a click causes from older ones
local function last_uid(): number
	local newest = 0
	for _, m in chat_messages() or {} do
		if m.uid > newest then
			newest = m.uid
		end
	end
	return newest
end

-- the "World N is a ... world!" confirmation the world list shows before some worlds, and the world it names
local function warning(): (Widget?, number?)
	local text = widget(WorldSwitcher.CONFIRM_GROUP, WorldSwitcher.CONFIRM_TEXT)
	if text == nil or text.hidden or text.text == nil then
		return nil, nil
	end
	local number = string.match(text.text, "World (%d+) is a")
	if number == nil then
		return nil, nil
	end
	return text, tonumber(number)
end

local function refused(since: number): boolean
	for _, m in chat_messages() or {} do
		if m.uid > since and string.find(m.text, REFUSED, 1, true) then
			return true
		end
	end
	return false
end

-- closes the warning with escape or its Cancel button (a biometric picks which first, the button is the fallback)
local function dismiss_warning(): boolean
	local function gone(): boolean
		return wait_until(function()
			return warning() == nil
		end, DISMISS_TIMEOUT_MS)
	end
	Random.sleep(200, 600)
	if Random.chance(Biometrics.get_probability(Biometrics.ESCAPE)) then
		Keyboard.key_press(Keyboard.keys.ESCAPE)
		if gone() then
			return true
		end
	end
	for _, button in widget_children(WorldSwitcher.CONFIRM_GROUP, WorldSwitcher.CONFIRM_BUTTONS) or {} do
		if button.text == "Cancel" and not button.hidden then
			Mouse.click(box_of(button))
			if gone() then
				return true
			end
			break
		end
	end
	if warning() == nil then
		return true
	end
	Keyboard.key_press(Keyboard.keys.ESCAPE)
	return gone()
end

-- blocks the world when the game turned the hop down, with a warning (cancelled) or a chat message; true when it did
local function check_refusal(world: number, since: number): boolean
	local text, named = warning()
	if text ~= nil then
		block(named or world, "warns before entering")
		if not dismiss_warning() then
			Log.log("WorldSwitcher", "couldn't close the world warning")
		end
		return true
	end
	if refused(since) then
		block(world, "isn't allowed")
		return true
	end
	return false
end

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

local function confirm(world: number, since: number)
	local button: Widget? = nil
	wait_until(function()
		button = confirm_button(world)
		return button ~= nil or hopping() or warning() ~= nil or refused(since)
	end, CONFIRM_TIMEOUT_MS)
	if button then
		Random.sleep(150, 500)
		Mouse.click(box_of(button))
	end
end

local HOP_ATTEMPTS = 3

-- one go at hopping: "ok", "refused" (the game said no, the world is blocked now), "moving" (the hop started but we didn't arrive), "unavailable" or "failed" (worth another try)
local function hop(world: number, fail_cooldown: boolean): string
	local row = scroll_to(world)
	if row == nil then
		return "failed"
	end
	if not row.available then
		return "unavailable"
	end
	Mouse.move(row.box)
	if not hovering(world) then
		return "failed"
	end
	local since = last_uid()
	Mouse.click()
	confirm(world, since)
	if not hopping() and check_refusal(world, since) then
		return "refused"
	end
	if WorldSwitcher.wait_switch(world, fail_cooldown) then
		return "ok"
	end
	if hopping() then
		return "moving"
	end
	if check_refusal(world, since) then
		return "refused"
	end
	return if WorldSwitcher.current() == world then "ok" else "failed"
end

-- whether your total level lets you into a world (worlds that aren't in the world list pass)
local function can_join(world: number): boolean
	local select = world_select()
	if select ~= nil then
		for _, w in select.worlds do
			if w.id == world then
				return meets_total(w.types, w.activity)
			end
		end
	end
	return true
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
	if blocked[world] then
		Log.log("WorldSwitcher", `world {world} is blocked`)
		return false
	end
	if not can_join(world) then
		Log.log("WorldSwitcher", `world {world} needs a higher total level than yours`)
		return false
	end
	for attempt = 1, HOP_ATTEMPTS do
		local opened = WorldSwitcher.open()
		if not opened then
			return opened
		end
		-- a list in world order scrolls predictably; if sorting fails the world is still found by scrolling
		if not WorldSwitcher.sort() then
			Log.log("WorldSwitcher", "couldn't sort the world list by world number")
		end
		local result = hop(world, attempt == HOP_ATTEMPTS)
		if result == "ok" then
			return true
		end
		if result ~= "failed" then
			return false
		end
		if attempt < HOP_ATTEMPTS then
			Log.log("WorldSwitcher", `hopping to world {world} failed (attempt {attempt}/{HOP_ATTEMPTS}), trying again`)
			Random.sleep(500, 1500)
		end
	end
	Log.warn(
		"WorldSwitcher",
		`hopping to world {world} failed {HOP_ATTEMPTS} times in a row, blocking it for this script`
	)
	block(world, `didn't let us in after {HOP_ATTEMPTS} attempts`)
	return false
end

local function pick(
	worlds: { number },
	safe: boolean?,
	choose: (worlds: { number }, current: number, at: number?) -> number
): boolean
	if safe ~= false then
		worlds = only_safe(worlds)
	else
		local allowed: { number } = {}
		for _, world in worlds do
			if not blocked[world] then
				table.insert(allowed, world)
			end
		end
		worlds = allowed
	end
	local reachable: { number } = {}
	local select = world_select()
	local info: { [number]: { types: number, activity: string } } = {}
	if select ~= nil then
		for _, w in select.worlds do
			info[w.id] = w
		end
	end
	local total = total_once()
	for _, world in worlds do
		local w = info[world]
		if w == nil or meets_total(w.types, w.activity, total) then
			table.insert(reachable, world)
		end
	end
	worlds = reachable
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
	return WorldSwitcher.switch(choose(worlds, current, table.find(worlds, current)))
end

function WorldSwitcher.next(worlds: { number }, safe: boolean?): boolean
	return pick(worlds, safe, function(worlds, _, at)
		return worlds[if at and at < #worlds then at + 1 else 1]
	end)
end

function WorldSwitcher.previous(worlds: { number }, safe: boolean?): boolean
	return pick(worlds, safe, function(worlds, _, at)
		return worlds[if at and at > 1 then at - 1 else #worlds]
	end)
end

function WorldSwitcher.random(worlds: { number }, safe: boolean?): boolean
	return pick(worlds, safe, function(worlds, current)
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
