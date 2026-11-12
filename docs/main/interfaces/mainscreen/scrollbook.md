# Main.Interfaces.Mainscreen.Scrollbook

The master scroll book (group 597): a grid of teleport scrolls with their held counts, opened by "Open" on the book in the inventory. A cell's "Activate" teleports and spends a scroll; `select` is the only function here that spends anything. The book's own "Teleport", "Set as default" and "Remove" are never used. Counts are also in the `bookofscrolls_*` varbits, which the transport data reads without opening the book.

```luau
local Scrollbook = require("@lib/main/interfaces/mainscreen/scrollbook")
```

A `Scroll` has `name`, `count` (held) and `area` (the cell widget).

## Constants

Definition:
```luau
Scrollbook.GROUP = 597
Scrollbook.LAST_COMPONENT = 100
Scrollbook.CLOSE = 3
Scrollbook.BOOK = 21389
Scrollbook.INVENTORY = 93
Scrollbook.OPTION = "Open"
Scrollbook.ACTIVATE = "Activate"
Scrollbook.OPEN_TIMEOUT_MS = 3000
Scrollbook.HOVER_TIMEOUT_MS = 800
Scrollbook.CONFIRM_TIMEOUT_MS = 4000
Scrollbook.POLL_MS = 50
Scrollbook.SETTLE_MS = 150
Scrollbook.OPEN_SETTLE_MS = { 250, 500 }
```
Widget ids (`LAST_COMPONENT` bounds the cell search), the book item, inventory container, options, and timings.

## Scrollbook.Name

Definition:
```luau
export type Name = "Nardah" | "Digsite" | "Feldip Hills" | "Lunar Isle" | "Mort'ton" | "Pest Control" | "Piscatoris" | "Tai Bwo Wannai" | "Iorwerth Camp" | "Mos Le' Harmless" | "Lumber-yard" | "Zul-andra" | "Key Master" | "Revenant caves" | "Watson" | "Guthixian Temple" | "Spider Cave" | "Colossal Wyrm" | "Chasm of Fire" | "Ardeaglais"
```
Every scroll as the book names it. `Scrollbook.Name` is a frozen table keyed without spaces or punctuation (`TaiBwoWannai`, `Zulandra`, `MosLeHarmless`, `Lumberyard`, `ChasmOfFire`).

## Scrollbook.is_open

Definition:
```luau
function Scrollbook.is_open(): boolean
```
Whether the book is open.

## Scrollbook.wait_open

Definition:
```luau
function Scrollbook.wait_open(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (default `OPEN_TIMEOUT_MS`) for the book. False on timeout.

## Scrollbook.scrolls

Definition:
```luau
function Scrollbook.scrolls(): { Scroll }?
```
Every scroll in reading order, including those with a count of 0, read from memory without hovering. Nil when the book isn't open.

Example:
```luau
for _, s in ipairs(Scrollbook.scrolls() or {}) do
	print(s.name, s.count)
end
```

## Scrollbook.find

Definition:
```luau
function Scrollbook.find(name: string): Scroll?
```
The scroll called `name`, ignoring case, spaces, punctuation and a trailing "teleport"/"scroll". An exact match wins; otherwise a substring match either way counts only if exactly one scroll fits ("Lumberyard teleport" finds "Lumber-yard"). Nil when the book isn't open.

## Scrollbook.select

Definition:
```luau
function Scrollbook.select(name: Name): boolean
```
Hovers the cell, clicks only when the menu's first entry is "Activate" on that cell's id, and waits for the book to close. False when the scroll isn't found, none is held, the menu disagrees, or the book stays open. Doesn't wait for the teleport.

Example:
```luau
assert(Scrollbook.open())
assert(Scrollbook.select(Scrollbook.Name.Watson), "couldn't use a Watson scroll")
```

## Scrollbook.close_button

Definition:
```luau
function Scrollbook.close_button(): Widget?
```
The close button, nil when the book isn't open.

## Scrollbook.close

Definition:
```luau
function Scrollbook.close(key_probability: number?): boolean
```
Closes the book via `Toplevel.close`: Escape with chance `key_probability` (nil or 0 uses the biometric), else the close button. True when closed, also if it wasn't open.

## Scrollbook.book_slot

Definition:
```luau
function Scrollbook.book_slot(): number?
```
The inventory slot of the book, nil when not held.

## Scrollbook.open

Definition:
```luau
function Scrollbook.open(): (boolean, string?)
```
Clears other interfaces with Escape, uses "Open" on the book and waits for it. True when open, also if it already was; otherwise false and the reason.

Example:
```luau
local ok, why = Scrollbook.open()
assert(ok, why)
```
