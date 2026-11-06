# Main.InventoryLayout

Inventory layouts: what an `inventory` form field gives a script, checked against and filled from the bank, with the rune pouch's runes.

```luau
local InventoryLayout = require("@lib/main/inventory_layout")
```

The user makes layouts in the loader, on the Inventory tab of the script's page: it reads the inventory from the client (and the runes in the rune pouch when the inventory holds one), keeps the layouts per script, and the form's `inventory` field picks one (see `Host.form` in [Host](../host.md)). A layout is positional, each item with its slot, but what matters to the bank is how much of each item it holds: a stack's range, or the number of copies of an item that doesn't stack. What counts as an item is its `ids`, or for a dose or charge item its accepted `doses` by name (see [LayoutItem](layout_item.md)), so four slots of `Prayer potion(4)` accepting doses 4 and 3 want four potions of either dose.

A field's `required` items are in every layout the user makes, padlocked: the user can drag them to another slot but not remove or change them, and they come with `locked = true`. A layout with no room for them (a full one saved before the script asked for them) can't be picked until the user frees a slot.

```luau
local Host = require("@lib/host")
local Bankmain = require("@lib/main/interfaces/mainscreen/bankmain")
local InventoryLayout = require("@lib/main/inventory_layout")

local values = Host.form({
	title = "Herblore",
	fields = {
		-- the vials of water start in slot 0; the user adds the rest
		{ id = "inventory", kind = "inventory", label = "Inventory", required = { { ids = { 227 }, slot = 0 } } },
	},
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
export type Entry = {
	items: { Item.Item },
	stackable: boolean,
	min: number,
	max: number,
	copies: number,
	label: string,
}
```
A layout is `{ name, slots, pouch? }`: the filled slots, each a `LayoutItem` with its `slot`, and the pouch's runes (`LayoutItem`s) when the layout holds a pouch. An `Entry` is one item as the bank sees it: what counts as it in the order to take it, its range when it stacks, and how many slots want it.

## InventoryLayout.from_client

Definition:
```luau
function InventoryLayout.from_client(name: string?): Layout?
```
A layout of what the inventory holds now, with the pouch's runes when it holds a pouch. Nil when the inventory can't be read. `stackable` is only known for a stack of more than one, which wants exactly what it holds.

## InventoryLayout.entries

Definition:
```luau
function InventoryLayout.entries(layout: Layout): { Entry }
```
The layout's items as the bank sees them: slots that want the same thing make one entry, `copies` the number of slots.

## InventoryLayout.matches

Definition:
```luau
function InventoryLayout.matches(layout: Layout): boolean?
```
Whether the inventory holds the layout: each stack in its range (any amount but none when both ends are 0), at least the number of copies of each other item, counting every accepted dose, and the pouch its runes in their ranges (a rune over its `max` counts, since the pouch can't give back part of a stack). Slots don't count: see `reorder`. Nil when the inventory can't be read.

## InventoryLayout.deposit_diff

Definition:
```luau
function InventoryLayout.deposit_diff(layout: Layout): boolean
```
With the bank open, deposits everything that isn't in the layout, which includes doses the layout doesn't accept (so a carried `Prayer potion(1)` goes back when only 4 and 3 count), and what the inventory holds beyond the layout: a stack over its `max`, and copies past the layout's number, the doses taken last going back first. True when all of it went in.

## InventoryLayout.withdraw

Definition:
```luau
function InventoryLayout.withdraw(layout: Layout): boolean
```
With the bank open, makes the inventory hold the layout: deposits what doesn't belong (`deposit_diff`), puts the layout's runes in the pouch, then takes what each item is missing: a stack below its `min` up to its `max` (all the bank has when both are 0 and the inventory holds none), and missing copies of the other items in the order of their accepted doses, each dose as far as the bank has it. True when the layout matches at the end. Everything the layout doesn't list is deposited, gear waiting to be worn included, so with an equipment layout too, get that worn first (`EquipmentLayout.prepare`) and fill the inventory after. The pouch comes out of the bank first when the inventory holds none, and its runes come out of the bank into the inventory; neither the bank (which offers only the pouch's own configuration screen) nor the pouch's menu fills it, so the bank is closed, each rune stack is used on the pouch (`Inventory.combine`, the pouch takes the whole stack), and the nearest bank is opened again before the rest is withdrawn.

## InventoryLayout.reorder

Definition:
```luau
function InventoryLayout.reorder(layout: Layout): boolean
```
Drags the items into the layout's slots, one slot at a time from the first, with the inventory tab open; a slot that holds anything counting as its item (any accepted dose) is left alone. True when every item of the layout sits where it says, or there was nothing to move; false when an item the layout wants in a slot isn't in the inventory outside the slots that already hold it for the layout.
