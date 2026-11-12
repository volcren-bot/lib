# Main.LayoutItem

Items of equipment and inventory layouts: what counts as one and how much of a stack it wants. [EquipmentLayout](equipment_layout.md) and [InventoryLayout](inventory_layout.md) build on it.

```luau
local LayoutItem = require("@lib/main/layout_item")
```

A layout item counts as any of its `ids`, in the order the bank takes them; for non-stackables the loader adds every other id with the same name (degradables change id but keep the name). A dose or charge item, whose name ends in a bracketed number (`Prayer potion(4)`, `Black mask (10)`), carries `doses` instead and is matched by name, since a family's ids are unordered. A stack wants `min` to `max`: equal ends want exactly that many, both 0 want at least one, and `min` 0 with a `max` makes it optional but capped.

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
What inventory and equipment slots share; an empty equipment slot has no `id`.

## LayoutItem.base

Definition:
```luau
function LayoutItem.base(item: Wanted): string?
```
The name without its bracketed number (`Prayer potion` for `Prayer potion(4)`), using `Item.name(id)` when the layout has no name. Nil when the name ends in no number.

## LayoutItem.items

Definition:
```luau
function LayoutItem.items(item: Wanted): { Item.Item }
```
What counts as the item in bank order: each dose by name (`{ "Prayer potion(4)", "Prayer potion(3)" }`), else `ids`, else `id`. Any `Item.Item` list function of the inventory or bank takes it.

Example:
```luau
local have = Inventory.count_ex(LayoutItem.items(slot)) or 0
if slot.stackable and not LayoutItem.in_range(slot, have) then
	print(LayoutItem.top_up(slot, have), LayoutItem.excess(slot, have))
end
```

## LayoutItem.counts_as

Definition:
```luau
function LayoutItem.counts_as(item: Wanted, id: number, name: string?): boolean
```
Whether an item counts as the layout's item; `name` is read from the client when matching needs it and it is nil.

## LayoutItem.in_range

Definition:
```luau
function LayoutItem.in_range(item: Wanted, have: number): boolean
```
Whether `have` is within `min` to `max`, or above 0 when both are 0.

## LayoutItem.top_up

Definition:
```luau
function LayoutItem.top_up(item: Wanted, have: number): number?
```
How many to withdraw: `max - have` once below `min`, 0 (all) when both are 0 and there is none, nil when nothing is needed.

## LayoutItem.excess

Definition:
```luau
function LayoutItem.excess(item: Wanted, have: number): number
```
How many are over `max`; 0 without a `max`.
