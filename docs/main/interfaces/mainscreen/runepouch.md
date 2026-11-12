# Main.Interfaces.Mainscreen.Runepouch

The rune pouch's contents and its transfer interface (group 190, "Open" on a pouch): pouch slots above, inventory below. Contents come from client variables, so reading needs neither the interface nor the pouch. The inventory disappears while the interface is open and returns shortly after it closes. To fill the pouch at the bank see [BankPouch](bankpouch.md) and [InventoryLayout](../../inventory_layout.md).

```luau
local Runepouch = require("@lib/main/interfaces/mainscreen/runepouch")
```

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
Widget ids (one child per slot), options, pouch item names, per-slot rune and amount varbits (rune is an index the enum maps to an item id), and the wait/poll times.

## Types

Definition:
```luau
export type Rune = { id: number, name: string, quantity: number }
export type Amount = number | "All"
```

## Runepouch.held

Definition:
```luau
function Runepouch.held(): boolean
```
Whether any pouch is in the inventory.

## Runepouch.runes

Definition:
```luau
function Runepouch.runes(): { Rune }?
```
The pouch's runes now, from varbits. Nil when they can't be read.

## Runepouch.quantity

Definition:
```luau
function Runepouch.quantity(rune: Item): number
```
How many of a rune (id or name) the pouch holds; 0 when none.

Example:
```luau
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
Opens the interface from a pouch in the inventory. True once open.

## Runepouch.close

Definition:
```luau
function Runepouch.close(): boolean
```
Closes the interface and waits for the inventory to return. True once it has.

## Runepouch.withdraw

Definition:
```luau
function Runepouch.withdraw(rune: Item, amount: Amount): boolean
```
With the interface open, moves 1, 5 or `"All"` of a rune to the inventory; other amounts return false (X needs typing). True once the pouch holds less.

## Runepouch.store

Definition:
```luau
function Runepouch.store(rune: Item, amount: Amount): boolean
```
With the interface open, moves 1, 5 or `"All"` of a rune from the inventory into the pouch; other amounts return false. True once the pouch holds more.

Example:
```luau
if Runepouch.open() then
	print(Runepouch.withdraw("Law rune", 5))
	print(Runepouch.store("Law rune", "All"))
	Runepouch.close()
end
```
