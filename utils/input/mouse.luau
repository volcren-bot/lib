--!strict
local Host = require("../../host")
local Random = require("../math/random")
local Geometry = require("../math/geometry")
local Log = require("../log")
local connection = Host.connection
local move = Host.move
local wind_mouse = Host.wind_mouse
local move_async = Host.move_async
local wind_mouse_async = Host.wind_mouse_async
local click_async = Host.click_async
local mouse_down_async = Host.mouse_down_async
local mouse_up_async = Host.mouse_up_async
local scroll_async = Host.scroll_async
local sleep_async = Host.sleep_async
local input_busy = Host.input_busy
local input_wait = Host.input_wait
local input_cancel = Host.input_cancel
local mouse_down = Host.mouse_down
local mouse_up = Host.mouse_up
local scroll = Host.scroll
local sleep = Host.sleep
local time = Host.time
local Point = Geometry.Point
local Box = Geometry.Box
local Circle = Geometry.Circle
local Quad = Geometry.Quad
type Point = Geometry.Point
type Box = Geometry.Box
type Circle = Geometry.Circle
type Quad = Geometry.Quad
type Area = Host.Area

export type Button = "left" | "right" | "middle"
export type Distribution = "random" | "gauss" | "skewed" | "rowp"
export type Target = Point | Box | Circle | Quad | Area

local Mouse = {}

Mouse.speed = 14
Mouse.wind = 5
Mouse.gravity = 10
Mouse.timeout = 15000
Mouse.press_min = 40
Mouse.press_max = 220
Mouse.distribution = "gauss" :: Distribution
Mouse.miss_chance = 0
Mouse.can_idle = true
Mouse.idle_interval = 0
Mouse.use_teleport = false

local idle_progress = 0
local idle_goal = 0

function Mouse.position(): Point?
	local conn = connection()
	if conn.mouse_x < 0 then
		return nil
	end
	return Point.new(conn.mouse_x, conn.mouse_y)
end

-- wind_mouse plans 100 + 14 * sqrt(distance) / (speed / 10) ms for a move, give or take 22%.
local function planned_ms(distance: number): number
	return 100 + 14 * math.sqrt(distance) / (math.clamp(Mouse.speed, 2, 30) / 10)
end

-- How long moves really take next to their plan, learned from the moves made so far.
local travel_scale = 0.9

-- How long a move from `from` (the mouse by default) to `to` usually takes, in milliseconds.
function Mouse.travel_ms(to: Point, from: Point?): number
	local start = from or Mouse.position()
	if start == nil or Mouse.use_teleport then
		return 0
	end
	local distance = Point.distance(start, to)
	if distance < 2 then
		return 0
	end
	return planned_ms(distance) * travel_scale
end

function Mouse.teleport(p: Point)
	move(math.round(p.x), math.round(p.y))
end

function Mouse.hold(button: Button?)
	mouse_down(button)
end

function Mouse.release(button: Button?)
	mouse_up(button)
end

function Mouse.idle()
	local ms = Random.trunc(Random.left(1000, 20000))
	Log.log("Mouse", `Idle: {ms} ms`)
	sleep(ms)
end

function Mouse.miss(destination: Point): Point
	local from = Mouse.position()
	if from == nil then
		return destination
	end
	local range = Random.trunc(Point.distance(from, destination) ^ 0.80)
	local miss = Random.mode(0.9, 0.1, 1.5)
	local at = Point.new(
		Random.trunc((1 - miss) * from.x + miss * destination.x),
		Random.trunc((1 - miss) * from.y + miss * destination.y)
	)
	return Point.random(at, range)
end

local function move_to(destination: Point)
	if Mouse.use_teleport then
		Mouse.teleport(destination)
		return
	end

	if Mouse.can_idle and Mouse.idle_interval > 0 then
		local start = Mouse.position()
		local conn = connection()
		if start and conn.width > 0 and conn.height > 0 then
			local interval = Mouse.idle_interval
			if idle_progress == 0 then
				idle_goal = Random.gauss(interval, interval * 0.20)
			elseif idle_progress > idle_goal then
				Mouse.idle()
				idle_progress = 0
				if Random.chance(0.1) then
					idle_goal = Random.gauss(interval / 2, interval / 2 * 0.20)
				else
					idle_goal = Random.gauss(interval, interval * 0.20)
				end
			end
			idle_progress += Point.distance(start, destination) / math.sqrt(conn.width ^ 2 + conn.height ^ 2)
		end
	end

	if Random.chance(Mouse.miss_chance) then
		move_to(Mouse.miss(destination))
		if Random.chance(0.25) then
			Random.sleep(0, 5000, "left")
		end
	end

	local start = Mouse.position()
	local started = time()
	wind_mouse(math.round(destination.x), math.round(destination.y), {
		speed = Mouse.speed,
		wind = Mouse.wind,
		gravity = Mouse.gravity,
		timeout = Mouse.timeout,
	})
	local distance = if start then Point.distance(start, destination) else 0
	if distance >= 20 then
		local ratio = (time() - started) / planned_ms(distance)
		travel_scale = math.clamp(travel_scale * 0.8 + ratio * 0.2, 0.5, 2)
	end
