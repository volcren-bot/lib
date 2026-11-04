--!strict
-- Checks the async input against a live client, logged in with the viewport free of interfaces: mouse moves and cancel, keys and the
-- middle button with the camera as the witness, and the async twins of the interface helpers with the antiban tasks. Prints ok or FAIL per check.
local Camera = require("@lib/main/camera")
local ChatTabs = require("@lib/main/interfaces/chatbox/chat_tabs")
local Geometry = require("@lib/utils/math/geometry")
local Host = require("@lib/host")
local Keyboard = require("@lib/utils/input/keyboard")
local Mouse = require("@lib/utils/input/mouse")
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")
local Stats = require("@lib/main/interfaces/gametabs/stats")
local Tasks = require("@lib/main/antiban/antiban_tasks")

local Point = Geometry.Point
local keys = Keyboard.keys

local function check(name: string, ok: boolean)
	print(`[{if ok then "ok" else "FAIL"}] {name}`)
end

local conn = Host.connection()

-- Mouse: async moves, cancel, blocking moves taking over, menu reads, queued moves.
local function mouse_checks()
	print("-- mouse")
	local far = Point.new(math.floor(conn.width * 0.8), math.floor(conn.height * 0.3))
	local near = Point.new(math.floor(conn.width * 0.2), math.floor(conn.height * 0.3))

	Mouse.teleport(near)
	Host.sleep(100)
	local started = Host.time()
	Mouse.move_async(far)
	check("move_async returns at once", Host.time() - started < 50)
	check("busy while moving", Mouse.busy())
	Host.sleep(60)
	local midway = Mouse.position()
	check("mouse is on its way", midway ~= nil and Point.distance(midway, near) > 5 and Point.distance(midway, far) > 5)
	check("wait succeeds", Mouse.wait())
	Host.sleep(100)
	local arrived = Mouse.position()
	check("arrived", arrived ~= nil and Point.distance(arrived, far) <= 3)
	check("not busy after", not Mouse.busy())

	Mouse.teleport(near)
	Host.sleep(100)
	Mouse.move_async(far)
	Host.sleep(60)
	Mouse.cancel()
	Host.sleep(100) -- the client still processes the moves posted before the cancel
	local stopped = Mouse.position()
	Host.sleep(300)
	local later = Mouse.position()
	check("cancel stops the move", stopped ~= nil and later ~= nil and Point.distance(stopped, later) < 1)
	check("stopped short", later ~= nil and Point.distance(later, far) > 5)

	Mouse.teleport(near)
	Host.sleep(100)
	Mouse.move_async(far)
	Host.sleep(60)
	Mouse.move(near)
	Host.sleep(100)
	local back = Mouse.position()
	check("blocking move takes over", back ~= nil and Point.distance(back, near) <= 3 and not Mouse.busy())
	Host.sleep(300)
	local still = Mouse.position()
	check("async move doesn't resume", still ~= nil and Point.distance(still, near) <= 3)

	Mouse.move_async(far)
	Host.sleep(60)
	Host.menu()
	Host.sleep(100)
	local at_menu = Mouse.position()
	check("menu read cancels", not Mouse.busy())
	Host.sleep(300)
	local after_menu = Mouse.position()
	check(
		"mouse stays put after the read",
		at_menu ~= nil and after_menu ~= nil and Point.distance(at_menu, after_menu) < 1
	)

	Mouse.teleport(near)
	Host.sleep(100)
	local mid = Point.new((near.x + far.x) // 2, near.y + 80)
	Mouse.move_async(mid)
	Mouse.move_async(far)
	check("queued moves finish", Mouse.wait())
	Host.sleep(100)
	local end_at = Mouse.position()
	check("ends at the last target", end_at ~= nil and Point.distance(end_at, far) <= 3)
	Mouse.teleport(near)
end

-- Keys, the middle button and the wheel, with the camera as the witness.
local function camera_checks()
	print("-- keys, middle button and wheel")
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

	local spot = Point.new(math.floor(conn.width * 0.4), math.floor(conn.height * 0.4))
	local start_yaw = yaw()
	local start_pitch = Camera.pitch() or 0
	local start_zoom = Camera.zoom() or 0
	Mouse.teleport(spot)
	Host.sleep(200)

	Keyboard.key_down_async(keys.LEFT)
	Host.sleep(400)
	check("key held turns the camera", turned(start_yaw) > 10)
	Keyboard.cancel()
	local after_cancel = settle_yaw()
	Host.sleep(300)
	check("cancel released the key", settle_yaw() == after_cancel)

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

	before = settle_yaw()
	Keyboard.key_down_async(keys.LEFT)
	Host.sleep(300)
	Mouse.move(spot, true) -- blocking input cancels, which releases LEFT
	local stopped = settle_yaw()
	Host.sleep(300)
	check("blocking input released the held key", settle_yaw() == stopped and turned(before) > 5)

	before = settle_yaw()
	Mouse.hold_async("middle")
	Mouse.move_async(Point.new(spot.x + 220, spot.y), true)
	Host.sleep(150)
	Mouse.cancel()
	Host.sleep(150)
	local dragged = settle_yaw()
	check("middle drag turned the camera", dragged ~= before)
	Mouse.teleport(Point.new(spot.x - 150, spot.y))
	Host.sleep(300)
	check("cancel released the middle button", settle_yaw() == dragged)

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

	Camera.set_zoom(start_zoom)
	Camera.set_angles(start_yaw, start_pitch)
end

-- The async twins of the interface helpers, and the antiban tasks that restore what they touched.
local function interface_checks()
	print("-- interface twins and antiban tasks")
	local function settle()
		Mouse.wait()
		Host.sleep(400)
	end
	local start_panel = SidePanels.current()
	local start_chat = ChatTabs.active()
	check("logged in", start_panel ~= nil and start_chat ~= nil)

	local t = Host.time()
	check("ChatTabs.open_async queues", ChatTabs.open_async("trade", true))
	check("returns at once", Host.time() - t < 50)
	settle()
	check("chat tab changed", ChatTabs.is_active("trade"))

	SidePanels.open(SidePanels.INVENTORY)
	check("SidePanels.open_async force", SidePanels.open_async(SidePanels.STATS, 0, true))
	settle()
	check("stats open", SidePanels.is_open(SidePanels.STATS))
	check("Stats.hover_async", Stats.hover_async("fishing"))
	settle()
	check("menu is readable after", Host.menu() ~= nil)

	local active = ChatTabs.active()
	Tasks.toggle_chat_tab(true)
	check("toggle_chat_tab returns at once", Mouse.busy())
	local deadline = Host.time() + 9000
	while Mouse.busy() and Host.time() < deadline do
		Host.sleep(100)
	end
	Host.sleep(400)
	check("toggle_chat_tab restored", ChatTabs.active() == active)

	local panel = SidePanels.current()
	Tasks.toggle_tab(true)
	deadline = Host.time() + 12000
	while Mouse.busy() and Host.time() < deadline do
		Host.sleep(100)
	end
	Host.sleep(400)
	check("toggle_tab restored", SidePanels.current() == panel)

	if start_chat ~= nil and start_chat ~= "none" then
		ChatTabs.open(start_chat)
	end
	if start_panel ~= nil then
		SidePanels.open(start_panel)
	end
end

mouse_checks()
camera_checks()
interface_checks()
