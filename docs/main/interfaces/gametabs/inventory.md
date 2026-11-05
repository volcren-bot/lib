# Main.Interfaces.Gametabs.Inventory

Your inventory (the 28 slots you carry). It has every function of [Inv](../inv.md) already set up for the inventory (the slots on screen are the dynamic children of `149:0`), plus selecting, combining and dropping items.

```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
```

## Constants

Definition:
```luau
Inventory.CONTAINER = 93
Inventory.SIZE = 28
Inventory.GROUP = 149
Inventory.shift_enabled = true
```
The container id of the inventory, how many slots it has and its interface. `shift_enabled` is cleared by `shift_drop_slots` when Shift doesn't make "Drop" the left-click option.

## Inventory.PATTERN_HABIT

Definition:
```luau
Inventory.PATTERN_HABIT = {
	turn = { 1, 2.5 },
	sloppy = { 0.12, 0.37 },
	finish = { 1.5, 3 },
	stick = { 0.85, 0.95 },
	corner_left = 0.7,
	corner_top = 0.7,
	along = 0.8,
	across = 1.3,
}
```
What an account's click order habit (see `pattern`) is picked from. `turn`, `sloppy`, `finish` and `stick` are ranges an account gets one value in; `corner_left` and `corner_top` are the chances its fallback start is on the left and at the top; `along` and `across` are what a move of one slot costs along its preferred axis (rows or columns) and across it.

## Inventory functions from Inv

`slots`, `items`, `item`, `indices_of`, `index_of`, `find`, `contains`, `contains_any`, `contains_all`, `find_different`, `contains_different`, `count`, `count_ex`, `wait_count`, `quantity`, `slot_quantity`, `used`, `empty`, `is_used`, `is_empty`, `count_used`, `count_empty`, `wait_used`, `open`, `boxes`, `box`, `slot_at`, `near`, `random_near`, `hover_slot`, `click_slot`, `move_slot`, `interact_slot`, `hover`, `click`, `move` and `interact` work exactly as described in [Inv](../inv.md), on your inventory. The ones that use the mouse open the inventory tab first.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print("logs:", Inventory.count_ex("Logs"))
print("has a knife:", Inventory.contains("Knife"))
Inventory.interact("Bones", "Bury")
```

## Inventory.is_open

Definition:
```luau
function Inventory.is_open(): boolean
```
Whether the inventory tab is the open side panel.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.is_open())
```

## Inventory.free_slots

Definition:
```luau
function Inventory.free_slots(): number?
```
How many empty slots you have (same as `count_empty`).

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print("free slots:", Inventory.free_slots())
```

## Inventory.is_full

Definition:
```luau
function Inventory.is_full(): boolean
```
Whether your inventory has no empty slots left.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print("full:", Inventory.is_full())
```

## Inventory.selected

Definition:
```luau
function Inventory.selected(): number?
```
The slot of the item waiting for a target (after "Use"), `nil` when no inventory item is selected. Read from the client, not from the white outline.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print("selected slot:", Inventory.selected())
```

## Inventory.is_selected

Definition:
```luau
function Inventory.is_selected(slot: number): boolean
```
Whether the item in `slot` is the selected one.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.is_selected(0))
```

## Inventory.deselect

Definition:
```luau
function Inventory.deselect(): boolean
```
Cancels what waits for a target. A selected inventory item is clicked (using it on itself only cancels it), anything else (a spell, an item of another interface, a selected item that has since left the inventory) gets "Cancel" from the menu. Then it waits for the selection to go.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.deselect())
```

## Inventory.select_slot

Definition:
```luau
function Inventory.select_slot(slot: number): boolean
```
Picks "Use" on the item in `slot` and waits until it's selected. Another selection is cancelled first; `true` right away when that slot already is.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.select_slot(0))
```

## Inventory.select

Definition:
```luau
function Inventory.select(items: Item | { Item }): boolean
```
Selects a random one of the matching items, or keeps the selection when it already is one of them.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.select("Knife"))
```

## Inventory.combine_slots

Definition:
```luau
function Inventory.combine_slots(slot_a: number, slot_b: number): boolean
```
Uses the item in `slot_a` on the one in `slot_b` and waits for the selection to go.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.combine_slots(0, 1))
```

## Inventory.combine

Definition:
```luau
function Inventory.combine(items_a: Item | { Item }, items_b: Item | { Item }): boolean
```
Uses one of `items_a` on one of `items_b`, picking the two slots closest to each other.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.combine("Knife", "Logs"))
```

## Inventory.pattern

Definition:
```luau
function Inventory.pattern(slots: { number }?, from: Point?): ({ number }, { boolean })
```
An order to click `slots` in (every slot by default), made up for each call the way a person goes over the inventory, and the mode each slot was reached in (`true` snake, `false` spiral). It starts on the slot whose centre is nearest `from` (the mouse by default), or at the account's corner when the slots can't be seen. Each next slot is picked at random among the rest, the cheap ones much more often: a slot costs its distance in slots, more for a move across the account's preferred axis, more for turning away from the way it was going, and in snake mode more for leaving a row (or column) that still has slots to click. So a snake goes over its line and steps to the next one, heading back, while a spiral keeps on and turns at the edges. Each order starts in snake or spiral mode on an even roll (Biometrics) and keeps its mode from slot to slot with the account's `stick` chance, so a snake can turn into a spiral and back.

The habit is the account's: whether it prefers rows or columns (`Biometrics.PATTERN`), how much it dislikes turning, how sloppy it is, how much it wants to finish a line, how long it sticks to a mode and its corner all come from the Biometrics hash, inside the ranges of `PATTERN_HABIT`. Without `Biometrics.setup` the hash, and so the habit, is random for the run. `examples/inventory_patterns.luau` draws the orders over the inventory.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(table.concat((Inventory.pattern()), ","))
print(table.concat((Inventory.pattern({ 3, 9, 14, 20 })), ","))
```

## Inventory.drop_slots

Definition:
```luau
function Inventory.drop_slots(slots: { number }, attempts: number?): boolean
```
Drops the items in `slots` in that order, picking "Drop" from the menu (with a left click when it's the left-click option). It waits for the drops to reach the inventory and goes over the ones still there, up to `attempts` times (5). A selected item is cancelled first.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.drop_slots({ 0, 1, 2 }))
```

## Inventory.drop

Definition:
```luau
function Inventory.drop(items: Item | { Item }, pattern: { number }?): boolean
```
Drops every matching item, going over their slots in the order of `pattern` (by default a new `Inventory.pattern` of those slots).

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.drop({ "Logs", "Oak logs" }))
```

## Inventory.shift_drop_slots

Definition:
```luau
function Inventory.shift_drop_slots(slots: { number }, attempts: number?): boolean
```
Drops the items in `slots` (in that order) by clicking them with Shift held. Before each click it checks that Shift made "Drop" the item's left-click option; when the game's "Shift click to drop items" setting is off, it clears `shift_enabled` and drops the rest with `drop_slots` (and so will later calls). Shift is always released.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.shift_drop_slots(Inventory.indices_of("Logs") or {}))
```

## Inventory.shift_drop

Definition:
```luau
function Inventory.shift_drop(items: Item | { Item }, pattern: { number }?): boolean
```
Shift drops every matching item, going over their slots in the order of `pattern` (by default a new `Inventory.pattern` of those slots).

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

-- top to bottom, row by row
print(Inventory.shift_drop("Raw shrimps", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27 }))
```