end

local function shape(t: Target): (string, any)
	local any_t = t :: any
	if any_t.radius ~= nil then
		return "circle", any_t
	elseif any_t.top ~= nil then
		return "quad", any_t
	elseif any_t.x1 ~= nil then
		return "box", any_t
	elseif any_t.width ~= nil then
		return "box", Box.from_area(any_t)
	end
	return "point", any_t
end

local SHAPES = { box = Box, circle = Circle, quad = Quad }

-- Where in the target a move goes, or nil when the mouse is already inside it and the move isn't forced.
local function pick(target: Target, forced: boolean?, distribution: Distribution?): Point?
	local kind, s = shape(target)
	if kind == "point" then
		return s
	end

	local Shape = (SHAPES :: any)[kind]
	local from = Mouse.position()
	if not forced and from and Shape.contains(s, from) then
		return nil
	end

	local d = distribution or Mouse.distribution
	if from == nil and (d == "skewed" or d == "rowp") then
		d = "gauss"
	end
	if d == "random" then
		return Shape.random_point(s)
	elseif d == "skewed" then
		return Shape.random_skewed_point(s, from)
	elseif d == "rowp" then
		return Shape.random_weighted_point(s, from)
	end
	return Shape.random_point_center(s)
end

function Mouse.move(target: Target, forced: boolean?, distribution: Distribution?)
	local p = pick(target, forced, distribution)
	if p then
		move_to(p)
	end
end

-- Queues the move, with no misses or idling, and returns where it goes (nil when the mouse is already there).
local function queue_move(target: Target, forced: boolean?, distribution: Distribution?): Point?
	local p = pick(target, forced, distribution)
	if p == nil then
		return nil
	end
	local x, y = math.round(p.x), math.round(p.y)
	if Mouse.use_teleport then
		move_async(x, y)
	else
		wind_mouse_async(x, y, {
			speed = Mouse.speed,
			wind = Mouse.wind,
			gravity = Mouse.gravity,
			timeout = Mouse.timeout,
		})
	end
	return Point.new(x, y)
end

-- Starts a move and returns at once; other input, `Mouse.cancel` or a minimenu read stops it where it got to.
function Mouse.move_async(target: Target, forced: boolean?, distribution: Distribution?)
	queue_move(target, forced, distribution)
end

-- Starts a click, after the move if there is a target, and returns at once; false if the mouse isn't over the client.
function Mouse.click_async(target: Target?, button: Button?, forced: boolean?, distribution: Distribution?): boolean
	local at: Point? = nil
	if target ~= nil then
		at = queue_move(target, forced, distribution)
	end
	at = at or Mouse.position()
	if at == nil then
		Log.log("Mouse", "click_async: the mouse isn't over the client and there is no target.")
		return false
	end
	click_async(math.round(at.x), math.round(at.y), button, Random.trunc(Random.left(Mouse.press_min, Mouse.press_max)))
	return true
end

-- Queues pressing a button and keeping it held. Cancelling (or the script ending) releases it.
function Mouse.hold_async(button: Button?)
	mouse_down_async(button)
end

function Mouse.release_async(button: Button?)
	mouse_up_async(button)
end

-- Queues a drag: press, move to the target, release. Cancelling in the middle still releases the button.
function Mouse.drag_async(target: Target, button: Button?)
	mouse_down_async(button)
	sleep_async(Random.int(40, 90))
	queue_move(target, true)
	sleep_async(Random.int(30, 70))
	mouse_up_async(button)
end

-- Queues turning the mouse wheel, after the move to the target if there is one.
function Mouse.scroll_async(amount: number, down: boolean, target: Target?, forced: boolean?)
	if target ~= nil then
		queue_move(target, forced)
	end
	scroll_async(if down then amount else -amount)
end

-- Whether async mouse input is still running or queued.
function Mouse.busy(): boolean
	return input_busy()
end

-- Waits for async input to finish. False if one failed (the reason is printed).
function Mouse.wait(): boolean
	local err = input_wait()
	if err then
		Log.log("Mouse", `async input failed: {err}`)
		return false
	end
	return true
end

-- Stops async input and drops what was queued; `Mouse.position` may trail a frame or two.
function Mouse.cancel()
	input_cancel()
end

function Mouse.click(target: Target?, button: Button?, forced: boolean?, distribution: Distribution?)
	if target ~= nil then
		Mouse.move(target, forced, distribution)
	end
	mouse_down(button)
	sleep(Random.trunc(Random.left(Mouse.press_min, Mouse.press_max)))
	mouse_up(button)
end

function Mouse.drag(target: Target, button: Button?)
	Mouse.hold(button)
	Mouse.move(target)
	Mouse.release(button)
end

function Mouse.scroll(amount: number, down: boolean, target: Target?, forced: boolean?)
	if target ~= nil then
		Mouse.move(target, forced)
	end
	scroll(if down then amount else -amount)
end

return Mouse
