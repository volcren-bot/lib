# Main.Interfaces.Mainscreen.BankPouch

The rune pouch's panel in the bank: "Configure" on a pouch in the bank's inventory shows it in place of the inventory, in the bank's side interface (group 15). It has the pouch's runes, a "Deposit runes" button, ten loadouts in a scrolling list and "Dismiss" to go back to the inventory.

```luau
local BankPouch = require("@lib/main/interfaces/mainscreen/bankpouch")
```

While the panel shows, a rune withdrawn from the bank goes straight into the pouch instead of the inventory, so filling the pouch takes no trip out of the bank. The pouch's runes are read from [Runepouch](runepouch.md)'s client variables, so they don't need the panel. Everything else here needs the bank open and, except `open`, the panel too.

## Constants

Definition:
```luau
BankPouch.GROUP = 15
BankPouch.PANEL = 19
BankPouch.DEPOSIT_RUNES = 20
BankPouch.DISMISS = 22
BankPouch.RUNES = 26
BankPouch.LIST = 32
BankPouch.LOADOUTS = { 33, 37, 40, 43, 45, 47, 49, 51, 53, 55 }
BankPouch.NAMES = { 34, 38, 41, 44, 46, 48, 50, 52, 54, 56 }
BankPouch.LAST_CHILD = 120
BankPouch.SLOTS = 4
BankPouch.EMPTY_SLOT = 11526
BankPouch.UNNAMED = "-"
BankPouch.OPTION = "Configure"
BankPouch.DISMISS_OPTION = "Dismiss"
BankPouch.DEPOSIT_RUNES_OPTION = "Deposit runes"
BankPouch.LOAD_OPTION = "Load"
BankPouch.AMOUNT_QUERY = "Enter amount"
BankPouch.MAX_SCROLLS = 12
BankPouch.TIMEOUT_MS = 2500
BankPouch.POLL_MS = 50
```
The bank's side interface and, in it, the panel (hidden while the inventory shows), its buttons, and the pouch's rune cells: children 1 to 4 of `RUNES`, each showing its rune and amount, and an empty cell another item. `LIST` is the scrolling list of loadouts: each row in `LOADOUTS` has a cell per slot as children 1 to 4 (the empty-slot item `EMPTY_SLOT` where no rune is set), its name as child 1 of the matching `NAMES` component (`UNNAMED` until the player names it), and a Load button somewhere in the panel up to `LAST_CHILD` whose parent is the row. Then the menu options, the query the client asks for a typed amount, and how far to scroll and how long to wait for each step, and between looks.

## Types

Definition:
```luau
export type Loadout = { number: number, name: string?, runes: { number } }
```
A loadout: its place in the list from 1, its name (nil while unnamed), and the item ids of its runes in slot order, empty slots left out.

## BankPouch.is_open

Definition:
```luau
function BankPouch.is_open(): boolean
```
Whether the bank is open with the panel showing, read from the panel's own component, which the client hides with all its contents when the inventory shows.

## BankPouch.open / BankPouch.close

Definition:
```luau
function BankPouch.open(timeout_ms: number?): boolean
function BankPouch.close(timeout_ms: number?): boolean
```
`open` picks "Configure" on the first pouch in the bank's inventory (`Bankmain.inventory`) and waits for the panel; false when the bank isn't open or the inventory holds no pouch. `close` clicks Dismiss and waits for the inventory to come back. Each is true at once when the panel already is that way.

Example:
```luau
local BankPouch = require("@lib/main/interfaces/mainscreen/bankpouch")

if BankPouch.open() then
	BankPouch.close()
end
```

## BankPouch.withdraw

Definition:
```luau
function BankPouch.withdraw(rune: Item, amount: number?): boolean
```
Takes a rune from the bank into the pouch (`Bankmain.withdraw`, which puts it in the pouch while the panel shows). True once the pouch holds more of it.

Example:
```luau
local BankPouch = require("@lib/main/interfaces/mainscreen/bankpouch")

if BankPouch.open() then
	BankPouch.withdraw("Law rune", 500)
	BankPouch.close()
end
```

## BankPouch.deposit / BankPouch.deposit_runes

Definition:
```luau
function BankPouch.deposit(rune: Item, amount: number?): boolean
function BankPouch.deposit_runes(): boolean
```
`deposit` puts some of a rune from the pouch back in the bank from its cell: 1, 5, 10 or the bank's custom amount by their own options, any other amount by Deposit-X and the typed amount, and all of it with no amount or one at least what the pouch holds. True once the pouch holds less of it; false when it holds none. `deposit_runes` empties the pouch into the bank with the panel's button, true once the pouch is empty (at once when it is).

## BankPouch.loadouts

Definition:
```luau
function BankPouch.loadouts(): { Loadout }?
```
The ten loadouts, from the panel's cells, whether or not their row is scrolled into view. Nil while the panel isn't open.

## BankPouch.load

Definition:
```luau
function BankPouch.load(which: number | string): boolean
```
Loads a loadout, by its number or its name (any case): scrolls its row into view over the list, clicks its Load, and waits until the pouch holds exactly the loadout's runes. False for an empty or missing loadout, or when the row can't be shown.

Example:
```luau
local BankPouch = require("@lib/main/interfaces/mainscreen/bankpouch")

if BankPouch.open() then
	for _, loadout in ipairs(BankPouch.loadouts() or {}) do
		print(loadout.number, loadout.name, #loadout.runes)
	end
	BankPouch.load(1)
	BankPouch.close()
end
```

## BankPouch.open

Definition:
```luau
function BankPouch.open(timeout_ms: number?): boolean
```
TODO...

Example:
```luau

```

## BankPouch.close

Definition:
```luau
function BankPouch.close(timeout_ms: number?): boolean
```
TODO...

Example:
```luau

```

## BankPouch.deposit_runes

Definition:
```luau
function BankPouch.deposit_runes(): boolean
```
TODO...

Example:
```luau

```

## BankPouch.deposit

Definition:
```luau
function BankPouch.deposit(rune: Item, amount: number?): boolean
```
TODO...

Example:
```luau

```
