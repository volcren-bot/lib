# Main.Interfaces.Mainscreen.Obelisk

The Wilderness obelisks: four stones around a 3 x 3 grid, and everyone on the grid is taken when one is activated.

```luau
local Obelisk = require("@lib/main/interfaces/mainscreen/obelisk")
```

Only "Set Destination" makes the landing known, and it needs the Wilderness hard diary. "Activate" alone is random, so the chooser leaves the network out without the diary. A trip is "Set Destination", a row of the list (group 187, the game's generic `menu` list), then "Teleport to Destination", with the player back on the grid, because clicking a stone walks you up to it. Another player who activates a stone first decides for everyone on the grid.

The obelisk in a player's house isn't used yet.

## Obelisk.stones

Definition:
```luau
function Obelisk.stones(): { Host.Loc }
```
The stones within `RANGE`, nearest first.

Example:
```luau
local Obelisk = require("@lib/main/interfaces/mainscreen/obelisk")

print(#Obelisk.stones())
```

## Obelisk.open

Definition:
```luau
function Obelisk.open(): boolean
```
Opens the list with "Set Destination" on the nearest stone. True once it is open.

Example:
```luau
local Obelisk = require("@lib/main/interfaces/mainscreen/obelisk")

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
local Obelisk = require("@lib/main/interfaces/mainscreen/obelisk")

print(Obelisk.is_open())
```

## Obelisk.destinations

Definition:
```luau
function Obelisk.destinations(): { Destination }?
```
Every row of the open list, each with `name` and `row`. Nil when it isn't open.

Example:
```luau
local Obelisk = require("@lib/main/interfaces/mainscreen/obelisk")

for _, d in ipairs(Obelisk.destinations() or {}) do
	print(d.name)
end
```

## Obelisk.select

Definition:
```luau
function Obelisk.select(level: Level): boolean
```
Clicks a row of the open list and waits for it to close. True once it has. Use `Obelisk.Level`.

Example:
```luau
local Obelisk = require("@lib/main/interfaces/mainscreen/obelisk")

print(Obelisk.select(Obelisk.Level.Level19))
```

## Obelisk.close

Definition:
```luau
function Obelisk.close(): boolean
```
Closes the list. True when it isn't open any more.

Example:
```luau
local Obelisk = require("@lib/main/interfaces/mainscreen/obelisk")

print(Obelisk.close())
```

## Obelisk.on_grid

Definition:
```luau
function Obelisk.on_grid(): boolean
```
Whether the player stands on the grid between the stones.

Example:
```luau
local Obelisk = require("@lib/main/interfaces/mainscreen/obelisk")

print(Obelisk.on_grid())
```

## Obelisk.teleport

Definition:
```luau
function Obelisk.teleport(): boolean
```
Clicks "Teleport to Destination" on the nearest stone, then walks back onto the grid if the click walked off it. The trip follows a few seconds later. True when the player is on the grid.

Example:
```luau
local Obelisk = require("@lib/main/interfaces/mainscreen/obelisk")

print(Obelisk.teleport())
```
