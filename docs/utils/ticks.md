# Utils.Ticks

Waiting in game time. The game advances in "ticks" of 0.6 seconds, and many things (walking, skilling, combat) happen once per tick, so waiting for ticks is more reliable than waiting for a fixed number of milliseconds.

```luau
local Ticks = require("../utils/ticks")
```

## Constants

Definition:
```luau
Ticks.MS = 600
Ticks.POLL_MS = 50
```
How long a tick lasts in milliseconds, and how often `wait` checks whether a new tick arrived.

## Ticks.current

Definition:
```luau
function Ticks.current(): number?
```
The number of the current tick (it counts up as the game runs).

Example:
```luau
local Ticks = require("../utils/ticks")

print("tick:", Ticks.current())
```

## Ticks.wait

Definition:
```luau
function Ticks.wait(count: number?, timeout_ms: number?): number?
```
Waits until `count` new ticks (default 1) have passed and returns the tick number it ended on. Gives up with an error if no tick arrives within `timeout_ms` (twice the expected time by default), which usually means you were logged out.

Example:
```luau
local Ticks = require("../utils/ticks")

local now = Ticks.wait(3)
print(if now then `reached tick {now}` else "unavailable")
```
