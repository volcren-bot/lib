--!strict
local Host = require("../host")
local game_state = Host.game_state
local sleep = Host.sleep
local time = Host.time
type CameraState = Host.CameraState
type Tile = Host.Tile
local Geometry = require("../utils/math/geometry")
local Keyboard = require("../utils/input/keyboard")
local Mouse = require("../utils/input/mouse")
local Random = require("../utils/math/random")
local Box = Geometry.Box
local Point = Geometry.Point
type Box = Geometry.Box
type Point = Geometry.Point
local Biometrics = require("./antiban/biometrics")
local Log = require("../utils/log")
local Toplevel = require("./interfaces/mainscreen/toplevel")

export type Method = "mouse" | "keys"

local Camera = {}

Camera.TURN = 16384
Camera.PITCH_MIN = 1024
Camera.PITCH_MAX = 3064
Camera.ZOOM_MIN = 128
Camera.ZOOM_MAX = 896
Camera.ZOOM_STEP = 24

Camera.method = "mouse" :: Method
Camera.tolerance = 64
Camera.zoom_tolerance = 12

-- `face` turns just enough to keep things within FACE_LIMIT degrees of the camera, with a distance chance (`face_chance`).
Camera.FACE_LIMIT = 70
Camera.FACE_PITCH_SLACK = 200
Camera.FACE_CHANCES = { { 2, 0.1 }, { 12, 0.8 }, { 20, 1 } }
Camera.FACE_TASK_CHANCE = 0.05
Camera.face_task = nil :: (() -> ())?
Camera.face_enabled = true

local YAW_PER_PIXEL = 16.4
local PITCH_PER_PIXEL = 15.4

function Camera.state(): CameraState?
	local state = game_state()
	if state.camera == nil then
		return nil
	end
	return state.camera
end

function Camera.yaw_to_degrees(yaw: number): number
	return (Camera.TURN - yaw) % Camera.TURN * 360 / Camera.TURN
end

function Camera.degrees_to_yaw(degrees: number): number
	return (Camera.TURN - math.round(degrees * Camera.TURN / 360)) % Camera.TURN
end

function Camera.pitch_to_degrees(pitch: number): number
	return pitch * 360 / Camera.TURN
end

function Camera.degrees_to_pitch(degrees: number): number
	return math.round(degrees * Camera.TURN / 360)
end

function Camera.yaw(): number?
	local camera = Camera.state()
	return if camera then camera.yaw else nil
end

function Camera.yaw_degrees(): number?
	local yaw = Camera.yaw()
	return if yaw then Camera.yaw_to_degrees(yaw) else nil
end

function Camera.pitch(): number?
	local camera = Camera.state()
	return if camera then camera.pitch else nil
end

function Camera.pitch_degrees(): number?
	local pitch = Camera.pitch()
	return if pitch then Camera.pitch_to_degrees(pitch) else nil
end

function Camera.zoom(): number?
	local camera = Camera.state()
	if camera == nil then
		return nil
	end
	if camera.zoom == nil then
		return nil
	end
	return camera.zoom
end

local function yaw_difference(from: number, to: number): number
	local d = (to - from) % Camera.TURN
	return if d > Camera.TURN / 2 then d - Camera.TURN else d
end

local function differences(camera: CameraState, yaw: number?, pitch: number?): (number, number)
	return if yaw then yaw_difference(camera.yaw, yaw) else 0, if pitch then pitch - camera.pitch else 0
end

local function settle(): CameraState?
	local last = Camera.state()
	for _ = 1, 40 do
		sleep(Random.int(30, 50))
		local now = Camera.state()
		if now == nil or last == nil then
			return now
		end
		if now.yaw == last.yaw and now.pitch == last.pitch then
			return now
		end
		last = now
	end
	return last
end

