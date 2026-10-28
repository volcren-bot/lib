--!strict
-- Checks async keys, the middle button and the wheel against a live client, with the camera as the witness. Needs the viewport free of interfaces.
local Camera = require("../main/camera")
local Geometry = require("../utils/math/geometry")
local Host = require("../host")
local Keyboard = require("../utils/input/keyboard")
local Mouse = require("../utils/input/mouse")

local Point = Geometry.Point
local keys = Keyboard.keys

local function check(name: string, ok: boolean)
	print(`[{if ok then "ok" else "FAIL"}] {name}`)
end

local function yaw(): number
	return Camera.yaw() or 0
end

local function turned(from: number): number
	return math.abs(((yaw() - from + Camera.TURN / 2) % Camera.TURN) - Camera.TURN / 2)
end

local function settle_yaw(): number
	local last = yaw()
	for _ = 1, 40 do
		Host.sleep(80)
		local now = yaw()
		if now == last then
			break
		end
		last = now
	end
	return last
end

local conn = Host.connection()
local spot = Point.new(math.floor(conn.width * 0.4), math.floor(conn.height * 0.4))
local start_yaw = yaw()
local start_pitch = Camera.pitch() or 0
local start_zoom = Camera.zoom() or 0
Mouse.teleport(spot)
Host.sleep(200)

-- A held key turns the camera while the script runs, and is released when the queue is cancelled.
Keyboard.key_down_async(keys.LEFT)
Host.sleep(400)
check("key held turns the camera", turned(start_yaw) > 10)
Keyboard.cancel()
local after_cancel = settle_yaw()
Host.sleep(300)
check("cancel released the key", settle_yaw() == after_cancel)

-- down, pause, up as one queued press; and cancelling in the pause still releases.
local before = yaw()
Keyboard.key_down_async(keys.RIGHT)
Host.sleep_async(5000)
Keyboard.key_up_async(keys.RIGHT)
Host.sleep(300)
check("key down is in effect during the pause", Keyboard.busy() and turned(before) > 5)
local started = Host.time()
Keyboard.cancel()
check("cancel cuts the pause short", Host.time() - started < 1000)
local released = settle_yaw()
Host.sleep(300)
check("pause cancel released the key", settle_yaw() == released)

-- A blocking key press takes over from a held async key and leaves nothing pressed.
before = settle_yaw()
Keyboard.key_down_async(keys.LEFT)
Host.sleep(300)
Mouse.move(spot, true) -- blocking input cancels, which releases LEFT
local stopped = settle_yaw()
Host.sleep(300)
check("blocking input released the held key", settle_yaw() == stopped and turned(before) > 5)

-- Middle button drag: moves while held rotate the camera; cancelling releases the button.
before = settle_yaw()
Mouse.hold_async("middle")
Mouse.move_async(Point.new(spot.x + 220, spot.y), true)
Host.sleep(150)
Mouse.cancel()
Host.sleep(150)
local dragged = settle_yaw()
check("middle drag turned the camera", dragged ~= before)
-- If the button were still down, this move would turn the camera more.
Mouse.teleport(Point.new(spot.x - 150, spot.y))
Host.sleep(300)
check("cancel released the middle button", settle_yaw() == dragged)

-- Scroll changes the zoom, if the client lets a blocking scroll do that at all.
Mouse.teleport(spot)
Host.sleep(200)
local zoom = Camera.zoom() or 0
Mouse.scroll(2, true)
Host.sleep(400)
if (Camera.zoom() or 0) == zoom then
	print("[skip] scroll_async: a blocking scroll doesn't change the zoom on this client either")
else
	zoom = Camera.zoom() or 0
	Mouse.scroll_async(2, false)
	Mouse.wait()
	Host.sleep(400)
	check("scroll_async zooms", (Camera.zoom() or 0) ~= zoom)
end

-- Put the camera back.
Camera.set_zoom(start_zoom)
Camera.set_angles(start_yaw, start_pitch)
