# Main.Interfaces.Mainscreen.Runepouch

The rune pouch: its runes, plus the interface that moves them (group 190), opened by "Open" on a pouch in the inventory, with the pouch's runes above and the inventory below.

```luau
local Runepouch = require("@lib/main/interfaces/mainscreen/runepouch")
```

The runes are in client variables, so reading doesn't need the interface. The interface takes the inventory away while it is open, and the inventory comes back a moment after it closes, so `close` waits for that. To fill the pouch from the bank see [InventoryLayout](../../inventory_layout.md).

## Constants

Definition:
```luau
Runepouch.GROUP = 190
Runepouch.FRAME = 1
Runepouch.POUCH = 4
Runepouch.INVENTORY = 7
Runepouch.OPTION = "Open"
Runepouch.CLOSE_OPTION = "Close"
Runepouch.POUCHES = { "Rune pouch", "Rune pouch (l)", "Divine rune pouch", "Divine rune pouch (l)" }
Runepouch.RUNE_VARBITS = { 29, 1622, 1623, 14285 }
Runepouch.AMOUNT_VARBITS = { 1624, 1625, 1626, 14286 }
Runepouch.RUNES_ENUM = 982
Runepouch.TIMEOUT_MS = 2500
Runepouch.POLL_MS = 50
```
The components, each with a child per slot by index; the pouches as the inventory names them; and the variables that hold each pouch slot's rune (a number the enum maps to an item id) and amount.

## Types

Definition:
```luau
export type Rune = { id: number, name: string, quantity: number }
export type Amount = number | "All"
```

A rune in the pouch and how many of it.

## Runepouch.held

Definition:
```luau
function Runepouch.held(): boolean
```
Whether a pouch is in the inventory.

## Runepouch.runes

Definition:
```luau
function Runepouch.runes(): { Rune }?
```
The runes in the pouch now, from the client's variables (they keep their values whether or not a pouch is in the inventory). Nil when they can't be read.

## Runepouch.quantity

Definition:
```luau
function Runepouch.quantity(rune: Item): number
```
How many of a rune the pouch holds, by id or name.

Example:
```luau
local Runepouch = require("@lib/main/interfaces/mainscreen/runepouch")

print(Runepouch.quantity("Law rune"))
```

## Runepouch.is_open

Definition:
```luau
function Runepouch.is_open(): boolean
```
Whether the interface is open.

## Runepouch.open

Definition:
```luau
function Runepouch.open(): boolean
```
Opens the interface from a pouch in the inventory. True when it is open.

## Runepouch.close

Definition:
```luau
function Runepouch.close(): boolean
```
Closes the interface and waits for the inventory to come back. True once it is usable.

## Runepouch.withdraw

Definition:
```luau
function Runepouch.withdraw(rune: Item, amount: Amount): boolean
```
With the interface open, takes a rune out to the inventory: 1, 5 or `"All"`. Other amounts return false, since the client's X option needs typing. True once the pouch holds less of it.

## Runepouch.store

Definition:
```luau
function Runepouch.store(rune: Item, amount: Amount): boolean
```
With the interface open, puts a rune from the inventory in the pouch: 1, 5 or `"All"`. True once the pouch holds more of it.

Example:
```luau
local Runepouch = require("@lib/main/interfaces/mainscreen/runepouch")

if Runepouch.open() then
	print(Runepouch.withdraw("Law rune", 5))
	print(Runepouch.store("Law rune", "All"))
	Runepouch.close()
end
```