local function drag_start(dx: number, dy: number): Point?
	local view = Toplevel.viewport()
	if view == nil then
		return nil
	end
	local margin = 40
	local x1 = math.max(view.x1 + margin, view.x1 + margin - dx)
	local x2 = math.min(view.x2 - margin, view.x2 - margin - dx)
	local y1 = math.max(view.y1 + margin, view.y1 + margin - dy)
	local y2 = math.min(view.y2 - margin, view.y2 - margin - dy)
	if x1 > x2 or y1 > y2 then
		return nil
	end
	local blockers = Toplevel.blockers() or {}
	for _ = 1, 20 do
		local p = Box.random_point_center(Box.new(x1, y1, x2, y2))
		local finish = Point.new(p.x + dx, p.y + dy)
		if Toplevel.is_visible(p, view, blockers) and Toplevel.is_visible(finish, view, blockers) then
			return p
		end
	end
	return nil
end

-- Where a middle-button drag starts and how far it goes to reach `yaw` and `pitch`; start is nil without room.
local function plan_drag(camera: CameraState, yaw: number?, pitch: number?): (Point?, number, number)
	local state = game_state()
	local view = Toplevel.viewport()
	if view == nil then
		return nil, 0, 0
	end
	local scale = state.ui_scale or 1
	local dyaw, dpitch = differences(camera, yaw, pitch)
	local dx = -dyaw / YAW_PER_PIXEL * scale
	local dy = dpitch / PITCH_PER_PIXEL * scale
	local limit_x, limit_y = (view.x2 - view.x1) / 2, (view.y2 - view.y1) / 2
	local shrink = math.min(1, limit_x / math.max(math.abs(dx), 1), limit_y / math.max(math.abs(dy), 1))
	dx = math.round(dx * shrink)
	dy = math.round(dy * shrink)
	return drag_start(dx, dy), dx, dy
end

local function drag(camera: CameraState, yaw: number?, pitch: number?): boolean
	local start, dx, dy = plan_drag(camera, yaw, pitch)
	if start == nil then
		return false
	end
	Mouse.move(start)
	Mouse.hold("middle")
	sleep(Random.int(40, 90))
	Mouse.move(Point.new(start.x + dx, start.y + dy))
	sleep(Random.int(30, 70))
	Mouse.release("middle")
	return true
end

local function hold_key(yaw: number?, pitch: number?): boolean
	local camera = Camera.state()
	if camera == nil then
		return false
	end
	local dyaw, dpitch = differences(camera, yaw, pitch)
	local keys = Keyboard.keys
	local key: number
	local remaining: (CameraState) -> number
	if math.abs(dyaw) >= math.abs(dpitch) then
		key = if dyaw > 0 then keys.RIGHT else keys.LEFT
		local sign = if dyaw > 0 then 1 else -1
		remaining = function(c: CameraState): number
			return sign * yaw_difference(c.yaw, yaw :: number)
		end
	else
		key = if dpitch > 0 then keys.UP else keys.DOWN
		local sign = if dpitch > 0 then 1 else -1
		remaining = function(c: CameraState): number
			return sign * ((pitch :: number) - c.pitch)
		end
	end

	Keyboard.key_down(key)
	local started = time()
	local last, last_time = remaining(camera), time()
	local speed = 0
	while time() - started < 5000 do
		sleep(Random.int(8, 16))
		local now = Camera.state()
		if now == nil then
			break
		end
		local left, now_time = remaining(now), time()
		if now_time > last_time then
			speed = math.max(speed, (last - left) / (now_time - last_time))
		end
		if left <= Camera.tolerance / 2 + speed * 60 then
			break
		end
		last = left
		last_time = now_time
	end
	Keyboard.key_up(key)
	return true
end

