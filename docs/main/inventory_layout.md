# Main.InventoryLayout

Inventory layouts: what an `inventory` form field gives a script, checked against and filled from the bank, with the rune pouch's runes.

```luau
local InventoryLayout = require("@lib/main/inventory_layout")
```

The user makes layouts in the loader, on the Inventory tab of the script's page: it reads the inventory from the client (and the runes in the rune pouch when the inventory holds one), keeps the layouts per script, and the form's `inventory` field picks one (see `Host.form` in [Host](../host.md)). A layout is positional, each item with its slot, but what matters to the bank is how much of each item it holds: a stack's quantity, or the number of copies of an item that doesn't stack.

```luau
local Host = require("@lib/host")
local Bankmain = require("@lib/main/interfaces/mainscreen/bankmain")
local InventoryLayout = require("@lib/main/inventory_layout")

local values = Host.form({
	title = "Herblore",
	fields = { { id = "inventory", kind = "inventory", label = "Inventory" } },
})
local layout = values and values.inventory
if layout and Bankmain.open() then
	if InventoryLayout.withdraw(layout) then
		Bankmain.close()
		InventoryLayout.reorder(layout)
	end
end
```

## Constants

Definition:
```luau
InventoryLayout.SIZE = 28
InventoryLayout.POUCH_TIMEOUT_MS = 2500
InventoryLayout.POLL_MS = 50
```
The inventory's size, and how long to wait for the pouch to take a stack of runes used on it, and between looks. The pouch's own data is in [Runepouch](interfaces/mainscreen/runepouch.md).

## Types

Definition:
```luau
export type Layout = Host.InventoryLayout
export type Slot = Host.InventoryLayoutSlot
export type Rune = Host.LayoutItem
```
A layout is `{ name, slots, pouch? }`: the filled slots, each `{ slot, id, quantity, name, stackable }`, and the pouch's runes (`{ id, quantity, name, stackable }`) when the layout holds a pouch.

## InventoryLayout.from_client

Definition:
```luau
function InventoryLayout.from_client(name: string?): Layout?
```
A layout of what the inventory holds now, with the pouch's runes when it holds a pouch. Nil when the inventory can't be read. `stackable` is only known for a stack of more than one, which is all the bank needs.

## InventoryLayout.wanted

Definition:
```luau
function InventoryLayout.wanted(layout: Layout): { [number]: number }
```
How much of each item the layout holds, by id: a stack's quantity, else the number of copies.

## InventoryLayout.matches

Definition:
```luau
function InventoryLayout.matches(layout: Layout): boolean?
```
Whether the inventory holds at least the layout's amount of each of its items, and the pouch at least its runes. Slots don't count: see `reorder`. Nil when the inventory can't be read.

## InventoryLayout.deposit_diff

Definition:
```luau
function InventoryLayout.deposit_diff(layout: Layout): boolean
```
With the bank open, deposits everything that isn't in the layout, and what the inventory holds beyond the layout's amounts. True when all of it went in.

## InventoryLayout.withdraw

Definition:
```luau
function InventoryLayout.withdraw(layout: Layout): boolean
```
With the bank open, makes the inventory hold the layout: deposits what doesn't belong (`deposit_diff`), puts the layout's runes in the pouch, then takes each item the layout has more of than the inventory. True when the layout matches at the end. Everything the layout doesn't list is deposited, gear waiting to be worn included, so with an equipment layout too, get that worn first (`EquipmentLayout.prepare`) and fill the inventory after. The pouch comes out of the bank first when the inventory holds none, and its runes come out of the bank into the inventory; neither the bank (which offers only the pouch's own configuration screen) nor the pouch's menu fills it, so the bank is closed, each rune stack is used on the pouch (`Inventory.combine`, the pouch takes the whole stack), and the nearest bank is opened again before the rest is withdrawn.

## InventoryLayout.reorder

Definition:
```luau
function InventoryLayout.reorder(layout: Layout): boolean
```
Drags the items into the layout's slots, one slot at a time from the first, with the inventory tab open. True when every item of the layout sits where it says, or there was nothing to move; false when an item the layout wants in a slot isn't in the inventory outside the slots that already hold it for the layout.
