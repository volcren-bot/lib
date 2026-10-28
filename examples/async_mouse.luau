--!strict
-- Checks async mouse input against a live client without clicking: moves, blocking moves, minimenu reads and cancel.
local Geometry = require("../utils/math/geometry")
local Host = require("../host")
local Mouse = require("../utils/input/mouse")

local Point = Geometry.Point

local function check(name: string, ok: boolean)
	print(`[{if ok then "ok" else "FAIL"}] {name}`)
end

local conn = Host.connection()
local far = Point.new(math.floor(conn.width * 0.8), math.floor(conn.height * 0.3))
local near = Point.new(math.floor(conn.width * 0.2), math.floor(conn.height * 0.3))

Mouse.teleport(near)
Host.sleep(100)

-- Returns at once and keeps moving while the script runs.
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

-- cancel stops it where it is.
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

-- A blocking move takes over from an async one.
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

-- Reading the live menu takes the mouse back.
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

-- Queued moves run in order.
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
