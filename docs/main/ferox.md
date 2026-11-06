# Main.Ferox

The Ferox Enclave: a safe zone inside the Wilderness's bounds, with a bank and the Pool of Refreshment. A common place to restock and restore for an account without a house pool; the planner reaches it only when the goal is inside it (see `Transports.choose`).

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
The Enclave's bounds, which are approximate, the pool's name and option, and how long `restore` waits for the walk and the drink.

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
Walks to the Pool of Refreshment, drinks from it and waits for it to take (`Player.restore_with`). False and why: not in the Enclave, the pool not in sight, or nothing restored.

Example:
```luau
local Ferox = require("@lib/main/ferox")

if Ferox.inside() then
	print(Ferox.restore())
end
```
