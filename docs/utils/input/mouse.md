# Utils.Input.Mouse

Human-like mouse input: curved movement, random spots inside targets, random press lengths, optional misses and idles. Async functions share the input queue with [Keyboard](keyboard.md) (see [Async input](../../host.md#async-input)).

```luau
local Mouse = require("@lib/utils/input/mouse")
```

## Targets

A `Target` is a point `{ x, y }`, box `{ x1, y1, x2, y2 }`, area `{ x, y, width, height }`, circle `{ x, y, radius }` or quad. For shapes a spot is picked by `distribution`; if the mouse is already inside, it stays unless `forced`.

## Settings

Definition:
```luau
Mouse.speed = 14
Mouse.pace = 1.5
Mouse.wind = 5
Mouse.gravity = 10
Mouse.timeout = 15000
Mouse.press_min = 40
Mouse.press_max = 220
Mouse.distribution = "gauss"
Mouse.miss_chance = 0
Mouse.can_idle = true
Mouse.idle_interval = 0
Mouse.use_teleport = false
Mouse.settle_timeout = 150
Mouse.settle_ms = 30
```
- `speed`, `wind`, `gravity`: movement shape; `speed` only scales the distance-dependent part. Biometrics set `speed`.
- `pace`: time divisor for every move (1.5 is a third faster than 1); raise briefly to hurry, then restore.
- `timeout`: max ms per move.
- `press_min`, `press_max`: click hold range in ms.
- `distribution`: `"random"`, `"gauss"` (centre), `"skewed"` (towards the mouse's origin) or `"rowp"` (weighted towards the mouse).
- `miss_chance`: chance to land near the target first and correct.
- `can_idle`, `idle_interval`: idle 1 to 20 s after roughly `idle_interval` screen diagonals of travel; 0 disables.
- `use_teleport`: jump instead of moving.
- `settle_timeout`, `settle_ms`: before pressing after a move, `click` waits up to `settle_timeout` ms for the client to report the final position, then `settle_ms`; otherwise the client can take the press at the previous frame's position.

## Mouse.position

Definition:
```luau
function Mouse.position(): Point?
```
Mouse position; nil when outside the client.

Example:
```luau
local p = Mouse.position()
print(if p then `{p.x}, {p.y}` else "outside the client")
```

## Mouse.wind_options

Definition:
```luau
function Mouse.wind_options(): Host.WindMouseOptions
```
The WindMouse options the current settings give, for host calls that move the mouse themselves such as [Host.act](../../host.md#hostact).

Example:
```luau
print(Mouse.wind_options().speed)
```

## Mouse.press_ms

Definition:
```luau
function Mouse.press_ms(): number
```
A button hold time between `press_min` and `press_max`, leaning short.

Example:
```luau
print(Mouse.press_ms())
```

## Mouse.teleport

Definition:
```luau
function Mouse.teleport(p: Point)
```
Jumps to a point without movement.

Example:
```luau
Mouse.teleport({ x = 200, y = 200 })
```

## Mouse.hold

Definition:
```luau
function Mouse.hold(button: Button?)
```
Presses and holds `"left"` (default), `"right"` or `"middle"`.

Example:
```luau
Mouse.hold("middle")
```

## Mouse.release

Definition:
```luau
function Mouse.release(button: Button?)
```
Releases a button.

Example:
```luau
Mouse.release("middle")
```

## Mouse.idle

Definition:
```luau
function Mouse.idle()
```
Sleeps 1 to 20 s (skewed short), like looking away.

Example:
```luau
Mouse.idle()
```

## Mouse.miss

Definition:
```luau
function Mouse.miss(destination: Point): Point
```
A random point near the destination, scaled by the distance from the mouse; the destination itself when the mouse position is unknown.

Example:
```luau
print(Mouse.miss({ x = 300, y = 300 }))
```

## Mouse.move

Definition:
```luau
function Mouse.move(target: Target, forced: boolean?, distribution: Distribution?)
```
Moves to a target, possibly missing or idling first per the settings.

Example:
```luau
Mouse.move({ x1 = 100, y1 = 100, x2 = 200, y2 = 140 })
```

## Mouse.move_async

Definition:
```luau
function Mouse.move_async(target: Target, forced: boolean?, distribution: Distribution?)
```
Queues a move like `Mouse.move` (never misses or idles) and returns at once. Any other input, `Mouse.cancel`, a minimenu read or script end stops it where it is.

Example:
```luau
Mouse.move_async({ x1 = 100, y1 = 100, x2 = 200, y2 = 140 })
```

## Mouse.click_async

Definition:
```luau
function Mouse.click_async(target: Target?, button: Button?, forced: boolean?, distribution: Distribution?): boolean
```
Queues an optional move then a click with a random hold; cancelling mid-press still releases. False when there is no target and the mouse is outside the client.

Example:
```luau
Mouse.click_async({ x1 = 100, y1 = 100, x2 = 200, y2 = 140 })
Mouse.wait()
```

## Mouse.hold_async

Definition:
```luau
function Mouse.hold_async(button: Button?)
```
Queues holding a button; released on cancel or script end.

Example:
```luau
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
Mouse.release_async("middle")
```

## Mouse.drag_async

Definition:
```luau
function Mouse.drag_async(target: Target, button: Button?)
```
Queues press, move, release; the button is released even if cancelled.

Example:
```luau
Mouse.drag_async({ x = 200, y = 200 }, "middle")
```

## Mouse.scroll_async

Definition:
```luau
function Mouse.scroll_async(amount: number, down: boolean, target: Target?, forced: boolean?)
```
Queues `Mouse.scroll`.

Example:
```luau
Mouse.scroll_async(3, true)
```

## Mouse.busy

Definition:
```luau
function Mouse.busy(): boolean
```
Whether async input is running or queued.

Example:
```luau
print(Mouse.busy())
```

## Mouse.wait

Definition:
```luau
function Mouse.wait(): boolean
```
Waits for async input; logs and returns false if one failed.

Example:
```luau
Mouse.wait()
```

## Mouse.cancel

Definition:
```luau
function Mouse.cancel()
```
Cancels async input and drops the queue. `Mouse.position` may trail the real mouse by a frame or two afterwards (also after `Mouse.wait`).

Example:
```luau
Mouse.cancel()
```

## Mouse.travel_ms

Definition:
```luau
function Mouse.travel_ms(to: Point, from: Point?): number
```
Estimated ms for a move from `from` (default the mouse) to `to`: the planned time corrected by how long past moves actually took. 0 with `use_teleport`.

Example:
```luau
print(Mouse.travel_ms({ x = 400, y = 300 }))
```

## Mouse.click

Definition:
```luau
function Mouse.click(target: Target?, button: Button?, forced: boolean?, distribution: Distribution?)
```
Moves to `target` if given, waits for the client to settle, then clicks with a random hold; without a target clicks in place.

Example:
```luau
Mouse.click({ x1 = 100, y1 = 100, x2 = 200, y2 = 140 })
```

## Mouse.drag

Definition:
```luau
function Mouse.drag(target: Target, button: Button?)
```
Holds a button, moves to the target, releases.

Example:
```luau
Mouse.drag({ x = 200, y = 200 })
```

## Mouse.scroll

Definition:
```luau
function Mouse.scroll(amount: number, down: boolean, target: Target?, forced: boolean?)
```
Turns the wheel `amount` notches, moving to `target` first if given.

Example:
```luau
Mouse.scroll(3, true)
```
