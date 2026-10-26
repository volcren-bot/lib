# Utils.Input.Mouse

Moving and clicking the mouse like a person: smooth curved movement, random click spots inside targets and slightly different click durations.

```luau
local Mouse = require("../utils/input/mouse")
```

## Targets

Many functions take a `target`: the place to go. It can be:

- a point: `{ x = 100, y = 100 }`
- a box: `{ x1 = 10, y1 = 10, x2 = 90, y2 = 40 }`
- an area: `{ x = 10, y = 10, width = 80, height = 30 }`
- a circle: `{ x = 50, y = 50, radius = 20 }`
- a four-cornered shape (a "quad")

For anything but a point, the mouse picks a spot inside the shape, so repeated clicks don't land on the exact same pixel. If the mouse is already inside it, it stays where it is (unless `forced` is true).

## Settings

Definition:
```luau
Mouse.speed = 12
Mouse.wind = 5
Mouse.gravity = 9
Mouse.timeout = 15000
Mouse.press_min = 40
Mouse.press_max = 220
Mouse.distribution = "gauss"
Mouse.miss_chance = 0
Mouse.can_idle = true
Mouse.idle_interval = 0
Mouse.use_teleport = false
```
- `speed`, `wind`, `gravity`: how fast and how wobbly the mouse moves.
- `timeout`: the most time (milliseconds) a single move may take.
- `press_min`, `press_max`: how long a click is held, in milliseconds.
- `distribution`: how a spot inside a shape is picked: `"random"` (anywhere), `"gauss"` (near the middle), `"skewed"` (towards where the mouse comes from) or `"rowp"` (weighted towards the mouse).
- `miss_chance`: chance (0 to 1) of first moving to a wrong spot nearby and correcting.
- `can_idle` and `idle_interval`: now and then pause the mouse for a few seconds, once the mouse has travelled about `idle_interval` screens. 0 turns it off.
- `use_teleport`: jump instead of moving smoothly. Mostly for testing.

## Mouse.position

Definition:
```luau
function Mouse.position(): Point?
```
Where the mouse is. Returns `nil` when the mouse is not over the game.

Example:
```luau
local Mouse = require("../utils/input/mouse")

local p = Mouse.position()
print(if p then `{p.x}, {p.y}` else "mouse is outside")
```

## Mouse.teleport

Definition:
```luau
function Mouse.teleport(p: Point)
```
Jumps the mouse straight to a point, with no movement in between.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.teleport({ x = 200, y = 200 })
```

## Mouse.hold

Definition:
```luau
function Mouse.hold(button: Button?)
```
Presses a mouse button (`"left"`, `"right"` or `"middle"`; left by default) and keeps it held.

Example:
```luau
local Host = require("../host")
local Mouse = require("../utils/input/mouse")

Mouse.hold("middle")
Host.sleep(200)
Mouse.release("middle")
```

## Mouse.release

Definition:
```luau
function Mouse.release(button: Button?)
```
Releases a mouse button.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.release()
```

## Mouse.idle

Definition:
```luau
function Mouse.idle()
```
Does nothing for one to twenty seconds, like a person who looked away.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.idle()
```

## Mouse.miss

Definition:
```luau
function Mouse.miss(destination: Point): Point
```
Picks a point near, but not exactly at, a destination. It is where a careless hand would first land.

Example:
```luau
local Mouse = require("../utils/input/mouse")

local near = Mouse.miss({ x = 300, y = 300 })
print(near.x, near.y)
```

## Mouse.move

Definition:
```luau
function Mouse.move(target: Target, forced: boolean?, distribution: Distribution?)
```
Moves the mouse to a target. `forced` makes it move even if it's already inside the shape; `distribution` overrides `Mouse.distribution` for this move.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.move({ x1 = 100, y1 = 100, x2 = 200, y2 = 140 })
```

## Mouse.move_async

