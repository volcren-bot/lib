# Main.LayoutItem

The items of equipment and inventory layouts: what counts as one, and how much of a stack it wants. [EquipmentLayout](equipment_layout.md) and [InventoryLayout](inventory_layout.md) are built on it.

```luau
local LayoutItem = require("@lib/main/layout_item")
```

A layout item (`Host.LayoutItem`) counts as any of its `ids`, in the order the bank takes them. For an item that doesn't stack, the loader adds the ids of every other item with exactly its name, which the user can untick: a degradable item such as the Crystal halberd keeps its name but changes id once used. A dose or charge item, one whose name ends in a number in brackets (`Prayer potion(4)`, `Amulet of glory(6)`, `Black mask (10)`), carries `doses` instead: the numbers that count, in the order the bank takes them. A family's ids aren't in any order (`Prayer potion(4)` is 2434, `Prayer potion(3)` is 139), so these items are matched by name: the family is the name without its number, from the layout or from the client (`Item.name`). The loader finds which numbers a family has from every item name in the client's cache, leaving out notes, placeholders and bought copies, so no id is written down anywhere.

A stack wants `min` to `max` of it: equal ends want exactly that many, and both 0 want any amount but at least one. A `min` of 0 with a `max` makes the stack optional, but no more than `max`.

```luau
local Host = require("@lib/host")
local LayoutItem = require("@lib/main/layout_item")
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

local values = Host.form({ title = "Fletcher", fields = { { id = "inventory", kind = "inventory" } } })
local layout = values and values.inventory
if layout then
	for _, slot in ipairs(layout.slots) do
		local have = Inventory.count_ex(LayoutItem.items(slot)) or 0
		if slot.stackable and not LayoutItem.in_range(slot, have) then
			print(`{slot.name}: {have}, take {LayoutItem.top_up(slot, have)} or put back {LayoutItem.excess(slot, have)}`)
		end
	end
end
```

## Types

Definition:
```luau
export type Wanted = {
	id: number?,
	ids: { number }?,
	name: string?,
	stackable: boolean?,
	min: number?,
	max: number?,
	doses: { number }?,
}
```
What an inventory slot and an equipment slot share; an equipment slot that wants no item has no `id`.

## LayoutItem.base

Definition:
```luau
function LayoutItem.base(item: Wanted): string?
```
The family of a dose or charge item: its name without the number, `Prayer potion` for `Prayer potion(4)`. The name comes from the client when the layout has none. Nil when the name ends in no number.

## LayoutItem.items

Definition:
```luau
function LayoutItem.items(item: Wanted): { Item.Item }
```
What counts as the item, in the order the bank takes it: each accepted dose by name (`{ "Prayer potion(4)", "Prayer potion(3)" }`), else its ids. Every `Item.Item` list function of the inventory and the bank takes it.

## LayoutItem.counts_as

Definition:
```luau
function LayoutItem.counts_as(item: Wanted, id: number, name: string?): boolean
```
Whether an item, by id and name (asked of the client when a dose needs it and `name` is nil), counts as the layout's item.

## LayoutItem.in_range

Definition:
```luau
function LayoutItem.in_range(item: Wanted, have: number): boolean
```
Whether `have` of a stack is what it wants: `min` to `max`, or more than none when both are 0.

## LayoutItem.top_up

Definition:
```luau
function LayoutItem.top_up(item: Wanted, have: number): number?
```
How many of a stack to take out of the bank: up to `max` once below `min`, 0 (all of it) when both are 0 and there is none, nil when no withdrawal is needed. Topping up to `max` rather than to `min` means fewer trips.

## LayoutItem.excess

Definition:
```luau
function LayoutItem.excess(item: Wanted, have: number): number
```
How many of a stack are over its `max` (0 without a `max`).
