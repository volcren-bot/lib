# Main.EquipmentLayout

Equipment layouts from a form's `equipment` field: checked against the worn items and put on from the inventory and bank.

```luau
local EquipmentLayout = require("@lib/main/equipment_layout")
```

The user builds layouts per script on the loader's Equipment tab, read from the worn items; the form's `equipment` field picks one (see `Host.form` in [Host](../host.md)). Each worn slot is listed once as `mode = "item"` (by `ids`), `"empty"` or `"any"`. Some items have a different held id than worn id (graceful: 13624 worn, 13623 held), so the inventory and bank are searched by ids or name. Dose/charge items count by accepted `doses` and are withdrawn in that order ([LayoutItem](layout_item.md)). A worn stack (ammo) wants at least `min` and is topped up to `max`; one over `max` stays, since only all of it can be removed.

A field's `required` items, each with a `slot`, replace that slot in every layout, padlocked (`locked = true`).

The secondary ammo slot (`Wornitems.SECONDARY_AMMO`) is always listed. Without a bolt pouch in the inventory or a worn quiver it is ignored everywhere, as is an item the pouch can't hold (arrows). A quiver's ammo comes out of the bank with it; a pouch must already be carried. See [Wornitems](interfaces/gametabs/wornitems.md).

A layout can carry a combat spell. If the weapon read into it offered autocast, `prepare` sets it as the autocast; otherwise `spell` gives it for the script to cast.

```luau
local Host = require("@lib/host")
local EquipmentLayout = require("@lib/main/equipment_layout")

local values = Host.form({
	title = "Slayer",
	fields = {
		{ id = "equipment", kind = "equipment", label = "Equipment", required = { { ids = { 11978 }, slot = 2, doses = { 6, 5, 4, 3, 2, 1 } } } },
	},
})
local layout = values and values.equipment
if layout and not EquipmentLayout.prepare(layout) then
	print("couldn't get the equipment on")
end
```

## Constants

Definition:
```luau
EquipmentLayout.EQUIP_TIMEOUT_MS = 2500
EquipmentLayout.POLL_MS = 50
EquipmentLayout.CONFIRM_MS = 1200
EquipmentLayout.WEAR_ATTEMPTS = 3
EquipmentLayout.SWAP_MOUSE_PACE = 1.2
EquipmentLayout.STOP_POLL_MS = 30
EquipmentLayout.SLOTS: { number }
```
- `EQUIP_TIMEOUT_MS`, `POLL_MS`: wait and poll after taking off or moving ammo.
- `CONFIRM_MS`, `WEAR_ATTEMPTS`: `equip`'s wait per round and maximum rounds.
- `SWAP_MOUSE_PACE`: `equip`'s mouse speed relative to `Mouse.pace` (1.2 is 20% faster).
- `STOP_POLL_MS`: how often `equip` checks `stop`.
- `SLOTS`: the listed slots, `Wornitems.HEAD` to `Wornitems.AMMO` in container order, then `Wornitems.SECONDARY_AMMO`.

## Types

Definition:
```luau
export type Layout = Host.EquipmentLayout
export type Slot = Host.EquipmentLayoutSlot
export type EquipOptions = { stop: (() -> boolean)?, after_clicks: (() -> ())? }
```
A layout is `{ name, slots, spell? }`; a slot is `{ slot, mode }` plus `LayoutItem` fields (`id`, `ids`, `name`, `stackable`, `min`, `max`, `doses`, `locked`) when `mode` is `"item"`; the spell is `{ key, name, book, level, autocast }`.

## EquipmentLayout.from_client

Definition:
```luau
function EquipmentLayout.from_client(name: string?): Layout?
```
A layout of what is worn now: items, `empty`, and `any` for an unusable secondary ammo slot. Nil when the worn items can't be read. `stackable` is only known for stacks over one, which want exactly what is worn.

Example:
```luau
local layout = EquipmentLayout.from_client("current")
```

## EquipmentLayout.matches

Definition:
```luau
function EquipmentLayout.matches(layout: Layout): boolean?
```
Whether every slot holds: an accepted item worn (a stack at least `min`) or nothing where `empty`. An unusable secondary ammo slot is ignored. Nil when the worn items can't be read.

Example:
```luau
print(EquipmentLayout.matches(layout))
```

## EquipmentLayout.missing

Definition:
```luau
function EquipmentLayout.missing(layout: Layout): { Slot }
```
Slots that must come from the bank: the item is neither worn (the other ammo slot counts) nor carried, or worn plus carried stack is under `min`. Bolts in the pouch's other rows aren't counted.

Example:
```luau
for _, s in ipairs(EquipmentLayout.missing(layout)) do
	print(s.name)
end
```

## EquipmentLayout.withdraw

Definition:
```luau
function EquipmentLayout.withdraw(layout: Layout): boolean
```
With the bank open, withdraws each missing item: a stack up to `max` counting worn and carried (all of it when both ends are 0), else one of the first accepted item the bank has. True when nothing is missing afterwards. Items wait in the inventory, so `equip` before `InventoryLayout.withdraw`, which would deposit them.

Example:
```luau
EquipmentLayout.withdraw(layout)
```

## EquipmentLayout.equip

Definition:
```luau
function EquipmentLayout.equip(layout: Layout, options: EquipOptions?): boolean
```
Wears each item from the inventory, then removes what is worn in `empty` slots. Items are clicked in `Inventory.pattern` order from the mouse, without waits, through the async mouse queue; it then waits up to `CONFIRM_MS` and re-clicks what didn't change, `WEAR_ATTEMPTS` rounds at most. Blocks until done. `options.stop` is checked every `STOP_POLL_MS`; when true, queued clicks are dropped and it returns false with the layout partly worn. `options.after_clicks` runs once after the first round of clicks, during the wait (e.g. hovering the next target). The bank must be closed. False when an item isn't carried or there's no room to take something off.

Secondary ammo goes last: it is worn, swapped across (`Wornitems.swap_ammo`), then the ammo slot's own item replaces what came back.

Example:
```luau
local deadline = os.clock() + 5
EquipmentLayout.equip(layout, { stop = function()
	return os.clock() > deadline
end })
```

## EquipmentLayout.spell

Definition:
```luau
function EquipmentLayout.spell(layout: Layout): Magic.Spell?
```
The layout's spell as [Magic](interfaces/gametabs/magic.md) knows it, for `Magic.cast`. Nil when there is none or the book can't be read.

Example:
```luau
local spell = EquipmentLayout.spell(layout)
if spell and not EquipmentLayout.autocasts(layout) then
	Magic.cast(spell)
end
```

## EquipmentLayout.autocasts

Definition:
```luau
function EquipmentLayout.autocasts(layout: Layout): boolean
```
Whether the layout's spell is an autocast spell.

Example:
```luau
print(EquipmentLayout.autocasts(layout))
```

## EquipmentLayout.set_autocast

Definition:
```luau
function EquipmentLayout.set_autocast(layout: Layout, defensive: boolean?): boolean
```
Sets the spell as autocast through [Combat](interfaces/gametabs/combat.md), defensively with `defensive`. True when there is no autocast spell or once set; false when the weapon doesn't offer it.

Example:
```luau
EquipmentLayout.set_autocast(layout, true)
```

## EquipmentLayout.prepare

Definition:
```luau
function EquipmentLayout.prepare(layout: Layout): boolean
```
Gets the layout worn: if the bank is open, withdraws and closes it; then equips and sets the autocast. Fails when items are missing and the bank isn't open. True when the layout matches at the end.

Example:
```luau
EquipmentLayout.prepare(layout)
```
