--!strict
local Antiban = require("./antiban")
local Biometrics = require("./biometrics")
local Camera = require("../camera")
local ChatTabs = require("../interfaces/chatbox/chat_tabs")
local DepositBox = require("../interfaces/mainscreen/depositbox")
local Geometry = require("../../utils/math/geometry")
local GroundItems = require("../entities/ground_items")
local Host = require("../../host")
local Log = require("../../utils/log")
local Make = require("../interfaces/chatbox/make")
local Minimap = require("../interfaces/minimap")
local Minimenu = require("../interfaces/minimenu")
local Mouse = require("../../utils/input/mouse")
local Npcs = require("../entities/npcs")
local Players = require("../entities/players")
local Random = require("../../utils/math/random")
local SidePanels = require("../interfaces/gametabs/side_panels")
local Stats = require("../interfaces/gametabs/stats")

local Point = Geometry.Point
local Box = Geometry.Box
type Point = Geometry.Point
type Box = Geometry.Box

local sleep = Host.sleep

local Tasks = {}

-- The skills `hover_skills` picks from, by name (see `Stats.CHILDREN`).
Tasks.skills = {} :: { string }

local CHAT_TABS: { ChatTabs.Tab } = { "game", "public", "private", "channel", "clan", "trade" }
local DEPOSIT_QUANTITIES: { DepositBox.Quantity } = { "ONE", "FIVE", "TEN", "ALL" }

local function canvas(): (number, number)
	local conn = Host.connection()
	return conn.width, conn.height
end

local function pause(async: boolean?, minimum: number, maximum: number?, dir: Random.Dir?)
	if async then
		Biometrics.sleep_async(minimum, maximum, dir)
	else
		Biometrics.sleep(minimum, maximum, dir)
	end
end

-- Async clicks run later, so `shown` is the tab the queued ones leave open: clicking it again would close it.
local function open_tab(async: boolean?, tab: number, shown: number?)
	if not async then
		SidePanels.open(tab)
	elseif tab ~= shown then
		SidePanels.open_async(tab, nil, true)
	end
end

local function open_chat_tab(async: boolean?, tab: ChatTabs.Tab, shown: ChatTabs.Tab | "none" | nil)
	if not async then
		ChatTabs.open(tab)
	elseif tab ~= shown then
		ChatTabs.open_async(tab, true)
	end
end

local function move_over(async: boolean?, box: Box)
	if async then
		Mouse.move_async(box)
	else
		Mouse.move(box)
	end
end

