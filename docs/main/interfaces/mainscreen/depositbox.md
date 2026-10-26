# Main.Interfaces.Mainscreen.DepositBox

The bank's item deposit box (interface group 192). Its 28 slots show your inventory, which is what the deposits come from, and its 11 equipment slots show your worn items. The buttons under them deposit the inventory, the worn items or the looting bag, and the quantity buttons on the right set how many one click deposits.

```luau
local DepositBox = require("../main/interfaces/mainscreen/depositbox")
```

## Constants

Definition:
```luau
DepositBox.GROUP = 192
DepositBox.OBJECT_NAME = "Bank deposit box"
DepositBox.DEPOSIT_BUTTONS = { WORN = 30, INVENTORY = 31, LOOT = 32 }
DepositBox.QUANTITY_BUTTONS = { ONE = 35, FIVE = 36, TEN = 37, CUSTOM = 38, ALL = 39 }
DepositBox.QUANTITY_ALL = 0
DepositBox.QUANTITY_ALL_BUT_ONE = -1
```
The interface group, the name of the deposit box loc, and the components of the buttons (`DEPOSIT_BUTTONS` and `QUANTITY_BUTTONS` are the components' child ids in group 192). Quantities of 0 or less mean all of the item, `QUANTITY_ALL_BUT_ONE` included.

## DepositBox.items

Definition:
```luau
DepositBox.items: Inv
```
The inventory as the deposit box shows it (container 93, 28 slots). Every function of [Inv](../inv.md) works on it, such as `DepositBox.items.indices_of("Logs")`, `DepositBox.items.hover_slot(slot)` or `DepositBox.items.items()`.

## DepositBox.equipment

Definition:
```luau
DepositBox.equipment: Inv
```
The worn items as the deposit box shows them (container 94, 14 slots, of which 11 are on the box). Everything [Inv](../inv.md) has works on it.

## DepositBox.is_open

Definition:
```luau
function DepositBox.is_open(): boolean
```
Whether the deposit box is open.

Example:
```luau
local open = DepositBox.is_open()
print(open)
```

## DepositBox.title

Definition:
```luau
function DepositBox.title(): string?
```
The deposit box's title, such as "The Bank of Gielinor - Item Deposits".

## DepositBox.wait_open

Definition:
```luau
function DepositBox.wait_open(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (3 seconds by default) for the deposit box to open. Returns false when it didn't.

## DepositBox.bounds

Definition:
```luau
function DepositBox.bounds(): Box?
```
The deposit box's panel, in interface units.

## DepositBox.slots_area

Definition:
```luau
function DepositBox.slots_area(): Box?
```
The area of the inventory slot grid.

## DepositBox.find_item_boundaries

Definition:
```luau
function DepositBox.find_item_boundaries(): { Box }?
```
The boxes of the inventory slots that hold an item, in slot order.

## DepositBox.quantity_of

Definition:
```luau
function DepositBox.quantity_of(amount: number): Quantity
```
The quantity button an amount uses: 1, 5 and 10 have their own buttons, 0 or less is `"ALL"`, anything else is `"CUSTOM"`.

Example:
```luau
print(DepositBox.quantity_of(5)) -- FIVE
```

## DepositBox.quantity_selected

Definition:
```luau
function DepositBox.quantity_selected(quantity: Quantity): boolean
```
Whether the quantity button is the default one: its frame is lit.

## DepositBox.select_quantity

Definition:
```luau
function DepositBox.select_quantity(quantity: Quantity): boolean
```
Makes `quantity` the default by clicking its button, unless it already is, and waits for it to light.

## DepositBox.select_quantity_async

Definition:
```luau
function DepositBox.select_quantity_async(quantity: Quantity, force: boolean?): boolean
```
Like `DepositBox.select_quantity`, but queues the click as async input and returns at once, without waiting for the button to light. Returns `true` if the quantity is selected or the click was queued, `false` if its button isn't there. `force` clicks even when it is selected now, for a quantity that an earlier queued click leaves.

Example:
```luau
local DepositBox = require("../main/interfaces/mainscreen/depositbox")

print(DepositBox.select_quantity_async("ALL"))
```

## DepositBox.click_button

Definition:
```luau
function DepositBox.click_button(button: DepositButton): boolean
```
Clicks one of the deposit buttons: `"WORN"` (deposit worn items), `"INVENTORY"` (deposit inventory) or `"LOOT"` (empty containers, the looting bag). Does nothing unless the box is open.

## DepositBox.deposit_inventory

Definition:
```luau
function DepositBox.deposit_inventory(): boolean
```
Clicks "Deposit inventory".

## DepositBox.deposit_loot_bag

Definition:
```luau
function DepositBox.deposit_loot_bag(): boolean
```
Clicks "Empty containers", which deposits the looting bag.

## DepositBox.deposit_equipment

Definition:
```luau
function DepositBox.deposit_equipment(): boolean
```
Clicks "Deposit worn items".

## DepositBox.close

Definition:
```luau
function DepositBox.close(key_probability: number?, timeout_ms: number?): boolean
```
Closes the box and waits for it to close (`timeout_ms` for each try, 3 ticks by default). It presses Escape with the chance `key_probability` (by default the `Biometrics.ESCAPE` probability; `1` always, `0` never), unless the client's "Esc to close" setting is off. If that doesn't close it, or Escape isn't used, it clicks the close button, up to 3 times. See `Toplevel.close`.

Example:
```luau
DepositBox.close(0) -- with the mouse
```

## DepositBox.deposit

Definition:
```luau
function DepositBox.deposit(item: Item, quantity: number?, use_quantity_buttons: boolean?): boolean
```
Deposits `quantity` of `item` from your inventory (all of it when `quantity` is 0 or less or nil). It picks one of the item's slots at random. With `use_quantity_buttons` (the default) it sets the quantity button first and then clicks the slot; without, it uses the slot's menu (`Deposit-1`, `Deposit-5`, `Deposit-10`, `Deposit-All`, or `Deposit-X` and the amount typed into the chat). Returns false when your inventory has none of the item.

Example:
```luau
DepositBox.deposit("Lobster", 0, true)
```

## DepositBox.deposit_array

Definition:
```luau
function DepositBox.deposit_array(entries: { Entry }, use_quantity_buttons: boolean?): boolean
```
Deposits each entry, an item name or `{ item = ..., quantity = ... }`, and carries on past a failure. Returns true when all of them went in, and the first error otherwise.

Example:
```luau
DepositBox.deposit_array({ "Lobster", { item = "Swordfish", quantity = 5 } }, true)
```

## DepositBox.deposit_different

Definition:
```luau
function DepositBox.deposit_different(keep: Item | { Item }, use_quantity_buttons: boolean?): boolean
```
Deposits every inventory item that isn't one of `keep`, all of each kind. Returns true when there was nothing else to deposit or all of it went in.

Example:
```luau
DepositBox.deposit_different({ "Abyssal whip", "Bandos chestplate", "Bandos tassets" })
```

## DepositBox.hover

Definition:
```luau
function DepositBox.hover(loc: Loc?, walk: boolean?): boolean
```
Hovers the deposit box loc, which is the closest one on the loaded map by default. With `walk` (the default) it walks close to the loc first.

Example:
```luau
DepositBox.hover()
```

## DepositBox.open

Definition:
```luau
function DepositBox.open(loc: Loc?, walk: boolean?): boolean
```
Opens the deposit box by picking its "Deposit" option on the loc (the closest one by default). It walks there unless `walk` is false, and waits up to 3 seconds for the box to show. Other main-screen interfaces are closed first with Escape.

Example:
```luau
DepositBox.open()
```
