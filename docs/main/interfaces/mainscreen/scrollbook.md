# Main.Interfaces.Mainscreen.Scrollbook

The master scroll book: a grid of the teleport scrolls it can hold, opened by "Open" on the book in the inventory (group 597, `bookofscrolls` in the cache). Each cell has the scroll's name and how many are held.

```luau
local Scrollbook = require("@lib/main/interfaces/mainscreen/scrollbook")
```

A cell's first option, "Activate", teleports at once and spends a scroll. Its other options are "Set as default" and "Remove", which takes the scrolls out of the book; nothing here clicks those. The book item's own "Teleport" option isn't used, because what it does depends on the default scroll.

A scroll has `name`, `count` (how many are held) and `area` (the cell: where to hover and click). Scrolls can be real money, so `select` is the only function here that spends anything. The counts are also in the game's `bookofscrolls_*` varbits, which is how the transport data checks them without opening the book.

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
The interface piece numbers (how many components are searched for cells and the close button), the book, the inventory's container, the book's option that opens it, a cell's option that teleports, and the waits: for `wait_open`, for a hover to show the menu, for the book to go after a click, between looks, for the menu to follow the mouse, and the pause `open` makes once the book shows.

## Scrollbook.Name

Definition:
```luau
export type Name = "Nardah" | "Digsite" | "Feldip Hills" | "Lunar Isle" | "Mort'ton" | "Pest Control" | "Piscatoris" | "Tai Bwo Wannai" | "Iorwerth Camp" | "Mos Le' Harmless" | "Lumber-yard" | "Zul-andra" | "Key Master" | "Revenant caves" | "Watson" | "Guthixian Temple" | "Spider Cave" | "Colossal Wyrm" | "Chasm of Fire" | "Ardeaglais"
```
Every scroll, as the book names it. `Scrollbook.Name` is a frozen table of them keyed without spaces or punctuation (`TaiBwoWannai`, `Zulandra`, `MosLeHarmless`, `Lumberyard`, ...), so a trip is `Scrollbook.select(Scrollbook.Name.Watson)` and a misspelled scroll is a type error.

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
Whether the book is open, polled for up to `timeout_ms` (3 seconds by default).

## Scrollbook.scrolls

Definition:
```luau
function Scrollbook.scrolls(): { Scroll }?
```
The scrolls in the book in reading order, including those with none held. The components aren't in a regular order, so a cell's labels are the ones inside it, and nothing is hovered. Nil when the book isn't open.

Example:
```luau
local Scrollbook = require("@lib/main/interfaces/mainscreen/scrollbook")

for _, s in ipairs(Scrollbook.scrolls() or {}) do
	print(s.name, s.count)
end
```

## Scrollbook.find

Definition:
```luau
function Scrollbook.find(name: string): Scroll?
```
The scroll called `name`, ignoring case and punctuation, with or without "teleport" and "scroll" after it. An exact name wins. Otherwise a name that contains the other counts, but only when exactly one scroll fits. So the data's "Lumberyard teleport" and "Chasm teleport scroll" find "Lumber-yard" and "Chasm of Fire".

## Scrollbook.select

Definition:
```luau
function Scrollbook.select(name: Name): boolean
```
Activates the scroll, which teleports and spends one, and waits for the book to go. The click only happens once the menu under the mouse offers "Activate" on that very cell (by the entry's id, because some scrolls have no target text), so a wrong spot costs nothing. False when no scroll has that name, none is held, the menu didn't offer it, or the book stayed open. The teleport is not waited for.

Example:
```luau
local Scrollbook = require("@lib/main/interfaces/mainscreen/scrollbook")

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
Closes the book: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.

## Scrollbook.book_slot

Definition:
```luau
function Scrollbook.book_slot(): number?
```
The inventory slot of the book, nil when it isn't held.

## Scrollbook.open

Definition:
```luau
function Scrollbook.open(): (boolean, string?)
```
Opens the book from the inventory and waits for it. True also when it was open already. When it didn't work, the second result says why.

Example:
```luau
local Scrollbook = require("@lib/main/interfaces/mainscreen/scrollbook")

local ok, why = Scrollbook.open()
assert(ok, why)
print(#(Scrollbook.scrolls() or {}))
assert(Scrollbook.close())
```