local function pick<T>(list: { T }): T
	return list[Random.int(1, #list)]
end

-- Starts a small mouse move and returns at once; the next input takes over.
function Tasks.small_random_mouse()
	Log.log("Antiban", "Random Mouse (Small)")
	local here = Mouse.position()
	if here == nil then
		return
	end
	local p: Point
	repeat
		p = Point.random(here, 350)
	until Point.distance(here, p) > 50
	Mouse.move_async(p)
end

function Tasks.large_random_mouse()
	Log.log("Antiban", "Random Mouse")
	local w, h = canvas()

	local speed = Mouse.speed
	Mouse.speed += Biometrics.random_mode_integer(2, 1, 5)

	local area = Box.new(-150, -150, w + 150, h + 150)
	for _ = 1, Random.trunc(math.abs(Random.gauss(1, 6))) do
		if Random.chance(0.3) then
			Mouse.move(area, true, "gauss")
		else
			Mouse.move(area, true, "random")
		end

		if Random.chance(0.5) then
			Biometrics.sleep(0, 1000, "left")
		end
	end

	Mouse.speed = speed
end

function Tasks.random_right_click()
	Log.log("Antiban", "Random Right Click")
	local w, h = canvas()

	Mouse.move(Box.new(15, 15, w - 15, h - 15), true, "random")
	local opened = Minimenu.open()
	if opened ~= true then
		Log.log("Antiban", "the menu didn't open")
		return
	end

	local open = Minimenu.entries()
	if open == nil or #open == 0 then
		Log.log("Antiban", "the menu didn't open")
		return
	end

	if Random.chance(0.5) then
		local row = Minimenu.row(Random.int(1, #open))
		if row ~= nil then
			Mouse.move(row)
		end
	end

	local examine = Minimenu.find("Examine")
	if Random.chance(0.6) and examine ~= nil then
		local row = Minimenu.row(examine)
		if row ~= nil then
			Mouse.click(row)
			return
		end
	end

	Biometrics.sleep(300, 6000, "left")
	Minimenu.close()
end

local function rotate_camera(radians: number, async: boolean?)
	local current = Camera.yaw_degrees()
	if current == nil then
		Log.log("Antiban", "the camera isn't readable")
		return
	end
	if async then
		Camera.set_yaw_degrees_async(current + math.deg(radians))
	else
		Camera.set_yaw_degrees(current + math.deg(radians))
	end
end

-- The tiny camera tasks queue their input and return at once; the next input takes over.
function Tasks.tiny_camera_rotation()
	Log.log("Antiban", "Tiny camera rotation")
	local current = Camera.yaw_degrees()
	if current == nil then
		Log.log("Antiban", "the camera isn't readable")
		return
	end
	Camera.set_yaw_degrees_async(current + Random.int(5, 20) * (if Random.chance(0.5) then 1 else -1))
end

function Tasks.small_camera_rotation(async: boolean?)
	Log.log("Antiban", "Small camera rotation")
	rotate_camera(Random.gauss(math.pi / 12, math.pi / 4) * Random.int(-1, 1), async)
end

-- Brings the zoom into the range of `set_zoom_range`, to a random level in it, if it is outside.
function Tasks.apply_zoom_range(): boolean
	local current = Camera.zoom()
	if current == nil then
		return false
	end
	if current >= Antiban.zoom.min and current <= Antiban.zoom.max then
		return true
	end
	local target = math.round(
		Random.mode(math.clamp(current, Antiban.zoom.min, Antiban.zoom.max), Antiban.zoom.min, Antiban.zoom.max)
	)
	Log.log("Antiban", `Setting the zoom to {target}`)
	return Camera.set_zoom(target)
end

-- Brings the pitch into the range of `set_pitch_range`, to a random level in it, if it is outside.
function Tasks.apply_pitch_range(): boolean
	local current = Camera.pitch()
	if current == nil then
		return false
	end
	if current >= Antiban.pitch.min and current <= Antiban.pitch.max then
		return true
	end
	local target = math.round(
		Random.mode(math.clamp(current, Antiban.pitch.min, Antiban.pitch.max), Antiban.pitch.min, Antiban.pitch.max)
	)
	Log.log("Antiban", `Setting the pitch to {target}`)
	return Camera.set_pitch(target)
end

-- `current + change`, kept inside `min` to `max`. If that is no change at all, the other way.
local function tiny_target(current: number, change: number, min: number, max: number, least: number): number
	local target = math.clamp(current + change, min, max)
	if math.abs(target - current) < least then
		target = math.clamp(current - change, min, max)
	end
	return target
end

-- One or two scroll notches up or down, inside the range of `set_zoom_range`.
function Tasks.tiny_zoom_change()
	local current = Camera.zoom()
	if current == nil then
		Log.log("Antiban", "the zoom isn't readable")
		return
	end
	local change = Random.int(1, 2) * Camera.ZOOM_STEP * (if Random.chance(0.5) then 1 else -1)
	local min, max = math.max(Camera.ZOOM_MIN, Antiban.zoom.min), math.min(Camera.ZOOM_MAX, Antiban.zoom.max)
	local target = tiny_target(current, change, min, max, Camera.ZOOM_STEP / 2)
	Log.log("Antiban", `Tiny zoom change: {current} -> {math.round(target)}`)
	Camera.set_zoom_async(target)
end

-- 3 to 15% of the pitch range up or down, inside the range of `set_pitch_range`.
function Tasks.tiny_pitch_change()
	local current = Camera.pitch()
	if current == nil then
		Log.log("Antiban", "the pitch isn't readable")
		return
	end
	local percent = Random.int(3, 15) / 100
	local change = math.round((Camera.PITCH_MAX - Camera.PITCH_MIN) * percent) * (if Random.chance(0.5) then 1 else -1)
	local min, max = math.max(Camera.PITCH_MIN, Antiban.pitch.min), math.min(Camera.PITCH_MAX, Antiban.pitch.max)
	local target = tiny_target(current, change, min, max, Camera.tolerance)
	Log.log("Antiban", `Tiny pitch change: {current} -> {math.round(target)}`)
	Camera.set_pitch_async(target)
end

local TINY_TASKS = { Tasks.tiny_camera_rotation, Tasks.tiny_zoom_change, Tasks.tiny_pitch_change }
local tiny_ready_at: { number } = {}

-- Runs one random tiny task that is off cooldown, then cools it for `min_cooldown` to `max_cooldown` ms; false when all are cooling.
function Tasks.random_tiny(min_cooldown: number, max_cooldown: number): boolean
	local ready: { number } = {}
	for i = 1, #TINY_TASKS do
		if Host.time() >= (tiny_ready_at[i] or 0) then
			table.insert(ready, i)
		end
	end
	if #ready == 0 then
		return false
	end
	local i = pick(ready)
	tiny_ready_at[i] = Host.time() + Random.int(min_cooldown, max_cooldown)
	TINY_TASKS[i]()
	return true
end

function Tasks.large_camera_rotation()
	Log.log("Antiban", "Large camera rotation")
	rotate_camera(Random.gauss(math.pi / 6, 2 * math.pi) * Random.int(-1, 1))
end

function Tasks.adjust_zoom()
	local zmin, zmax = Antiban.zoom.min, Antiban.zoom.max
	if math.abs(zmax - zmin) <= 15 then
		Log.log("Antiban", "adjust_zoom: the zoom range is too narrow for this task")
		return
	end

	local current = Camera.zoom()
	if current == nil then
		Log.log("Antiban", "the zoom isn't readable")
		return
	end

	local zoom = math.clamp(current, zmin, zmax)
	local new = zoom
	local attempts = 0
	repeat
		attempts += 1
		if attempts > 100 then
			return
		end
		new = math.round(Random.mode(zoom, zmin, zmax))
	until math.abs(zoom - new) > 15

	Log.log("Antiban", `Adjust zoom: {new}`)
	Camera.set_zoom(new)
end

-- Zooms the minimap to a different random level; with `async` it queues the scrolls and returns at once.
function Tasks.adjust_minimap_zoom(async: boolean?)
	local current = Minimap.zoom()
	if current == nil then
		Log.log("Antiban", "the minimap zoom isn't readable")
		return
	end
	local new: number
	repeat
		new = Random.int(Minimap.ZOOM_MIN, Minimap.ZOOM_MAX)
	until new ~= current
	Log.log("Antiban", `Adjust minimap zoom: {current} -> {new}`)
	if async then
		Minimap.set_zoom_async(new)
	else
		Minimap.set_zoom(new)
	end
end

local function delta_angle(a: number, b: number): number
	local d = (b - a) % (2 * math.pi)
	return if d > math.pi then d - 2 * math.pi else d
end

local function angle(a: Point, b: Point): number
	return math.atan2(b.y - a.y, b.x - a.x)
end

local function generate_swivel_points(
	a: Point,
	inv_circularity: number,
	curls: number,
	base_rad: number,
	direction: boolean
): { Point }
	local result: { Point } = {}
	local origin = Random.int(0, 359)
	local start_angle = math.rad(origin)
	local from = a

	for _ = 1, curls do
		local rad = base_rad
		local c = Point.rotate(Point.new(from.x + rad, from.y + rad), math.rad(180 - origin), from)

		local count = math.max(8, math.floor(2 * math.pi * rad))
		local pts: { Point } = {}
		for k = 0, count - 1 do
			local t = 2 * math.pi * k / count
			table.insert(pts, Point.new(c.x + rad * math.cos(t), c.y + rad * math.sin(t)))
		end
		table.sort(pts, function(p: Point, q: Point)
			local ap = (math.atan2(p.y - c.y, p.x - c.x) - start_angle) % (2 * math.pi)
			local aq = (math.atan2(q.y - c.y, q.x - c.x) - start_angle) % (2 * math.pi)
			if direction then
				return ap < aq
			end
			return ap > aq
		end)

		local dx, dy = from.x - pts[1].x, from.y - pts[1].y
		for _, p in pts do
			p.x += dx
			p.y += dy
		end

		local jitter = math.round(rad * inv_circularity)
		local ctrl: { Point } = { Point.new(pts[1].x, pts[1].y) }
		for i = 2, #pts - 1, 35 do
			table.insert(
				ctrl,
				Point.new(pts[i].x + Random.int(-jitter, jitter), pts[i].y + Random.int(-jitter, jitter))
			)
		end
		local last = pts[#pts]
		table.insert(ctrl, Point.new(last.x + Random.int(-jitter, jitter), last.y + Random.int(-jitter, jitter)))

		local t = 0
		while t <= 1 do
			local work: { Point } = {}
			for k, p in ctrl do
				work[k] = Point.new(p.x, p.y)
			end
			for i = #work, 2, -1 do
				for k = 1, i - 1 do
					work[k].x += (work[k + 1].x - work[k].x) * t
					work[k].y += (work[k + 1].y - work[k].y) * t
				end
			end
			table.insert(result, Point.new(math.round(work[1].x), math.round(work[1].y)))
			t += 0.01
		end

		from = result[#result]
	end

	return result
end

local function swivel_near(
	start: Point,
	inv_circularity: number,
	curls: number,
	radius: number,
	direction: boolean,
	max_speed: number,
	min_speed: number,
	base_speed: number
)
	local can_idle = Mouse.can_idle
	local mouse_speed = Mouse.speed
	Mouse.speed = Random.int(15, 20)
	Mouse.can_idle = false

	local q = Point.new(-1, -1)
	local swivel = generate_swivel_points(start, inv_circularity, curls, radius, direction)
	local speed = base_speed
	local i = 1
	while i <= #swivel do
		local p = swivel[i]
		if Point.distance(p, q) > math.max(4, speed * 2) then
			Mouse.move(p)
		end
		Mouse.teleport(Point.random(p, 1))
		q = p

		local d1 = angle(swivel[i], swivel[math.min(#swivel, i + 20)])
		local d2 = angle(swivel[i], swivel[math.min(#swivel, i + 40)])
		local asc = math.abs(delta_angle(d1, d2))

		if #swivel - i < speed then
			speed -= 1
		end
		if asc < 2.0 then
			speed += 2
		end
		speed = math.min(max_speed, speed)
		speed = math.max(min_speed, speed - math.random() * 0.5)

		sleep(1)
		i += math.round(speed)
	end

	Mouse.speed = mouse_speed
	Mouse.can_idle = can_idle
end

function Tasks.swivel_near_box(area: Box, radius: number, iterations: number?)
	for _ = 1, iterations or 1 do
		swivel_near(
			Box.random_point(area),
			1 / 2,
			Random.trunc(Random.gauss(1, 4)),
			radius,
			Random.gauss(0, 1.25) > 0.5,
			Random.int(12, 22),
			9,
			14
		)
		if math.random() < 0.5 then
			Biometrics.sleep(0, 300, "left")
		end
	end
end

function Tasks.swivel()
	Log.log("Antiban", "Swivel")
	for _ = 1, Random.trunc(Random.gauss(1, 4)) do
		local here = Mouse.position()
		if here == nil then
			return
		end
		swivel_near(
			here,
			1 / 2,
			Random.trunc(Random.gauss(1, 4)),
			Random.int(25, 40),
			Random.gauss(0, 1.25) > 0.5,
			Random.int(12, 22),
			9,
			14
		)
		if math.random() < 0.5 then
			Biometrics.sleep(0, 300, "left")
		end
	end
end

-- Returns the tab it ends on.
local function open_tab_between(async: boolean?, first: number, last: number): number
	local shown = SidePanels.current()
	local tab = Random.int(first, last)
	if Random.chance(0.5) then
		open_tab(async, tab, shown)
		shown = tab
		pause(async, 0, 2500, "left")
		tab = Random.int(first, last)
	end
	open_tab(async, tab, shown)
	return tab
end

local function random_tab(async: boolean?): number
	Log.log("Antiban", "Random Tab")
	if Biometrics.random_boolean(0.8) then
		return open_tab_between(async, SidePanels.COMBAT_INTERFACE, SidePanels.MAGIC_SPELLBOOK)
	end
	return open_tab_between(async, SidePanels.SIDE_CHANNELS, SidePanels.MUSIC)
end

function Tasks.random_tab(async: boolean?)
	random_tab(async)
end

function Tasks.toggle_tab(async: boolean?)
	local current = SidePanels.current()
	if current == nil then
		Log.log("Antiban", "the side panel isn't readable")
		return
	end
	Log.log("Antiban", "Toggling game tabs")
	local last = random_tab(async)
	pause(async, 500, 6000, "left")
	open_tab(async, current, last)
end

-- Hovers a skill in the stats tab for a while, then half the time returns to the previous tab.
function Tasks.hover_skills(async: boolean?)
	if #Tasks.skills == 0 then
		Log.log("Antiban", "hover_skills: no skills declared")
		return
	end
	local skill = pick(Tasks.skills)
	local back = if Biometrics.random_boolean(0.5) then SidePanels.current() else nil
	Log.log("Antiban", `Hover skill: {skill}`)
	local ok = if async then Stats.hover_async(skill) else Stats.hover(skill)
	if ok ~= true then
		Log.log("Antiban", "the skill can't be hovered")
		return
	end
	pause(async, Biometrics.random_mode_integer(3000, 1000, 8000))
	if back ~= nil then
		open_tab(async, back, SidePanels.STATS)
	end
end

local function random_chat_tab(async: boolean?): ChatTabs.Tab
	local tab = pick(CHAT_TABS)
	Log.log("Antiban", `Opening {tab} chat tab`)
	open_chat_tab(async, tab, ChatTabs.active())
	return tab
end

function Tasks.random_chat_tab(async: boolean?)
	random_chat_tab(async)
end

function Tasks.toggle_chat_tab(async: boolean?)
	local active = ChatTabs.active()
	if active == nil or active == "none" then
		Log.log("Antiban", "the chat tabs aren't loaded")
		return
	end
	Log.log("Antiban", "Toggling chat tabs")
	local tab = random_chat_tab(async)
	pause(async, 3000, 5000)
	open_chat_tab(async, active, tab)
end

function Tasks.random_chat_tab_state()
	local tab = pick(CHAT_TABS)
	local state: ChatTabs.State
	if tab == "game" then
		state = "filtered"
	elseif tab == "public" then
		state = pick({ "filtered", "disabled", "hide", "autochat" })
	else
		state = pick({ "enabled", "filtered", "disabled" })
	end
	Log.log("Antiban", `Changing {tab} state to {state}`)
	ChatTabs.set_state(tab, state)
end

function Tasks.hover_make_item(async: boolean?)
	if Make.is_open() ~= true then
		return
	end
	local options = Make.options()
	if options == nil or #options == 0 then
		return
	end
	Log.log("Antiban", "Hovering a random make item")
	move_over(async, pick(options).box)
end

function Tasks.hover_make_quantity(async: boolean?)
	if Make.is_open() ~= true then
		return
	end
	local amounts = Make.amounts()
	if amounts == nil or #amounts == 0 then
		return
	end
	Log.log("Antiban", "Hovering a random make quantity button")
	move_over(async, pick(amounts).box)
	pause(async, 500, 2000, "left")
end

function Tasks.toggle_make_quantity(async: boolean?)
	if Make.is_open() ~= true then
		return
	end
	local amounts = Make.amounts()
	local current = Make.amount()
	if amounts == nil or #amounts == 0 or current == nil then
		return
	end
	if async then
		local labels: { string } = {}
		for _, a in amounts do
			if a.label ~= "X" and a.label ~= current then
				table.insert(labels, a.label)
			end
		end
		if #labels == 0 then
			return
		end
		local label = pick(labels)
		Log.log("Antiban", `Toggling make quantity to {label}`)
		Make.set_amount_async(label)
		Biometrics.sleep_async(1000, 3000, "left")
		Make.set_amount_async(current, true)
		return
	end
	local chosen = pick(amounts)
	Log.log("Antiban", `Toggling make quantity to {chosen.label}`)
	if chosen.label == "X" then
		Make.set_amount(Random.int(1, 26))
	else
		Make.set_amount(chosen.label)
	end
	Biometrics.sleep(1000, 3000, "left")
	if Make.is_open() == true then
		Make.set_amount(current)
	end
end

function Tasks.hover_deposit_item(async: boolean?)
	local boxes = DepositBox.find_item_boundaries()
	if boxes == nil or #boxes == 0 then
		return
	end
	Log.log("Antiban", "Hovering a random deposit box item")
	move_over(async, pick(boxes))
	pause(async, 500, 2000, "left")
end

function Tasks.toggle_deposit_quantity(async: boolean?)
	local current: DepositBox.Quantity? = nil
	for _, q in DEPOSIT_QUANTITIES do
		if DepositBox.quantity_selected(q) == true then
			current = q
			break
		end
	end
	if current == nil then
		return
	end
	local others = {}
	for _, q in DEPOSIT_QUANTITIES do
		if q ~= current then
			table.insert(others, q)
		end
	end
	Log.log("Antiban", `Toggling deposit quantity from {current}`)
	if async then
		DepositBox.select_quantity_async(pick(others))
		Biometrics.sleep_async(1000, 3000, "left")
		DepositBox.select_quantity_async(current, true)
		return
	end
	DepositBox.select_quantity(pick(others))
	Biometrics.sleep(1000, 3000, "left")
	DepositBox.select_quantity(current)
end

function Tasks.hover_random_npc(async: boolean?)
	local npcs = Npcs.find()
	if npcs == nil or #npcs == 0 then
		return
	end
	Log.log("Antiban", "Hovering a random NPC")
	if async then
		Npcs.hover_async(pick(npcs))
	else
		Npcs.hover(pick(npcs))
	end
	pause(async, 1500, 2700)
end

function Tasks.hover_random_player(async: boolean?)
	local players = Players.find()
	if players == nil or #players == 0 then
		return
	end
	Log.log("Antiban", "Hovering a random player")
	if async then
		Players.hover_async(pick(players))
	else
		Players.hover(pick(players))
	end
	pause(async, 1500, 2700)
end

function Tasks.hover_random_ground_item(async: boolean?)
	local items = GroundItems.find()
	if items == nil or #items == 0 then
		return
	end
	Log.log("Antiban", "Hovering a random ground item")
	if async then
		GroundItems.hover_async(pick(items))
	else
		GroundItems.hover(pick(items))
	end
	pause(async, 1500, 2700)
end
-- Like `adjust_zoom` for pitch: a random pitch in range, at least a quarter of the range from the current one.
function Tasks.adjust_pitch()
	local pmin, pmax = Antiban.pitch.min, Antiban.pitch.max
	local min_change = (pmax - pmin) / 4
	if min_change < 1 then
		Log.log("Antiban", "adjust_pitch: the pitch range is too narrow for this task")
		return
	end

	local current = Camera.pitch()
	if current == nil then
		Log.log("Antiban", "the pitch isn't readable")
		return
	end

	local pitch = math.clamp(current, pmin, pmax)
	local new = pitch
	local attempts = 0
	repeat
		attempts += 1
		if attempts > 100 then
			return
		end
		new = math.round(Random.mode(pitch, pmin, pmax))
	until math.abs(pitch - new) > min_change

	Log.log("Antiban", `Adjust pitch: {new}`)
	Camera.set_pitch(new)
end

-- Adjusts the zoom and the pitch, in an order that depends on the biometrics.
function Tasks.adjust_camera()
	if Biometrics.random_boolean(0.5) then
		Tasks.adjust_zoom()
		Tasks.adjust_pitch()
	else
		Tasks.adjust_pitch()
		Tasks.adjust_zoom()
	end
end

function Tasks.lose_focus()
	Log.log("Antiban", "Losing client focus")
	Antiban.lose_focus()
end

function Tasks.random_camera_task()
	local r = Random.int(0, 9)
	if r <= 1 then
		Tasks.adjust_zoom()
	elseif r <= 3 then
		Tasks.adjust_pitch()
	elseif r <= 4 then
		Tasks.adjust_camera()
	elseif r <= 7 then
		Tasks.small_camera_rotation()
	else
		Tasks.large_camera_rotation()
	end
end

function Tasks.random_mouse_task()
	local r = Random.int(0, 9)
	if r <= 1 then
		Tasks.random_right_click()
	elseif r <= 4 then
		Tasks.large_random_mouse()
	else
		Tasks.small_random_mouse()
	end
end

function Tasks.random_game_tab_task(async: boolean?)
	local r = Random.int(0, 12)
	if r <= 3 then
		Tasks.random_tab(async)
	elseif r <= 9 then
		Tasks.toggle_tab(async)
	end
end

function Tasks.random_make_task(async: boolean?)
	local r = Random.int(0, 10)
	if r <= 3 then
		Tasks.hover_make_item(async)
	elseif r <= 6 then
		Tasks.hover_make_quantity(async)
	elseif r <= 8 then
	else
		Tasks.toggle_make_quantity(async)
	end
end

function Tasks.random_chat_task(async: boolean?)
	local r = Random.int(0, 29)
	if r <= 5 then
		Tasks.random_chat_tab(async)
	elseif r <= 17 then
		Tasks.toggle_chat_tab(async)
	elseif r <= 24 then
	else
		Tasks.random_chat_tab_state()
	end
end

function Tasks.random_deposit_task(async: boolean?)
	local r = Random.int(0, 10)
	if r <= 3 then
		Tasks.hover_deposit_item(async)
	elseif r <= 8 then
	else
		Tasks.toggle_deposit_quantity(async)
	end
end

Tasks.TASKS = {
	HoverSkills = Tasks.hover_skills,
	SmallRandomMouse = Tasks.small_random_mouse,
	LargeRandomMouse = Tasks.large_random_mouse,
	TinyCameraRotation = Tasks.tiny_camera_rotation,
	SmallCameraRotation = Tasks.small_camera_rotation,
	TinyZoomChange = Tasks.tiny_zoom_change,
	TinyPitchChange = Tasks.tiny_pitch_change,
	LargeCameraRotation = Tasks.large_camera_rotation,
	LoseFocus = Tasks.lose_focus,
	HoverMakeItem = Tasks.hover_make_item,
	HoverMakeQuantity = Tasks.hover_make_quantity,
	ToggleMakeQuantity = Tasks.toggle_make_quantity,
	RandomMakeTask = Tasks.random_make_task,
	RandomChatTab = Tasks.random_chat_tab,
	ToggleChatTab = Tasks.toggle_chat_tab,
	RandomChatTabState = Tasks.random_chat_tab_state,
	RandomTab = Tasks.random_tab,
	ToggleTab = Tasks.toggle_tab,
	HoverDepositItem = Tasks.hover_deposit_item,
	ToggleDepositQuantity = Tasks.toggle_deposit_quantity,
	RandomDepositTask = Tasks.random_deposit_task,
	RandomRightClick = Tasks.random_right_click,
	AdjustZoom = Tasks.adjust_zoom,
	AdjustPitch = Tasks.adjust_pitch,
	AdjustCamera = Tasks.adjust_camera,
	AdjustMinimapZoom = Tasks.adjust_minimap_zoom,
	Swivel = Tasks.swivel,
	HoverRandomNPC = Tasks.hover_random_npc,
	HoverRandomPlayer = Tasks.hover_random_player,
	HoverRandomGrounditem = Tasks.hover_random_ground_item,
	RandomCameraTask = Tasks.random_camera_task,
	RandomMouseTask = Tasks.random_mouse_task,
	RandomGameTabTask = Tasks.random_game_tab_task,
	RandomChatTask = Tasks.random_chat_task,
}

Tasks.WALKING_TASKS = {
	SmallRandomMouse = Tasks.small_random_mouse,
	LargeRandomMouse = Tasks.large_random_mouse,
	TinyCameraRotation = Tasks.tiny_camera_rotation,
	SmallCameraRotation = Tasks.small_camera_rotation,
	TinyZoomChange = Tasks.tiny_zoom_change,
	TinyPitchChange = Tasks.tiny_pitch_change,
	LoseFocus = Tasks.lose_focus,
	RandomChatTab = Tasks.random_chat_tab,
	ToggleChatTab = Tasks.toggle_chat_tab,
	RandomChatTabState = Tasks.random_chat_tab_state,
	RandomTab = Tasks.random_tab,
	ToggleTab = Tasks.toggle_tab,
	RandomRightClick = Tasks.random_right_click,
	AdjustZoom = Tasks.adjust_zoom,
	AdjustPitch = Tasks.adjust_pitch,
	AdjustCamera = Tasks.adjust_camera,
	AdjustMinimapZoom = Tasks.adjust_minimap_zoom,
	Swivel = Tasks.swivel,
	HoverRandomNPC = Tasks.hover_random_npc,
	HoverRandomPlayer = Tasks.hover_random_player,
	HoverRandomGrounditem = Tasks.hover_random_ground_item,
	RandomCameraTask = Tasks.random_camera_task,
	RandomMouseTask = Tasks.random_mouse_task,
	RandomGameTabTask = Tasks.random_game_tab_task,
	RandomChatTask = Tasks.random_chat_task,
}

-- `Camera.face` sometimes adjusts the zoom and pitch with this instead of raising the pitch.
Camera.face_task = Tasks.adjust_camera

return Tasks