Definition:
```luau
function Mouse.move_async(target: Target, forced: boolean?, distribution: Distribution?)
```
Starts moving to a target and returns at once; the script keeps running while the mouse moves. Picks the point like `Mouse.move` and uses the same speed, wind and gravity, but never misses or idles. Moves queue in order. The move stops, leaving the mouse where it got to, when the script sends other input (`Mouse.move`, `Mouse.click`, `Mouse.hold`, a key...), calls `Mouse.cancel`, reads the minimenu (`Host.menu`, `Host.menu_open`, `Host.menu_layout`) or ends. Use it to aim at the next target while doing something else, or for small movements.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.move_async({ x1 = 100, y1 = 100, x2 = 200, y2 = 140 })
-- ... do other work, then click: this takes over from the move above
Mouse.click({ x1 = 100, y1 = 100, x2 = 200, y2 = 140 })
```

## Mouse.click_async

Definition:
```luau
function Mouse.click_async(target: Target?, button: Button?, forced: boolean?, distribution: Distribution?): boolean
```
Starts a click, after the move to the target if there is one, and returns at once. The button is held for a random time between `Mouse.press_min` and `Mouse.press_max`. Cancelling during the press still releases the button. Returns `false` when there is no target and the mouse isn't over the client.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.click_async({ x1 = 100, y1 = 100, x2 = 200, y2 = 140 })
Mouse.wait()
```

## Mouse.hold_async

Definition:
```luau
function Mouse.hold_async(button: Button?)
```
Queues pressing a button and keeping it held. Cancelling with `Mouse.cancel`, other input, a minimenu read or the script ending releases it.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.hold_async("middle")
Mouse.move_async({ x = 400, y = 300 })
Mouse.release_async("middle")
```

## Mouse.release_async

Definition:
```luau
function Mouse.release_async(button: Button?)
```
Queues releasing a button.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.release_async("middle")
```

## Mouse.drag_async

Definition:
```luau
function Mouse.drag_async(target: Target, button: Button?)
```
Queues a drag: press the button, move to the target, release it. If the drag is cancelled in the middle, the button is still released.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.move({ x = 100, y = 100 })
Mouse.drag_async({ x = 200, y = 200 }, "middle")
Mouse.wait()
```

## Mouse.scroll_async

Definition:
```luau
function Mouse.scroll_async(amount: number, down: boolean, target: Target?, forced: boolean?)
```
Queues turning the mouse wheel by `amount` notches, down or up. With a target it moves there first.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.scroll_async(3, true)
```

## Mouse.busy

Definition:
```luau
function Mouse.busy(): boolean
```
Whether async mouse input is still running or queued.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.move_async({ x = 300, y = 200 })
print(Mouse.busy())
```

## Mouse.wait

Definition:
```luau
function Mouse.wait(): boolean
```
Waits for async input to finish. Returns `false`, after printing the reason, if one failed.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.move_async({ x = 300, y = 200 })
Mouse.wait()
```

## Mouse.cancel

Definition:
```luau
function Mouse.cancel()
```
Stops async input and drops what was queued. Returns once nothing is being sent any more. The client may still be working through moves already sent, so `Mouse.position` can trail the real mouse by a frame or two; wait a moment before reading it. The same goes after `Mouse.wait`.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.move_async({ x = 300, y = 200 })
Mouse.cancel()
```

## Mouse.travel_ms

Definition:
```luau
function Mouse.travel_ms(to: Point, from: Point?): number
```
About how long (milliseconds) a move from `from` (the mouse by default) to `to` takes. It starts from the time the mouse movement plans for the distance and speed, and learns from the moves made so far how long they really take next to that plan. 0 with `use_teleport`.

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Mouse = require("../utils/input/mouse")

print(Mouse.travel_ms(Geometry.Point.new(400, 300)))
```

## Mouse.click

Definition:
```luau
function Mouse.click(target: Target?, button: Button?, forced: boolean?, distribution: Distribution?)
```
Clicks. With a target it moves there first; without one it clicks where the mouse is.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.click({ x1 = 100, y1 = 100, x2 = 200, y2 = 140 })
Mouse.click(nil, "right")
```

## Mouse.drag

Definition:
```luau
function Mouse.drag(target: Target, button: Button?)
```
Holds a button, moves to the target and releases the button.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.move({ x = 100, y = 100 })
Mouse.drag({ x = 200, y = 200 })
```

## Mouse.scroll

Definition:
```luau
function Mouse.scroll(amount: number, down: boolean, target: Target?, forced: boolean?)
```
Turns the mouse wheel by `amount` notches, down or up. With a target it moves there first.

Example:
```luau
local Mouse = require("../utils/input/mouse")

Mouse.scroll(3, true) -- three notches down
```
