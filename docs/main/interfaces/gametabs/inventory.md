# Main.Interfaces.Gametabs.Inventory

The 28-slot inventory: every [Inv](../inv.md) function bound to it (on-screen slots are the dynamic children of `149:0`), plus selecting, combining and dropping.

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
Container, size and interface. `shift_enabled` is cleared by `shift_drop_slots` once it finds Shift doesn't make "Drop" the left-click option.

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
Ranges each account's `pattern` habit is drawn from: `turn`, `sloppy`, `finish`, `stick` are ranges; `corner_left`/`corner_top` are chances for the fallback start corner; `along`/`across` are per-slot move costs on and off the preferred axis.

## Inventory functions from Inv

`slots`, `items`, `item`, `indices_of`, `index_of`, `find`, `contains`, `contains_any`, `contains_all`, `find_different`, `contains_different`, `count`, `count_ex`, `wait_count`, `quantity`, `slot_quantity`, `used`, `empty`, `is_used`, `is_empty`, `count_used`, `count_empty`, `wait_used`, `open`, `boxes`, `box`, `slot_at`, `near`, `random_near`, `hover_slot`, `click_slot`, `move_slot`, `interact_slot`, `hover`, `click`, `move`, `interact`: as in [Inv](../inv.md). Mouse functions open the tab first.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

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
Empty slot count (`count_empty`).

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.free_slots())
```

## Inventory.is_full

Definition:
```luau
function Inventory.is_full(): boolean
```
Whether no slot is empty; false when unreadable.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.is_full())
```

## Inventory.selected

Definition:
```luau
function Inventory.selected(): number?
```
The slot of the item selected with "Use", read from the client; nil when none.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.selected())
```

## Inventory.is_selected

Definition:
```luau
function Inventory.is_selected(slot: number): boolean
```
Whether `slot` holds the selected item.

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
Cancels any pending selection and waits for it to clear: a selected inventory item is used on itself, anything else (a spell, another interface's item) gets "Cancel" from the menu. True when nothing was selected.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.deselect()
```

## Inventory.select_slot

Definition:
```luau
function Inventory.select_slot(slot: number): boolean
```
Picks "Use" on `slot` and waits until selected, cancelling another selection first. True at once if already selected.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.select_slot(0)
```

## Inventory.select

Definition:
```luau
function Inventory.select(items: Item | { Item }): boolean
```
Selects a random matching slot, or keeps a selection that already matches. False when none match.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.select("Knife")
```

## Inventory.combine_slots

Definition:
```luau
function Inventory.combine_slots(slot_a: number, slot_b: number): boolean
```
Uses `slot_a` on `slot_b` after a short random pause and waits for the selection to clear.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.combine_slots(0, 1)
```

## Inventory.combine

Definition:
```luau
function Inventory.combine(items_a: Item | { Item }, items_b: Item | { Item }): boolean
```
Uses one of `items_a` on one of `items_b`, choosing the closest pair of distinct slots. False when either is missing.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.combine("Knife", "Logs")
```

## Inventory.pattern

Definition:
```luau
function Inventory.pattern(slots: { number }?, from: Point?): ({ number }, { boolean })
```
A fresh human-like order to click `slots` (all 28 by default), plus each slot's mode (`true` snake, `false` spiral). Starts at the slot nearest `from` (default the mouse), else the account's corner. Each step is a weighted random pick favouring near slots, the preferred axis, keeping direction and, in snake mode, finishing the current line; the mode starts on a coin flip and flips with chance `1 - stick`.

The habit (rows vs columns from `Biometrics.PATTERN`, turn, sloppy, finish, stick, corner) comes from the Biometrics hash within `PATTERN_HABIT`, so it is stable per account and random per run without `Biometrics.setup`. `examples/inventory_patterns.luau` draws the orders.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(table.concat((Inventory.pattern({ 3, 9, 14, 20 })), ","))
```

## Inventory.drop_slots

Definition:
```luau
function Inventory.drop_slots(slots: { number }, attempts: number?): boolean
```
Drops `slots` in order with "Drop", cancelling a selection first, then waits and retries slots still holding their item, up to `attempts` passes (5). True when all are gone.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.drop_slots({ 0, 1, 2 })
```

## Inventory.drop

Definition:
```luau
function Inventory.drop(items: Item | { Item }, pattern: { number }?): boolean
```
Drops every matching item in `pattern` order (default a new `Inventory.pattern` of their slots). False when none match.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.drop({ "Logs", "Oak logs" })
```

## Inventory.shift_drop_slots

Definition:
```luau
function Inventory.shift_drop_slots(slots: { number }, attempts: number?): boolean
```
Drops `slots` in order by Shift-clicking, checking before each click that "Drop" is the left-click option. If it isn't (the game's shift-drop setting is off), clears `shift_enabled` and finishes with `drop_slots`, as do later calls. Shift is always released.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.shift_drop_slots(Inventory.indices_of("Logs") or {})
```

## Inventory.shift_drop

Definition:
```luau
function Inventory.shift_drop(items: Item | { Item }, pattern: { number }?): boolean
```
`drop` using `shift_drop_slots`.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.shift_drop("Raw shrimps")
```
