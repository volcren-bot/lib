# Main.Interfaces.Inv

A tool for looking inside any item container: your inventory, worn items, the bank and so on. You create one for the container you care about and then ask it questions: what's in it, how many of something, whether something is there.

```luau
local Inv = require("../main/interfaces/inv")
```

Items can be given by id (`995`), by name (`"Logs"`, not case sensitive) or as a range of doses (`"Potion (1..4)"`). Wherever a function takes `items`, you can give one of them or a list.

## Inv.new

Definition:
```luau
function Inv.new(container: number, size: number?, view: View?): Inv
```
Creates a tool for one container. `container` is the container's id (inventory is `93`, worn items `94`, bank `95`). If you give `size`, empty slots are included in `slots()` so the list always has that many entries.

`view` tells it where the container's slots are on screen:

```luau
export type View = {
	open: () -> boolean,
	boxes: () -> { [number]: Widget }?,
	owns: (slot: number) -> (MenuEntry) -> boolean,
}
```

`open` brings the interface up, `boxes` reads the slot components keyed by slot number (from 0) and `owns` says which menu entries belong to a slot. The functions that use the mouse (`boxes`, `hover_slot`, `interact`...) need it and fail without it. [Inventory](gametabs/inventory.md) and [Wornitems](gametabs/wornitems.md) come with theirs.

Example:
```luau
local Inv = require("../main/interfaces/inv")

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
Every slot of the container. Empty slots have an `id` of `-1` (only listed when you gave a `size`).

Example:
```luau
local Inv = require("../main/interfaces/inv")

