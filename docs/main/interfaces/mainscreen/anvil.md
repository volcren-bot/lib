# Main.Interfaces.Mainscreen.Anvil

The smithing window an anvil opens with "Smith" (group 312, `smithing` in the cache): one slot per item the bars in the inventory make, and the quantity buttons on the right.

```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")
```

Everything is read from the interface. Script 431 builds each slot: the bar count is green when the inventory holds enough bars and orange when it doesn't, and the item's name is black, without a shadow, when the Smithing level is too low (white otherwise). The slot the game highlights is the item Space smiths, and only shows when there are enough bars for it. Sets (nails, dart tips, arrowtips, knives, javelin tips, bolts) use "Smith set" instead of "Smith".

The window doesn't close on Escape, even with "Esc to close" on, so `close` always clicks the button. A script that calls `Toplevel.escape_clear` while the anvil is open has Escape fail three times, which turns Escape off for the rest of the run.

A `Slot` is `{ child, id, name, label, makes, bars, enough_bars, available, highlighted, option, area }`: `name` is the item's full name from the cache (`"Iron platebody"`), `label` what the slot shows (`"Platebody"`), `makes` how many one smith makes (15 nails), `bars` the bars one smith takes, `available` whether the level allows it, `option` the slot's menu option and `area` the slot to click. Items are given by name or id, like the rest of the lib.

A `Button` is `{ child, label, selected, area }`, with `label` one of `1`, `5`, `10`, `X`, `All` or the last amount typed for X.

## Constants

Definition:
```luau
Anvil.GROUP = 312
Anvil.FRAME = 1
Anvil.TITLE_INDEX = 1
Anvil.CLOSE_INDEX = 11
Anvil.QUANTITY_CHILDREN = { 3, 4, 5, 6, 7, 8 }
Anvil.FIRST_SLOT = 9
Anvil.LAST_SLOT = 38
Anvil.OBJECT = "anvil"
Anvil.OPTION = "Smith"
Anvil.QUANTITY_OPTION = "Quantity:"
Anvil.QUERY = "Enter amount"
Anvil.UNAVAILABLE_COLOR = 0x000000
Anvil.ENOUGH_BARS_COLOR = 0x00ff00
Anvil.KEY_CHANCE = 0.5
Anvil.OPEN_TIMEOUT_MS = 4000
Anvil.QUANTITY_TIMEOUT_MS = 1500
Anvil.CLOSE_TIMEOUT_MS = 2400
Anvil.MADE_TIMEOUT_MS = 3600
Anvil.POLL_MS = 50
```
The interface piece numbers, what anvils are called, the anvil's option and the quantity buttons' option, the prompt X opens, the name colour of an item the level is too low for and the bar colour of one there are enough bars for, the chance a biometric is rolled around for pressing Space rather than clicking, and the waits: for `wait_open`, for a quantity to be selected, for the window to close after a smith and then for the first item to land, and between looks.

## Anvil.is_open

Definition:
```luau
function Anvil.is_open(): boolean
```
Whether the smithing window is open.

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

print("anvil open:", Anvil.is_open())
```

## Anvil.wait_open

Definition:
```luau
function Anvil.wait_open(timeout_ms: number?): boolean
```
Whether the window is open, polled for up to `timeout_ms` (4 seconds by default).

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

print(Anvil.wait_open(2000))
```

## Anvil.title

Definition:
```luau
function Anvil.title(): string?
```
The window's title, `"What would you like to make?"`. Nil when it isn't open.

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

print(Anvil.title())
```

## Anvil.slots

Definition:
```luau
function Anvil.slots(): { Slot }?
```
Every slot shown, in the window's order (down each column, left to right). Nil when the window isn't open or the names can't be read.

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

for _, s in ipairs(Anvil.slots() or {}) do
	print(s.name, s.bars, s.enough_bars, s.available)
end
```

## Anvil.find

