# Main.Interfaces.Mainscreen.Boltpouch

The bolt pouch: four stored stacks of bolts, plus the interface that moves them (group 433), opened by "Open" on the pouch in the inventory. The fourth stack is the extra ammo that the worn items tab offers as a second ammo slot; for that slot use [Wornitems](../gametabs/wornitems.md#the-secondary-ammo-slot).

```luau
local Boltpouch = require("@lib/main/interfaces/mainscreen/boltpouch")
```

What it holds is in client variables, so reading doesn't need the interface. The interface sits over the side panel, in a slot [Toplevel](toplevel.md) doesn't track, so this module has its own `is_open` and `close`, which uses the mouse.

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
A row is a number: `CURRENT` (0) is the worn ammo, 1 to 3 the stored stacks and `EXTRA` (4) the extra ammo. `ROWS` gives each row's component. The varbits hold each stack's bolt (a number the enum maps to an item id) and amount. A drag holds the button for `DRAG_HOLD_MS` first: the rows only start a drag after 5 client cycles held, and letting go sooner is a click, which takes the stack out.

## Types

Definition:
```luau
export type Bolt = { slot: number, id: number, quantity: number }
```
A stack and its row.

## Boltpouch.held

Definition:
```luau
function Boltpouch.held(): boolean
```
Whether the pouch is in the inventory.

## Boltpouch.accepts

Definition:
```luau
function Boltpouch.accepts(id: number): boolean?
```
Whether the pouch can store the item. Nil when the game files can't be read.

## Boltpouch.slot

Definition:
```luau
function Boltpouch.slot(slot: number): Bolt?
```
What a row holds. Nil when it is empty or can't be read.

## Boltpouch.stored

Definition:
```luau
function Boltpouch.stored(): { Bolt }
```
The stored stacks that hold something, not the worn ammo.

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

## Boltpouch.open

Definition:
```luau
function Boltpouch.open(): boolean
```
Opens the interface from the pouch in the inventory. True when it is open.

## Boltpouch.close

Definition:
```luau
function Boltpouch.close(): boolean
```
Clicks the close button and waits. True when it is closed.

## Boltpouch.store

Definition:
```luau
function Boltpouch.store(item: Item): boolean
```
Uses an item on the pouch, with no interface over the inventory. The client picks the row: an empty extra ammo row fills before the others. True once the pouch took some.

## Boltpouch.remove

Definition:
```luau
function Boltpouch.remove(slot: number): boolean
```
With the interface open, clicks a row to take its stack out: stored bolts, or the worn ammo with `CURRENT`, go to the inventory. True once the row is empty.

## Boltpouch.move

Definition:
```luau
function Boltpouch.move(from: number, to: number): boolean
```
With the interface open, drags one row's stack onto another; the client swaps two stacks of different bolts. True once the stack is there; a stack the client won't put there just fails.

Example:
```luau
local Boltpouch = require("@lib/main/interfaces/mainscreen/boltpouch")

if Boltpouch.open() then
	print(Boltpouch.move(Boltpouch.CURRENT, Boltpouch.EXTRA))
	Boltpouch.close()
end
```