local backpack = Inv.new(93, 28)
print("slots:", #(backpack.slots() or {}))
```

## inv.items

Definition:
```luau
items: () -> { Slot }?
```
Only the slots that hold something, each with `slot`, `id`, `quantity` and `name`.

Example:
```luau
local Inv = require("../main/interfaces/inv")

for _, item in ipairs(Inv.new(93, 28).items() or {}) do
	print(item.name, item.quantity)
end
```

## inv.indices_of

Definition:
```luau
indices_of: (items: Item | { Item }) -> { number }?
```
The slot numbers (starting at 0) of every matching item.

Example:
```luau
local Inv = require("../main/interfaces/inv")

local slots = Inv.new(93, 28).indices_of("Logs")
print(slots and #slots, "stacks of logs")
```

## inv.index_of

Definition:
```luau
index_of: (items: Item | { Item }) -> number?
```
The slot number of the first matching item, or `nil` if there is none. `inv.find` is the same function.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print(Inv.new(93, 28).index_of("Logs"))
```

## inv.find

Definition:
```luau
find: (item: Item | { Item }) -> number?
```
Same as `index_of`.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print(Inv.new(93, 28).find({ "Logs", "Oak logs" }))
```

## inv.contains

Definition:
```luau
contains: (item: Item) -> boolean
```
Whether the container holds that item.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print("has logs:", Inv.new(93, 28).contains("Logs"))
```

## inv.contains_any

Definition:
```luau
contains_any: (items: { Item }) -> boolean
```
Whether the container holds at least one of the items.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print(Inv.new(93, 28).contains_any({ "Logs", "Oak logs" }))
```

## inv.contains_all

Definition:
```luau
contains_all: (items: { Item }) -> boolean
```
Whether the container holds every one of the items.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print(Inv.new(93, 28).contains_all({ "Logs", "Tinderbox" }))
```

## inv.count

Definition:
```luau
count: (items: Item | { Item }) -> number?
```
How many slots hold a matching item. A stack of 100 coins counts as one.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print(Inv.new(93, 28).count("Logs"), "slots with logs")
```

## inv.count_ex

Definition:
```luau
count_ex: (items: Item | { Item }) -> number?
```
The total quantity of matching items: a stack of 100 coins counts as 100.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print(Inv.new(93, 28).count_ex("Coins"), "coins")
```

## inv.wait_count

Definition:
```luau
wait_count: (items: Item | { Item }, count: number, timeout_ms: number?, interval_ms: number?) -> boolean
```
Waits until exactly `count` slots hold a matching item. Returns `false` if that doesn't happen within `timeout_ms` (600 by default). It checks every `interval_ms`, or at slightly random moments if you don't say.

Example:
```luau
local Inv = require("../main/interfaces/inv")

local backpack = Inv.new(93, 28)
print(backpack.wait_count("Logs", 28, 5000))
```

## inv.item

Definition:
```luau
item: (slot: number) -> Slot?
```
The item in `slot` with its `id`, `quantity` and `name`, or `nil` (and no error) when the slot is empty. The id is read from the client, so there's only ever one answer.

Example:
```luau
local Inv = require("../main/interfaces/inv")

local first = Inv.new(93, 28).item(0)
print(first and first.name)
```

## inv.find_different

Definition:
```luau
find_different: (items: Item | { Item }) -> { number }?
```
The slots that hold something other than `items`.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print("slots to bank:", #(Inv.new(93, 28).find_different({ "Knife", "Logs" }) or {}))
```

## inv.contains_different

Definition:
```luau
contains_different: (items: Item | { Item }) -> boolean
```
Whether any slot holds something other than `items`.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print(Inv.new(93, 28).contains_different("Logs"))
```

## inv.quantity

Definition:
```luau
quantity: (items: Item | { Item }) -> number?
```
The quantity in the first slot holding a matching item, `0` when there's none. A single item reads `1`.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print("coins:", Inv.new(93, 28).quantity("Coins"))
```

## inv.slot_quantity

Definition:
```luau
slot_quantity: (slot: number) -> number?
```
The quantity in `slot`, `0` when it's empty.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print(Inv.new(93, 28).slot_quantity(0))
```

## inv.used

Definition:
```luau
used: () -> { number }?
```
The slots that hold something.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print(#(Inv.new(93, 28).used() or {}), "slots used")
```

## inv.empty

Definition:
```luau
empty: () -> { number }?
```
The empty slots. It needs the container's `size`.

Example:
```luau
local Inv = require("../main/interfaces/inv")

local free = Inv.new(93, 28).empty()
print("first free slot:", free and free[1])
```

## inv.is_used

Definition:
```luau
is_used: (slot: number) -> boolean
```
Whether `slot` holds something.

Example:
```luau
local Inv = require("../main/interfaces/inv")

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
local Inv = require("../main/interfaces/inv")

print(Inv.new(93, 28).is_empty(27))
```

## inv.count_used

Definition:
```luau
count_used: () -> number?
```
How many slots hold something.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print(Inv.new(93, 28).count_used())
```

## inv.count_empty

Definition:
```luau
count_empty: () -> number?
```
How many slots are empty. It needs the container's `size`.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print(Inv.new(93, 28).count_empty())
```

## inv.wait_used

Definition:
```luau
wait_used: (count: number, timeout_ms: number?, interval_ms: number?) -> boolean
```
Waits until exactly `count` slots hold something, like `wait_count` does for items.

Example:
```luau
local Inv = require("../main/interfaces/inv")

print(Inv.new(93, 28).wait_used(0, 3000))
```

## inv.open

Definition:
```luau
open: () -> boolean
```
Brings up the interface that shows the container (the view's `open`).

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")

print(Inventory.open())
```

## inv.boxes

Definition:
```luau
boxes: (slots: { number }?) -> { [number]: Widget }?
```
The slot components keyed by slot number (from 0), only those of `slots` when given. Their position is known with the interface closed too.

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")

for slot, box in pairs(Inventory.boxes(Inventory.used() or {}) or {}) do
	print(slot, box.x, box.y)
end
```

## inv.box

Definition:
```luau
box: (slot: number) -> Widget?
```
The component of one slot.

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")

local box = Inventory.box(0)
print(box and box.width, box and box.height)
```

## inv.slot_at

Definition:
```luau
slot_at: (at: Point?) -> number?
```
The slot under `at` (the mouse by default), `nil` when it's over none.

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")

print("mouse over slot", Inventory.slot_at())
```

## inv.near

Definition:
```luau
near: (slot: number, slots: { number }, max_dist: number?, remove_slot: boolean?) -> { number }?
```
Those of `slots` within `max_dist` (60 by default) of `slot`, nearest first. Distances are centre to centre in interface units (inventory slots are about 42 apart across and 36 down, so 60 takes in the diagonals). `slot` itself is left out unless `remove_slot` is false.

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")

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
A random one of `slots` near `slot` (within `max_dist`, 800 by default). With `"gauss"` (the default) it picks among the nearest band of 60 units, with `"random"` among all of them.

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")

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
local Inventory = require("../main/interfaces/gametabs/inventory")

Inventory.hover_slot(0)
```

## inv.click_slot

Definition:
```luau
click_slot: (slot: number, button: Button?) -> boolean
```
Opens the interface and clicks `slot`, empty or not.

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")

Inventory.click_slot(0, "right")
```

## inv.interact_slot

Definition:
```luau
interact_slot: (slot: number, option: string?) -> boolean
```
Picks `option` on the item in `slot` (its left-click option when not given): a left click when it's the top entry, the menu otherwise. It returns `false` when the slot is empty or the client did something else.

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")

print(Inventory.interact_slot(0, "Drink"))
```

## inv.move_slot

Definition:
```luau
move_slot: (slot: number, destination: number) -> boolean
```
Drags the item in `slot` onto `destination` and waits for the container to show it there.

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")

print(Inventory.move_slot(0, 27))
```

## inv.hover

Definition:
```luau
hover: (items: Item | { Item }) -> boolean
```
Moves the mouse onto the first matching item. `false` when there's none.

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")

Inventory.hover("Knife")
```

## inv.click

Definition:
```luau
click: (items: Item | { Item }, button: Button?) -> boolean
```
Clicks the first matching item.

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")

Inventory.click("Knife")
```

## inv.interact

Definition:
```luau
interact: (items: Item | { Item }, option: string?) -> boolean
```
`interact_slot` on the first matching item.

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")

print(Inventory.interact("Prayer potion(1..4)", "Drink"))
```

## inv.move

Definition:
```luau
move: (items: Item | { Item }, destination: number) -> boolean
```
Drags the matching item nearest to `destination` there. Returns `true` right away when one is already there.

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")

print(Inventory.move("Knife", 0))
```
