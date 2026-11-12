# Main.Interfaces.Mainscreen.Boltpouch

The bolt pouch: four stored stacks of bolts and the interface (group 433) that moves them. The fourth stack is the extra ammo slot; to wield from it use [Wornitems](../gametabs/wornitems.md#the-secondary-ammo-slot). Contents are read from varbits, so reads don't need the interface open. The interface sits in a slot [Toplevel](toplevel.md) doesn't track, so this module has its own `is_open` and `close`.

```luau
local Boltpouch = require("@lib/main/interfaces/mainscreen/boltpouch")
```

## Constants

Definition:
```luau
Boltpouch.ITEM = 9433
Boltpouch.GROUP = 433
Boltpouch.CLOSE = 21
Boltpouch.OPTION = "Open"
Boltpouch.CURRENT = 0
Boltpouch.EXTRA = 4
Boltpouch.ROWS: { [number]: number }
Boltpouch.BOLT_VARBITS = { 2473, 2474, 2475, 2476 }
Boltpouch.AMOUNT_VARBITS = { 2469, 2470, 2471, 2472 }
Boltpouch.BOLTS_ENUM = 336
Boltpouch.WORN_CONTAINER = 94
Boltpouch.WORN_AMMO_SLOT = 13
Boltpouch.TIMEOUT_MS = 2500
Boltpouch.DRAG_HOLD_MS = { 130, 220 }
Boltpouch.DRAG_DROP_MS = { 60, 130 }
Boltpouch.POLL_MS = 50
```
Rows: `CURRENT` (0) is the worn ammo, 1 to 3 the stored stacks, `EXTRA` (4) the extra ammo; `ROWS` maps each to its component. Each stack's bolt varbit holds an index into enum `BOLTS_ENUM`. A drag holds for `DRAG_HOLD_MS` first, since a shorter press is a click that takes the stack out.

## Types

Definition:
```luau
export type Bolt = { slot: number, id: number, quantity: number }
```
A stack and its row number.

## Boltpouch.held

Definition:
```luau
function Boltpouch.held(): boolean
```
Whether the pouch is in the inventory.

Example:
```luau
print(Boltpouch.held())
```

## Boltpouch.accepts

Definition:
```luau
function Boltpouch.accepts(id: number): boolean?
```
Whether the pouch can store the item. Nil when the game files can't be read.

Example:
```luau
print(Boltpouch.accepts(9144))
```

## Boltpouch.slot

Definition:
```luau
function Boltpouch.slot(slot: number): Bolt?
```
What a row holds. Nil when it is empty or can't be read.

Example:
```luau
local worn = Boltpouch.slot(Boltpouch.CURRENT)
```

## Boltpouch.stored

Definition:
```luau
function Boltpouch.stored(): { Bolt }
```
Non-empty stacks in rows 1 to `EXTRA`; excludes the worn ammo.

Example:
```luau
local Boltpouch = require("@lib/main/interfaces/mainscreen/boltpouch")

for _, bolt in ipairs(Boltpouch.stored()) do
	print(bolt.slot, bolt.id, bolt.quantity)
end
```

## Boltpouch.is_open

Definition:
```luau
function Boltpouch.is_open(): boolean
```
Whether the interface is open.

Example:
```luau
print(Boltpouch.is_open())
```

## Boltpouch.open

Definition:
```luau
function Boltpouch.open(): boolean
```
Clicks "Open" on the pouch in the inventory. True once open.

Example:
```luau
Boltpouch.open()
```

## Boltpouch.close

Definition:
```luau
function Boltpouch.close(): boolean
```
Clicks the close button. True once closed, or if it already was.

Example:
```luau
Boltpouch.close()
```

## Boltpouch.store

Definition:
```luau
function Boltpouch.store(item: Item): boolean
```
Uses the item on the pouch; the client picks the row, filling an empty extra ammo row first. True once the inventory quantity drops.

Example:
```luau
Boltpouch.store(9144)
```

## Boltpouch.remove

Definition:
```luau
function Boltpouch.remove(slot: number): boolean
```
With the interface open, clicks a row to move its stack (or the worn ammo, for `CURRENT`) to the inventory. False if the row is empty; true once it empties.

Example:
```luau
Boltpouch.remove(1)
```

## Boltpouch.move

Definition:
```luau
function Boltpouch.move(from: number, to: number): boolean
```
With the interface open, drags one row onto another; different bolts swap. True once `to` holds the source bolt; false (and logged) when the client refuses.

Example:
```luau
local Boltpouch = require("@lib/main/interfaces/mainscreen/boltpouch")

if Boltpouch.open() then
	print(Boltpouch.move(Boltpouch.CURRENT, Boltpouch.EXTRA))
	Boltpouch.close()
end
```
