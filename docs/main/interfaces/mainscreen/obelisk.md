# Main.Interfaces.Mainscreen.Obelisk

The Wilderness obelisks: four stones around a 3 x 3 grid; activating one teleports everyone on the grid. A known landing needs "Set Destination" (Wilderness hard diary), a row of the list (group 187, the generic `menu` list), then "Teleport to Destination" from the grid; plain "Activate" is random, so the chooser skips the network without the diary. Another player activating first decides for everyone. House obelisks aren't supported.

```luau
local Obelisk = require("@lib/main/interfaces/mainscreen/obelisk")
```

## Constants

Definition:
```luau
Obelisk.GROUP = 187
Obelisk.LIST = 3
Obelisk.CLOSE = 4
Obelisk.OBJECT = "Obelisk"
Obelisk.SET = "Set Destination"
Obelisk.TELEPORT = "Teleport to Destination"
Obelisk.RANGE = 8
Obelisk.OPEN_TIMEOUT_MS = 5000
Obelisk.CLOSE_TIMEOUT_MS = 3000
Obelisk.POLL_MS = 50
Obelisk.SETTLE_MS = { 250, 500 }
Obelisk.GRID_TIMEOUT_MS = 4000
```
Widget ids, object name and options, stone search radius in tiles, open/close waits, poll rate, settle after opening, and the walk-back timeout.

## Obelisk.Level

Definition:
```luau
export type Level = "Level 13 Wilderness" | "Level 19 Wilderness" | "Level 27 Wilderness" | "Level 35 Wilderness" | "Level 44 Wilderness" | "Level 50 Wilderness"
```
The list's rows. `Obelisk.Level` is a frozen table of them (`Obelisk.Level.Level19`).

## Obelisk.stones

Definition:
```luau
function Obelisk.stones(): { Host.Loc }
```
Obelisks within `RANGE`, nearest first. Empty when none or your position is unknown.

Example:
```luau
print(#Obelisk.stones())
```

## Obelisk.open

Definition:
```luau
function Obelisk.open(): boolean
```
Uses "Set Destination" on the nearest stone and waits for the list. True once open (or already open).

Example:
```luau
print(Obelisk.open())
```

## Obelisk.is_open

Definition:
```luau
function Obelisk.is_open(): boolean
```
Whether the list is open.

Example:
```luau
print(Obelisk.is_open())
```

## Obelisk.destinations

Definition:
```luau
function Obelisk.destinations(): { Destination }?
```
Rows of the open list, each with `name` and `row`. Nil when not open.

Example:
```luau
for _, d in ipairs(Obelisk.destinations() or {}) do
	print(d.name)
end
```

## Obelisk.select

Definition:
```luau
function Obelisk.select(level: Level): boolean
```
Clicks the row and waits for the list to close. False when the row is absent or the list stays open.

Example:
```luau
print(Obelisk.select(Obelisk.Level.Level19))
```

## Obelisk.close

Definition:
```luau
function Obelisk.close(): boolean
```
Closes the list via `Toplevel.close`. True once closed.

Example:
```luau
print(Obelisk.close())
```

## Obelisk.on_grid

Definition:
```luau
function Obelisk.on_grid(): boolean
```
Whether you stand strictly inside the four stones. False when fewer than four are in range.

Example:
```luau
print(Obelisk.on_grid())
```

## Obelisk.teleport

Definition:
```luau
function Obelisk.teleport(): boolean
```
Uses "Teleport to Destination" on the nearest stone, then walks back to the grid centre if the click walked you off. True when you end on the grid; false when fewer than four stones are in range. The trip follows a few seconds later.

Example:
```luau
print(Obelisk.teleport())
```