Definition:
```luau
function Anvil.find(items: Item | { Item }): Slot?
```
The first slot that makes any of `items`. Nil when none does or the window isn't open.

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

local s = Anvil.find("Iron platebody")
print(s and s.label)
```

## Anvil.can_smith

Definition:
```luau
function Anvil.can_smith(items: Item | { Item }): boolean
```
Whether the window offers one of `items` and both the level and the bars allow it.

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

print(Anvil.can_smith("Iron platebody"))
```

## Anvil.buttons

Definition:
```luau
function Anvil.buttons(): { Button }?
```
The quantity buttons shown, top to bottom. The selected one has its label in white. The X amount button only shows once an amount has been typed. Nil when the window isn't open.

The game sometimes hides 5, 10 and X when few bars are left: right after smithing a stack down to 2 iron bars only 1 and All showed, but reopening later with the same 2 bars showed all of them. What decides it isn't known.

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

for _, b in ipairs(Anvil.buttons() or {}) do
	print(b.label, b.selected)
end
```

## Anvil.quantity

Definition:
```luau
function Anvil.quantity(): string?
```
The label of the selected quantity button (`"1"`, `"All"`, `"14"`, ...). Nil when the window isn't open.

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

print(Anvil.quantity())
```

## Anvil.set_quantity

Definition:
```luau
export type Quantity = "All" | number

function Anvil.set_quantity(quantity: Quantity): boolean
```
Selects `quantity` and waits for it. A button already showing it is clicked, any other whole number goes through X and the "Enter amount" prompt. When neither the number's button nor X is shown, All is selected instead, since they have only been seen hidden when there were too few bars for them to make less than All. `true` when the wanted quantity (or All, then) ends up selected, also if it already was.

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

print(Anvil.set_quantity(14))
```

## Anvil.smith

Definition:
```luau
function Anvil.smith(items: Item | { Item }, quantity: Quantity?, key_probability: number?): boolean
```
Smiths the first of `items` the window offers, `quantity` times (`"All"` by default). Fails without input when the level or the bars don't allow it. When the item is the highlighted one, Space is pressed with the chance `key_probability` (nil or negative rolls a biometric around `Anvil.KEY_CHANCE`), otherwise the slot is clicked. `true` once the window has closed and the first item is in the inventory; the rest keep being made after it returns.

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

if Anvil.open() then
	print(Anvil.smith("Iron platebody"))
end
```

## Anvil.close_button

Definition:
```luau
function Anvil.close_button(): Widget?
```
The window's close button. Nil when it isn't open.

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

print(Anvil.close_button() ~= nil)
```

## Anvil.close

Definition:
```luau
function Anvil.close(): boolean
```
Closes the window with its close button, up to 3 tries, since Escape doesn't close it. See `Toplevel.close`. `true` when it's closed, also if it wasn't open.

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

print(Anvil.close())
```

## Anvil.nearest

Definition:
```luau
function Anvil.nearest(): Loc?
```
The closest object in the scene whose name has "anvil" in it and that offers "Smith". Nil when there's none.

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

local a = Anvil.nearest()
print(a and `{a.x}, {a.y}`)
```

## Anvil.hover

Definition:
```luau
function Anvil.hover(anvil: Loc?): boolean
```
Hovers `anvil`, or the nearest one. `false` when there's no anvil or it couldn't be hovered.

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

print(Anvil.hover())
```

## Anvil.open

Definition:
```luau
function Anvil.open(anvil: Loc?, walk: boolean?): (boolean, string?)
```
Opens the window: closes any other main screen interface with Escape, then uses "Smith" on `anvil` (the nearest by default), walking closer first unless `walk` is false, and waits for the window. `true` when it is open, also if it already was; otherwise `false` and why.

Example:
```luau
local Anvil = require("@lib/main/interfaces/mainscreen/anvil")

local ok, why = Anvil.open()
print(ok, why)
```
