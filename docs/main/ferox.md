# Main.Ferox

The Ferox Enclave: a Wilderness safe zone with a bank and the Pool of Refreshment. The planner only goes there when the goal is inside it (`Transports.choose`).

```luau
local Ferox = require("@lib/main/ferox")
```

## Constants

Definition:
```luau
Ferox.BOUNDS = { x1 = 3123, y1 = 3618, x2 = 3155, y2 = 3639 }
Ferox.POOL = "Pool of Refreshment"
Ferox.POOL_OPTION = "Drink"
Ferox.RESTORE_TIMEOUT_MS = 10000
```
Approximate bounds, the pool's name and option, and `restore`'s timeout.

## Ferox.contains

Definition:
```luau
function Ferox.contains(x: number, y: number): boolean
```
Whether a tile is in the Enclave.

Example:
```luau
local Ferox = require("@lib/main/ferox")

print(Ferox.contains(3150, 3635))
```

## Ferox.inside

Definition:
```luau
function Ferox.inside(): boolean
```
Whether the player is in the Enclave.

Example:
```luau
local Ferox = require("@lib/main/ferox")

print(Ferox.inside())
```

## Ferox.restore

Definition:
```luau
function Ferox.restore(): (boolean, string?)
```
Walks to the pool, drinks and waits for the restore (`Player.restore_with`). `false` and why when not in the Enclave, the pool isn't in sight, or nothing restored.

Example:
```luau
local Ferox = require("@lib/main/ferox")

if Ferox.inside() then
	print(Ferox.restore())
end
```
