# Main.Interfaces.Inv

Queries and mouse actions for any item container (inventory, worn items, bank...). Create one per container.

```luau
local Inv = require("@lib/main/interfaces/inv")
```

An `Item` is an id (`995`), a case-insensitive name (`"Logs"`) or a dose range (`"Potion (1..4)"`); `items` arguments take one or a list. Slots are numbered from 0.

## Constants

Definition:
```luau
Inv.LOSES_ITEM: { [string]: boolean }
```
Left-click options `click_slot` refuses: `Drop`, `Destroy`, `Release`.

## Inv.new

Definition:
```luau
function Inv.new(container: number, size: number?, view: View?): Inv
```
A handle for container `container` (inventory `93`, worn `94`, bank `95`). With `size`, `slots()` includes empty slots. Mouse functions need a `view` and fail without one; [Inventory](gametabs/inventory.md) and [Wornitems](gametabs/wornitems.md) ship theirs.

```luau
export type View = {
	open: () -> boolean,
	boxes: () -> { [number]: Widget }?,
	owns: (slot: number) -> (MenuEntry) -> boolean,
	empty: (() -> { [number]: boolean }?)?,
}
```
`open` shows the interface, `boxes` returns slot widgets, `owns` matches a slot's menu entries, and `empty` marks slots that read 0 despite the container (bank placeholders).

Example:
```luau
local backpack = Inv.new(93, 28)
for _, item in ipairs(backpack.items() or {}) do
	print(item.slot, item.name, item.quantity)
end
```

## inv.slots

Definition:
```luau
slots: () -> { ItemSlot }?
```
Every slot; empty ones have `id == -1` (listed only with a `size`).

Example:
```luau
print(#(Inv.new(93, 28).slots() or {}))
```

## inv.items

Definition:
```luau
items: () -> { Slot }?
```
Non-empty slots, each `{ slot, id, quantity, name }`.

Example:
```luau
for _, item in ipairs(Inv.new(93, 28).items() or {}) do
	print(item.name, item.quantity)
end
```

## inv.indices_of

Definition:
```luau
indices_of: (items: Item | { Item }) -> { number }?
```
Slots of every matching item.

Example:
```luau
print(#(Inv.new(93, 28).indices_of("Logs") or {}))
```

## inv.index_of

Definition:
```luau
index_of: (items: Item | { Item }) -> number?
```
Slot of the first match, nil when none.

Example:
```luau
print(Inv.new(93, 28).index_of("Logs"))
```

## inv.find

Definition:
```luau
find: (item: Item | { Item }) -> number?
```
Alias of `index_of`.

Example:
```luau
print(Inv.new(93, 28).find({ "Logs", "Oak logs" }))
```

## inv.contains

Definition:
```luau
contains: (item: Item) -> boolean
```
Whether the item is present.

Example:
```luau
print(Inv.new(93, 28).contains("Logs"))
```

## inv.contains_any

Definition:
```luau
contains_any: (items: { Item }) -> boolean
```
Whether at least one of the items is present.

Example:
```luau
print(Inv.new(93, 28).contains_any({ "Logs", "Oak logs" }))
```

## inv.contains_all

Definition:
```luau
contains_all: (items: { Item }) -> boolean
```
Whether every item is present.

Example:
```luau
print(Inv.new(93, 28).contains_all({ "Logs", "Tinderbox" }))
```

## inv.count

Definition:
```luau
count: (items: Item | { Item }) -> number?
```
Number of matching slots; a stack counts once.

Example:
```luau
print(Inv.new(93, 28).count("Logs"))
```

## inv.count_ex

Definition:
```luau
count_ex: (items: Item | { Item }) -> number?
```
Total quantity of matches; a stack of 100 counts 100.

Example:
```luau
print(Inv.new(93, 28).count_ex("Coins"))
```

## inv.wait_count

Definition:
```luau
wait_count: (items: Item | { Item }, count: number, timeout_ms: number?, interval_ms: number?) -> boolean
```
Waits until exactly `count` slots match. Timeout defaults to 600 ms; polling to a random human-like interval.

Example:
```luau
print(Inv.new(93, 28).wait_count("Logs", 28, 5000))
```

## inv.item

Definition:
```luau
item: (slot: number) -> Slot?
```
The item in `slot`, nil (no error) when empty.

Example:
```luau
local first = Inv.new(93, 28).item(0)
print(first and first.name)
```

## inv.find_different

Definition:
```luau
find_different: (items: Item | { Item }) -> { number }?
```
Slots holding anything other than `items`.

Example:
```luau
print(#(Inv.new(93, 28).find_different({ "Knife", "Logs" }) or {}))
```

## inv.contains_different

Definition:
```luau
contains_different: (items: Item | { Item }) -> boolean
```
Whether any slot holds something other than `items`.

Example:
```luau
print(Inv.new(93, 28).contains_different("Logs"))
```

## inv.quantity

Definition:
```luau
quantity: (items: Item | { Item }) -> number?
```
Quantity in the first matching slot, 0 when none.

Example:
```luau
print(Inv.new(93, 28).quantity("Coins"))
```

