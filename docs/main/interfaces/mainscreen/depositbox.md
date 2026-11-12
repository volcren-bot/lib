# Main.Interfaces.Mainscreen.DepositBox

The bank deposit box (group 192): your 28 inventory slots, 11 worn slots, buttons that deposit the inventory, worn items or looting bag, and quantity buttons that set what one slot click deposits.

```luau
local DepositBox = require("@lib/main/interfaces/mainscreen/depositbox")
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
The group, the deposit box object name, and the button children. Any quantity of 0 or less deposits all, `QUANTITY_ALL_BUT_ONE` included.

## DepositBox.items

Definition:
```luau
DepositBox.items: Inv
```
The inventory as the box shows it (container 93, 28 slots); every [Inv](../inv.md) function works on it.

Example:
```luau
print(DepositBox.items.indices_of("Logs"))
```

## DepositBox.equipment

Definition:
```luau
DepositBox.equipment: Inv
```
Worn items as the box shows them (container 94, 14 slots, 11 shown); an [Inv](../inv.md).

Example:
```luau
print(DepositBox.equipment.items())
```

## DepositBox.is_open

Definition:
```luau
function DepositBox.is_open(): boolean
```
Whether the box is open (group open and its title contains "deposit").

Example:
```luau
print(DepositBox.is_open())
```

## DepositBox.title

Definition:
```luau
function DepositBox.title(): string?
```
The box's title text, `nil` when it isn't loaded.

Example:
```luau
print(DepositBox.title())
```

## DepositBox.wait_open

Definition:
```luau
function DepositBox.wait_open(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (3000 by default) for the box to open.

Example:
```luau
DepositBox.wait_open()
```

## DepositBox.bounds

Definition:
```luau
function DepositBox.bounds(): Box?
```
The box's panel.

Example:
```luau
print(DepositBox.bounds())
```

## DepositBox.slots_area

Definition:
```luau
function DepositBox.slots_area(): Box?
```
The inventory slot grid.

Example:
```luau
print(DepositBox.slots_area())
```

## DepositBox.find_item_boundaries

Definition:
```luau
function DepositBox.find_item_boundaries(): { Box }?
```
The boxes of occupied inventory slots, in slot order.

Example:
```luau
print(#(DepositBox.find_item_boundaries() or {}))
```

## DepositBox.quantity_of

Definition:
```luau
function DepositBox.quantity_of(amount: number): Quantity
```
The button for an amount: 1, 5, 10 have their own, 0 or less is `"ALL"`, the rest `"CUSTOM"`.

Example:
```luau
print(DepositBox.quantity_of(5)) -- FIVE
```

## DepositBox.quantity_selected

Definition:
```luau
function DepositBox.quantity_selected(quantity: Quantity): boolean
```
Whether the quantity button is lit (the current default).

Example:
```luau
print(DepositBox.quantity_selected("ALL"))
```

## DepositBox.select_quantity

Definition:
```luau
function DepositBox.select_quantity(quantity: Quantity): boolean
```
Clicks the quantity button unless lit, and waits up to 1800 ms for it to light.

Example:
```luau
DepositBox.select_quantity("TEN")
```

## DepositBox.select_quantity_async

Definition:
```luau
function DepositBox.select_quantity_async(quantity: Quantity, force: boolean?): boolean
```
Queues the click as async input and returns at once. `true` if already lit or queued, `false` if the button is missing. `force` clicks even when lit, for when an earlier queued click will change it.

Example:
```luau
DepositBox.select_quantity_async("ALL")
```

## DepositBox.click_button

Definition:
```luau
function DepositBox.click_button(button: DepositButton): boolean
```
Clicks `"WORN"`, `"INVENTORY"` or `"LOOT"` (empty containers). `false` when the box isn't open.

Example:
```luau
DepositBox.click_button("INVENTORY")
```

## DepositBox.deposit_inventory

Definition:
```luau
function DepositBox.deposit_inventory(): boolean
```
Clicks "Deposit inventory".

Example:
```luau
DepositBox.deposit_inventory()
```

## DepositBox.deposit_loot_bag

Definition:
```luau
function DepositBox.deposit_loot_bag(): boolean
```
Clicks "Empty containers", depositing the looting bag.

Example:
```luau
DepositBox.deposit_loot_bag()
```

## DepositBox.deposit_equipment

Definition:
```luau
function DepositBox.deposit_equipment(): boolean
```
Clicks "Deposit worn items".

Example:
```luau
DepositBox.deposit_equipment()
```

## DepositBox.close

Definition:
```luau
function DepositBox.close(key_probability: number?, timeout_ms: number?): boolean
```
Closes the box via `Toplevel.close`: Escape with chance `key_probability` (default the Escape biometric; 1 always, 0 never), else the close button. `timeout_ms` per try, 1800 by default.

Example:
```luau
DepositBox.close(0)
```

## DepositBox.deposit

Definition:
```luau
function DepositBox.deposit(item: Item, quantity: number?, use_quantity_buttons: boolean?): boolean
```
Deposits `quantity` (all when `nil` or 0 or less) of `item` from a random one of its slots. With `use_quantity_buttons` (default) it sets the quantity button then clicks; otherwise it uses the slot menu (`Deposit-N`, `Deposit-All`, or `Deposit-X` and types the amount). `false` when none is held.

Example:
```luau
DepositBox.deposit("Lobster")
```

## DepositBox.deposit_array

Definition:
```luau
function DepositBox.deposit_array(entries: { Entry }, use_quantity_buttons: boolean?): boolean
```
Deposits each entry (an item or `{ item, quantity }`), continuing past failures. `true` only if all succeeded.

Example:
```luau
DepositBox.deposit_array({ "Lobster", { item = "Swordfish", quantity = 5 } })
```

## DepositBox.deposit_different

Definition:
```luau
function DepositBox.deposit_different(keep: Item | { Item }, use_quantity_buttons: boolean?): boolean
```
Deposits all of every item kind not in `keep`, stopping at the first failure. `true` when nothing else remains to deposit.

Example:
```luau
DepositBox.deposit_different({ "Abyssal whip", "Bandos chestplate" })
```

## DepositBox.hover

Definition:
```luau
function DepositBox.hover(loc: Loc?, walk: boolean?): boolean
```
Hovers `loc` or the nearest deposit box, walking close first unless `walk` is false.

Example:
```luau
DepositBox.hover()
```

## DepositBox.open

Definition:
```luau
function DepositBox.open(loc: Loc?, walk: boolean?): boolean
```
Clears other interfaces with Escape, then uses "Deposit" on `loc` or the nearest box (walking unless `walk` is false) and waits up to 3 seconds. If a menu opened instead, picks "Deposit" when the hover text names a deposit box.

Example:
```luau
DepositBox.open()
```
