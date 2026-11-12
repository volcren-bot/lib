# Utils.Ticks

Waiting in game ticks (0.6 s), the unit most game actions happen in.

```luau
local Ticks = require("@lib/utils/ticks")
```

## Constants

Definition:
```luau
Ticks.MS = 600
Ticks.POLL_MS = 50
```
Tick length and `wait`'s poll interval, in ms.

## Ticks.current

Definition:
```luau
function Ticks.current(): number?
```
The current tick counter (`game_state().tick_count`); nil when unknown.

Example:
```luau
local Ticks = require("@lib/utils/ticks")

print("tick:", Ticks.current())
```

## Ticks.wait

Definition:
```luau
function Ticks.wait(count: number?, timeout_ms: number?): number?
```
Waits for `count` new ticks (default 1) and returns the tick reached. Returns nil, logging a line, when the counter is unknown or no tick arrives within `timeout_ms` (default twice the expected time; usually a logout).

Example:
```luau
local Ticks = require("@lib/utils/ticks")

local now = Ticks.wait(3)
print(if now then `reached tick {now}` else "unavailable")
```