## inv.slot_quantity

Definition:
```luau
slot_quantity: (slot: number) -> number?
```
Quantity in `slot`, 0 when empty.

Example:
```luau
print(Inv.new(93, 28).slot_quantity(0))
```

## inv.used

Definition:
```luau
used: () -> { number }?
```
Non-empty slots.

Example:
```luau
print(#(Inv.new(93, 28).used() or {}))
```

## inv.empty

Definition:
```luau
empty: () -> { number }?
```
Empty slots. Needs `size`.

Example:
```luau
local free = Inv.new(93, 28).empty()
print(free and free[1])
```

## inv.is_used

Definition:
```luau
is_used: (slot: number) -> boolean
```
Whether `slot` holds something.

Example:
```luau
print(Inv.new(93, 28).is_used(27))
```

## inv.is_empty

Definition:
```luau
is_empty: (slot: number) -> boolean
```
Whether `slot` is empty.

Example:
```luau
print(Inv.new(93, 28).is_empty(27))
```

## inv.count_used

Definition:
```luau
count_used: () -> number?
```
Number of non-empty slots.

Example:
```luau
print(Inv.new(93, 28).count_used())
```

## inv.count_empty

Definition:
```luau
count_empty: () -> number?
```
Number of empty slots. Needs `size`.

Example:
```luau
print(Inv.new(93, 28).count_empty())
```

## inv.wait_used

Definition:
```luau
wait_used: (count: number, timeout_ms: number?, interval_ms: number?) -> boolean
```
Waits until exactly `count` slots are used, with `wait_count`'s defaults.

Example:
```luau
print(Inv.new(93, 28).wait_used(0, 3000))
```

## inv.open

Definition:
```luau
open: () -> boolean
```
Shows the container's interface (the view's `open`).

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.open())
```

## inv.boxes

Definition:
```luau
boxes: (slots: { number }?) -> { [number]: Widget }?
```
Slot widgets keyed by slot, limited to `slots` when given. Positions are known even while the interface is closed.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

for slot, box in pairs(Inventory.boxes(Inventory.used() or {}) or {}) do
	print(slot, box.x, box.y)
end
```

## inv.box

Definition:
```luau
box: (slot: number) -> Widget?
```
Widget of one slot.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.box(0))
```

## inv.slot_at

Definition:
```luau
slot_at: (at: Point?) -> number?
```
Slot under `at` (default the mouse), nil when none.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.slot_at())
```

## inv.near

Definition:
```luau
near: (slot: number, slots: { number }, max_dist: number?, remove_slot: boolean?) -> { number }?
```
Entries of `slots` within `max_dist` (default 60 interface units, centre to centre; inventory slots are ~42 apart across, ~36 down) of `slot`, nearest first. `slot` is excluded unless `remove_slot` is `false`.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(table.concat(Inventory.near(13, Inventory.used() or {}) or {}, ", "))
```

## inv.random_near

Definition:
```luau
random_near: (
	slot: number,
	slots: { number },
	max_dist: number?,
	remove_slot: boolean?,
	distribution: ("gauss" | "random")?
) -> number?
```
A random entry of `slots` within `max_dist` (default 800). `"gauss"` (default) picks from the nearest 60-unit band; `"random"` from all.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.random_near(13, Inventory.used() or {}))
```

## inv.hover_slot

Definition:
```luau
hover_slot: (slot: number) -> boolean
```
Opens the interface and moves the mouse onto `slot`.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.hover_slot(0)
```

## inv.click_slot

Definition:
```luau
click_slot: (slot: number, button: Button?) -> boolean
```
Opens the interface and clicks `slot`. A left click first checks the slot's top option and returns `false` (logged) instead of clicking when it is in `LOSES_ITEM` (such as shift-drop). Drop with `interact_slot(slot, "Drop")`.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.click_slot(0, "right")
```

## inv.interact_slot

Definition:
```luau
interact_slot: (slot: number, option: string?) -> boolean
```
Picks `option` (default the left-click option) on `slot`: left click when it's the top entry, else the menu. `false` when the slot is empty or the client did something else.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.interact_slot(0, "Drink"))
```

## inv.move_slot

Definition:
```luau
move_slot: (slot: number, destination: number) -> boolean
```
Drags `slot` onto `destination` and waits for the container to reflect it.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.move_slot(0, 27))
```

## inv.hover

Definition:
```luau
hover: (items: Item | { Item }) -> boolean
```
Hovers the first match; `false` when none.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.hover("Knife")
```

## inv.click

Definition:
```luau
click: (items: Item | { Item }, button: Button?) -> boolean
```
`click_slot` on the first match.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.click("Knife")
```

## inv.interact

Definition:
```luau
interact: (items: Item | { Item }, option: string?) -> boolean
```
`interact_slot` on the first match.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.interact("Prayer potion(1..4)", "Drink"))
```

## inv.move

Definition:
```luau
move: (items: Item | { Item }, destination: number) -> boolean
```
Drags the match nearest `destination` there; `true` at once when one is already there.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

print(Inventory.move("Knife", 0))
```
