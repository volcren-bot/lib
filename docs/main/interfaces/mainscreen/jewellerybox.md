# Main.Interfaces.Mainscreen.Jewellerybox

The jewellery box in a player's house: panels of teleports by the jewellery they copy, opened by "Teleport Menu" on the box (group 590, `poh_jewellery_box` in the cache). Trips are free.

```luau
local Jewellerybox = require("@lib/main/interfaces/mainscreen/jewellerybox")
```

Each destination is a line like `<col=ccccff>1:</col> Emir's Arena`, whose letter or digit is also its key. One the account can't use is struck through (`available` is false). Only the ornate box, with all six panels, has been seen; a smaller box should just show fewer panels.

The box's right-click menu also offers a destination directly (`Emir's Arena` here), which isn't used, and "Remove", which takes the box out of the house and which nothing here can click. Walking the chooser to a box isn't wired up: all house rows are left out of the transports.

A destination has `name`, `key`, `jewellery` (its panel's title), `available` and `area` (the line: where to hover and click).

## Constants

Definition:
```luau
Jewellerybox.GROUP = 590
Jewellerybox.FRAME = 1
Jewellerybox.CLOSE_INDEX = 11
Jewellerybox.FIRST_PANEL = 2
Jewellerybox.LAST_PANEL = 7
Jewellerybox.OBJECT = "jewellery box"
Jewellerybox.OPTION = "Teleport Menu"
Jewellerybox.KEY_CHANCE = 0.5
Jewellerybox.OPEN_TIMEOUT_MS = 3000
Jewellerybox.HOVER_TIMEOUT_MS = 800
Jewellerybox.CONFIRM_TIMEOUT_MS = 4000
Jewellerybox.POLL_MS = 50
Jewellerybox.HOVER_SETTLE_MS = 150
Jewellerybox.SETTLE_MS = { 250, 500 }
```
The interface piece numbers, what box objects are called (any size), the option that opens the menu, the chance a biometric is rolled around for using a key rather than a click, and the waits: for `wait_open`, for a hover to show the menu, for the menu to go after a pick, between looks, for the menu to follow the mouse, and the pause `open` makes once the menu shows.

## Jewellerybox.Place

Definition:
```luau
export type Place = "Emir's Arena" | "Castle Wars" | "Ferox Enclave" | "Fortis Colosseum" | "Burthorpe" | "Barbarian Outpost" | "Corporeal Beast" | "Tears of Guthix" | "Wintertodt Camp" | "Warriors' Guild" | "Champions' Guild" | "Monastery" | "Ranging Guild" | "Fishing Guild" | "Mining Guild" | "Crafting Guild" | "Cooking Guild" | "Woodcutting Guild" | "Farming Guild" | "Miscellania" | "Grand Exchange" | "Falador Park" | "Dondakan's Rock" | "Edgeville" | "Karamja" | "Draynor Village" | "Al Kharid"
```
Every destination of the biggest box, as the game names them. `Jewellerybox.Place` is a frozen table of them keyed without spaces or punctuation (`EmirsArena`, `GrandExchange`, `AlKharid`, ...), so a trip is `Jewellerybox.select(Jewellerybox.Place.GrandExchange)` and a misspelled place is a type error.

## Jewellerybox.is_open

Definition:
```luau
function Jewellerybox.is_open(): boolean
```
Whether the menu is open.

## Jewellerybox.wait_open

Definition:
```luau
function Jewellerybox.wait_open(timeout_ms: number?): boolean
```
Whether the menu is open, polled for up to `timeout_ms` (3 seconds by default).

## Jewellerybox.destinations

Definition:
```luau
function Jewellerybox.destinations(): { Destination }?
```
The destinations in the menu's order, read from the widgets without hovering. Nil when the menu isn't open.

Example:
```luau
local Jewellerybox = require("@lib/main/interfaces/mainscreen/jewellerybox")

for _, d in ipairs(Jewellerybox.destinations() or {}) do
	print(d.key, d.name, d.jewellery, d.available)
end
```

## Jewellerybox.names

Definition:
```luau
function Jewellerybox.names(): { string }?
```
The names of the destinations in the menu's order. Nil when the menu isn't open.

## Jewellerybox.find

Definition:
```luau
function Jewellerybox.find(name: string): Destination?
```
The destination called `name`, ignoring case. An exact name wins. Otherwise a name that contains the other counts, but only when exactly one destination fits ("Exchange" finds the Grand Exchange, "Guild" finds nothing).

## Jewellerybox.select

Definition:
```luau
function Jewellerybox.select(place: Place, key_probability: number?): string?
```
Chooses a destination and returns how it was done: "key" (its key; chance `key_probability`, nil or 0 is a biometric around `KEY_CHANCE`) or "click" on its line. A key that leaves the menu open for `CONFIRM_TIMEOUT_MS` is followed by the click, which only happens once the menu under the mouse offers that destination, so a wrong spot costs nothing. Nil when no destination has that name, it is struck through, or nothing worked. The trip itself is not waited for.

Example:
```luau
local Jewellerybox = require("@lib/main/interfaces/mainscreen/jewellerybox")

assert(Jewellerybox.open())
assert(Jewellerybox.select(Jewellerybox.Place.GrandExchange), "couldn't choose the Grand Exchange")
```

## Jewellerybox.close_button

Definition:
```luau
function Jewellerybox.close_button(): Widget?
```
The close button, nil when the menu isn't open.

## Jewellerybox.close

Definition:
```luau
function Jewellerybox.close(key_probability: number?): boolean
```
Closes the menu: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.

## Jewellerybox.nearest

Definition:
```luau
function Jewellerybox.nearest(): Loc?
```
The nearest jewellery box of any size, nil when there is none.

## Jewellerybox.open

Definition:
```luau
function Jewellerybox.open(box: Loc?, walk: boolean?): (boolean, string?)
```
Opens the menu from the nearest box (or `box`), walking closer first unless `walk` is false, and waits for it. True also when it was open already. When it didn't work, the second result says why.

Example:
```luau
local Jewellerybox = require("@lib/main/interfaces/mainscreen/jewellerybox")

local ok, why = Jewellerybox.open()
assert(ok, why)
print(table.concat(Jewellerybox.names() or {}, ", "))
assert(Jewellerybox.close())
```
