# Main.EquipmentLayout

Equipment layouts: what an `equipment` form field gives a script, checked against and put on with the worn items, the inventory and the bank.

```luau
local EquipmentLayout = require("@lib/main/equipment_layout")
```

The user makes layouts in the loader, on the Equipment tab of the script's page: it reads the worn items from the client, keeps the layouts per script, and the form's `equipment` field picks one (see `Host.form` in [Host](../host.md)). A layout lists every worn items slot once: it wants an item there (`mode = "item"`, by id, as the client held it), nothing there (`empty`) or doesn't care (`any`). The script never has to guess an id. Some items are worn under another id than they are held in the inventory and the bank (graceful pieces: 13624 worn, 13623 held), so the inventory and the bank are searched by the slot's id or its name.

```luau
local Host = require("@lib/host")
local EquipmentLayout = require("@lib/main/equipment_layout")

local values = Host.form({
	title = "Slayer",
	fields = { { id = "equipment", kind = "equipment", label = "Equipment" } },
})
local layout = values and values.equipment
if layout and not EquipmentLayout.prepare(layout) then
	print("couldn't get the equipment on")
end
```

The Equipment tab always has the secondary ammo slot (`Wornitems.SECONDARY_AMMO`), because a layout can't know whether the account will have a bolt pouch in its inventory or Dizana's quiver. Without one the slot is ignored everywhere here, and so is an item a pouch can't store, such as arrows. A layout that wears a quiver counts as having the slot, so its ammo comes out of the bank with the quiver. For a pouch, have it in the inventory first. See [Wornitems](interfaces/gametabs/wornitems.md).

The layout can carry a spell, picked on the same tab from the three books with combat spells. When the weapon read into the layout offered autocast (a staff), it is the autocast spell and `prepare` sets it on the combat tab; otherwise it is a spell for the script to cast by hand (`spell` gives it as the spellbook knows it).

## Constants

Definition:
```luau
EquipmentLayout.EQUIP_TIMEOUT_MS = 2500
EquipmentLayout.POLL_MS = 50
EquipmentLayout.SLOTS: { number }
```
How long to wait for the worn items to change after a click and between looks, and the worn items slots a layout lists (`Wornitems.HEAD` to `Wornitems.AMMO`, in the container's order, then `Wornitems.SECONDARY_AMMO`).

## Types

Definition:
```luau
export type Layout = Host.EquipmentLayout
export type Slot = Host.EquipmentLayoutSlot
```
A layout is `{ name, slots, spell? }`; a slot is `{ slot, mode, id?, quantity?, name?, stackable? }`, the item fields set when `mode` is `"item"`; the spell is `{ key, name, book, level, autocast }`.

## EquipmentLayout.from_client

Definition:
```luau
function EquipmentLayout.from_client(name: string?): Layout?
```
A layout of what is worn now: every slot its item, or `empty`, and `any` for a secondary ammo slot nothing gives. Nil when the worn items can't be read. `stackable` is only known for a stack of more than one, which is all the bank needs.

## EquipmentLayout.matches

Definition:
```luau
function EquipmentLayout.matches(layout: Layout): boolean?
```
Whether every slot of the layout holds: its item worn (by id, the quantity of ammo doesn't count), or nothing worn where it wants nothing. A secondary ammo slot that doesn't count is ignored. Nil when the worn items can't be read.

## EquipmentLayout.missing

Definition:
```luau
function EquipmentLayout.missing(layout: Layout): { Slot }
```
The slots whose item is neither worn (the other ammo slot counts, being a swap away) nor in the inventory: what has to come out of the bank. A secondary ammo slot that doesn't count isn't listed. Bolts stored in the pouch's other rows aren't looked at.

## EquipmentLayout.withdraw

Definition:
```luau
function EquipmentLayout.withdraw(layout: Layout): boolean
```
With the bank open, withdraws each missing item (a stack's whole quantity, else one). True when none is missing afterwards. The items wait in the inventory for `equip`, so wear them before `InventoryLayout.withdraw`, which deposits whatever its layout doesn't list.

## EquipmentLayout.equip

Definition:
```luau
function EquipmentLayout.equip(layout: Layout): boolean
```
Wears each of the layout's items from the inventory, clicking them in one of the inventory's patterns (`Inventory.random_pattern`), then takes off what is worn where the layout wants nothing. The bank must be closed, since a click in the inventory would deposit. True when the layout matches afterwards. An item that isn't in the inventory, or no room to take something off, fails it.

With the secondary ammo slot in play the ammo comes last, because an item only reaches that slot through the worn ammo slot: it is worn, then swapped across (`Wornitems.swap_ammo`), which leaves the slot's old ammo worn, and the ammo slot's own item replaces that.

## EquipmentLayout.spell

Definition:
```luau
function EquipmentLayout.spell(layout: Layout): Magic.Spell?
```
The layout's spell as the spellbook knows it ([Magic](interfaces/gametabs/magic.md)), nil when the layout has none or the book can't be read. For a spell to cast by hand, this is what `Magic.cast` takes.

## EquipmentLayout.autocasts

Definition:
```luau
function EquipmentLayout.autocasts(layout: Layout): boolean
```
Whether the layout's spell is one to autocast: the weapon read into the layout offered autocast.

## EquipmentLayout.set_autocast

Definition:
```luau
function EquipmentLayout.set_autocast(layout: Layout, defensive: boolean?): boolean
```
Sets the layout's spell as the autocast, defensively with `defensive`, through the combat tab ([Combat](interfaces/gametabs/combat.md)). True when the layout has no spell to autocast, or once it is set; false when the wielded weapon's picker doesn't offer it.

## EquipmentLayout.prepare

Definition:
```luau
function EquipmentLayout.prepare(layout: Layout): boolean
```
Gets the layout worn: nothing when it matches already; with the bank open it withdraws what is missing and closes the bank; then equips, and sets the autocast spell when the layout has one. True when the layout matches at the end.