local function turn(yaw: number?, pitch: number?, method: Method?): boolean
	if pitch then
		pitch = math.clamp(pitch, Camera.PITCH_MIN, Camera.PITCH_MAX)
	end
	local how = method or Camera.method
	for _ = 1, 6 do
		local camera = settle()
		if camera == nil then
			return false
		end
		local dyaw, dpitch = differences(camera, yaw, pitch)
		if math.abs(dyaw) <= Camera.tolerance and math.abs(dpitch) <= Camera.tolerance then
			return true
		end
		local ok
		if how == "keys" then
			ok = hold_key(yaw, pitch)
		else
			ok = drag(camera, yaw, pitch)
		end
		if not ok then
			return false
		end
		Random.sleep(60, 200)
	end
	local camera = settle()
	if camera then
		local dyaw, dpitch = differences(camera, yaw, pitch)
		if math.abs(dyaw) <= Camera.tolerance and math.abs(dpitch) <= Camera.tolerance then
			return true
		end
	end
	Log.log("Camera", "the camera didn't reach the angle")
	return false
end

function Camera.set_yaw(yaw: number, method: Method?): boolean
	return turn(yaw % Camera.TURN, nil, method)
end

function Camera.set_yaw_degrees(degrees: number, method: Method?): boolean
	return Camera.set_yaw(Camera.degrees_to_yaw(degrees), method)
end

function Camera.set_pitch(pitch: number, method: Method?): boolean
	return turn(nil, pitch, method)
end

function Camera.set_pitch_degrees(degrees: number, method: Method?): boolean
	return Camera.set_pitch(Camera.degrees_to_pitch(degrees), method)
end

function Camera.set_angles(yaw: number, pitch: number, method: Method?): boolean
	return turn(yaw % Camera.TURN, pitch, method)
end

-- Queues a middle-button drag towards `yaw` and `pitch` and returns at once; open loop, false when it can't drag.
local function turn_async(yaw: number?, pitch: number?): boolean
	if pitch then
		pitch = math.clamp(pitch, Camera.PITCH_MIN, Camera.PITCH_MAX)
	end
	local camera = Camera.state()
	if camera == nil then
		return false
	end
	local dyaw, dpitch = differences(camera, yaw, pitch)
	if math.abs(dyaw) <= Camera.tolerance and math.abs(dpitch) <= Camera.tolerance then
		return true
	end
	local start, dx, dy = plan_drag(camera, yaw, pitch)
	if start == nil then
		return false
	end
	Mouse.move_async(start, true)
	Mouse.drag_async(Point.new(start.x + dx, start.y + dy), "middle")
	return true
end

function Camera.set_yaw_async(yaw: number): boolean
	return turn_async(yaw % Camera.TURN, nil)
end

function Camera.set_yaw_degrees_async(degrees: number): boolean
	return Camera.set_yaw_async(Camera.degrees_to_yaw(degrees))
end

function Camera.set_pitch_async(pitch: number): boolean
	return turn_async(nil, pitch)
end

function Camera.set_angles_async(yaw: number, pitch: number): boolean
	return turn_async(yaw % Camera.TURN, pitch)
end

-- Queues scrolls from the current zoom towards `zoom` and returns at once; open loop, one notch is about ZOOM_STEP.
function Camera.set_zoom_async(zoom: number): boolean
	local target = math.clamp(zoom, Camera.ZOOM_MIN, Camera.ZOOM_MAX)
	local current = Camera.zoom()
	if current == nil then
		return false
	end
	local diff = target - current
	if math.abs(diff) <= Camera.zoom_tolerance then
		return true
	end

	local view = Toplevel.viewport()
	if view == nil then
		return false
	end
	local blockers = Toplevel.blockers() or {}
	local here = Mouse.position()
	local over: Point? = nil
	if here == nil or not Toplevel.is_visible(here, view, blockers) then
		local w, h = view.x2 - view.x1, view.y2 - view.y1
		local spot = Toplevel.visible_point(
			Box.new(view.x1 + w * 0.25, view.y1 + h * 0.25, view.x2 - w * 0.25, view.y2 - h * 0.25)
		)
		if spot == nil then
			return false
		end
		over = Point.random(spot, 30)
	end
	Mouse.scroll_async(math.max(1, math.round(math.abs(diff) / Camera.ZOOM_STEP)), diff < 0, over)
	return true
end

function Camera.set_zoom(zoom: number): boolean
	local target = math.clamp(zoom, Camera.ZOOM_MIN, Camera.ZOOM_MAX)
	local current = Camera.zoom()
	if current == nil then
		return false
	end
	if math.abs(target - current) <= Camera.zoom_tolerance then
		return true
	end

	local view = Toplevel.viewport()
	if view == nil then
		return false
	end
	local blockers = Toplevel.blockers() or {}
	local here = Mouse.position()
	if here == nil or not Toplevel.is_visible(here, view, blockers) then
		local w, h = view.x2 - view.x1, view.y2 - view.y1
		local spot = Toplevel.visible_point(
			Box.new(view.x1 + w * 0.25, view.y1 + h * 0.25, view.x2 - w * 0.25, view.y2 - h * 0.25)
		)
		if spot == nil then
			return false
		end
		Mouse.move(Point.random(spot, 30))
	end

	local stuck = 0
	for _ = 1, 80 do
		local diff = target - current
		if math.abs(diff) <= Camera.zoom_tolerance then
			return true
		end
		local notches = math.clamp(math.round(math.abs(diff) / Camera.ZOOM_STEP), 1, 4)
		Mouse.scroll(notches, diff < 0)
		Random.sleep(80, 180)
		local now = Camera.zoom()
		if now == nil then
			return false
		end
		stuck = if now == current then stuck + 1 else 0
		if stuck >= 3 then
			Log.log("Camera", `the zoom stopped at {now}`)
			return false
		end
		current = now
	end
	Log.log("Camera", "the camera didn't reach the zoom")
	return false
end

-- The chance `face` turns for a thing `tiles` away, from FACE_CHANCES.
function Camera.face_chance(tiles: number): number
	local points = Camera.FACE_CHANCES
	if tiles <= points[1][1] then
		return points[1][2]
	end
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		if tiles <= b[1] then
			return a[2] + (b[2] - a[2]) * (tiles - a[1]) / (b[1] - a[1])
		end
	end
	return points[#points][2]
end

-- The yaw `face` turns to, or nil when `tile` is already within FACE_LIMIT of the camera's direction.
local function facing_yaw(camera: CameraState, tile: Tile, me: Tile): number?
	local facing = Camera.yaw_to_degrees(camera.yaw)
	local bearing = math.deg(math.atan2(tile.x - me.x, tile.y - me.y))
	local ahead = (bearing - facing + 180) % 360 - 180
	if math.abs(ahead) <= Camera.FACE_LIMIT then
		return nil
	end
	local sign = if ahead < 0 then -1 else 1
	local left_off = Random.right(0, Camera.FACE_LIMIT)
	return Camera.degrees_to_yaw(facing + ahead - sign * left_off)
end

-- Turns the camera so `tile` shows in the upper half of the screen; `force` skips the distance chance. Returns whether it turned.
function Camera.face(tile: Tile, force: boolean?): boolean
	if not Camera.face_enabled then
		return false
	end
	local state = game_state()
	local me, camera = state.position, state.camera
	if me == nil or camera == nil then
		return false
	end
	if tile.x == me.x and tile.y == me.y then
		return false
	end
	local yaw = facing_yaw(camera, tile, me)
	if yaw == nil then
		return false
	end
	local chance = Camera.face_chance(math.max(math.abs(tile.x - me.x), math.abs(tile.y - me.y)))
	if not force and chance < 1 and not Biometrics.random_boolean(chance) then
		return false
	end
	local task = Camera.face_task
	if task and Biometrics.random_boolean(Camera.FACE_TASK_CHANCE) then
		local ok = Camera.set_yaw(yaw)
		task()
		return ok
	end
	if camera.pitch < Camera.PITCH_MAX - Camera.FACE_PITCH_SLACK then
		return Camera.set_angles(yaw, Camera.PITCH_MAX)
	end
	return Camera.set_yaw(yaw)
end

return Camera
