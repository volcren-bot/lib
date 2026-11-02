# Main.Interfaces.Mainscreen.Minecart

The Lovakengj minecart network on Zeah: the list of stops that opens when you "Travel" with a minecart. It is group 187, the game's generic `menu` list, titled "Minecart rides: Free" (the part after the colon is the fare, so only the start of the title is checked, `TITLE_PREFIX`). Each place is a row reading `<col=735a28>K</col>: Name`, followed by a "Cancel" row. A row is chosen by clicking it (its menu option is "Continue") or by pressing its key (1 to 9, then A, B, ...).

```luau
local Minecart = require("@lib/main/interfaces/mainscreen/minecart")
```

No stop has been seen drawn as locked, but the colour tag the other lists of this group use is still checked: a destination's `available` is false for a stop drawn that way, and `select` refuses it. The list also shows the place you are standing at; this module doesn't tell it apart.

A destination has `key` (the key before the name), `name`, `available` and `row` (where to click). The keys are never a safe way to pick a stop by hand: they depend on the list.

## Constants

Definition:
```luau
Minecart.GROUP = 187
Minecart.TITLE = 0
Minecart.TITLE_INDEX = 1
Minecart.TITLE_PREFIX = "Minecart rides"
Minecart.LIST = 3
Minecart.CLOSE = 4
Minecart.LOCKED_COLOUR = "5f5f5f"
Minecart.CANCEL = "(Cancel)"
Minecart.OBJECT = "Minecart"
Minecart.OPTION = "Travel"
Minecart.KEY_CHANCE = 0.5
Minecart.OPEN_TIMEOUT_MS = 3000
Minecart.CONFIRM_TIMEOUT_MS = 4000
Minecart.POLL_MS = 50
Minecart.SETTLE_MS = { 250, 500 }
```
The interface piece numbers and the title that tells this list from the other lists of the group, the colour tag of a locked stop, the cart object and the option that opens the list, the chance a biometric is rolled around for using a key rather than a click, and the waits: for `wait_open`, for the list to go after a choice, between looks, and the pause `open` makes once the list shows (the game ignores a key pressed in the first moments after it appears).

## Minecart.is_open

Definition:
```luau
function Minecart.is_open(): boolean
```
Whether the minecart list is open (the group is shared, so the title is checked too).

## Minecart.wait_open

Definition:
```luau
function Minecart.wait_open(timeout_ms: number?): boolean
```
Waits for the list to open (`OPEN_TIMEOUT_MS` by default). False when it didn't.

## Minecart.destinations

Definition:
```luau
function Minecart.destinations(): { Destination }?
```
The stops in the list, top to bottom, without the Cancel row. Nil when the list isn't open.

Example:
```luau
local Minecart = require("@lib/main/interfaces/mainscreen/minecart")

for _, d in ipairs(Minecart.destinations() or {}) do
	print(d.key, d.name, d.available)
end
```

## Minecart.names

Definition:
```luau
function Minecart.names(available_only: boolean?): { string }?
```
The names of the stops; with `available_only`, only those not drawn as locked.

## Minecart.find

Definition:
```luau
function Minecart.find(name: string): Destination?
```
The stop called `name`, ignoring case. An exact name wins. Otherwise a name that contains the other ("Hosidius" fits two, so it finds none; "Shayzien East" is exact) counts, but only when exactly one stop fits. Nil when nothing fits.

## Minecart.key_code

Definition:
```luau
function Minecart.key_code(d: Destination): number?
```
The key code of a destination's key (digits and capital letters are their own codes).

## Minecart.Stop

Definition:
```luau
export type Stop = "Arceuus" | "Farming Guild" | "Hosidius South" | "Hosidius West" | "Kingstown" | "Kourend Woodland" | "Lovakengj" | "Mount Quidamortem" | "Northern Tundras" | "Port Piscarilius" | "Shayzien East" | "Shayzien West"
```
Every stop of the network, as the list names it. `Minecart.Stop` is a frozen table of them keyed without spaces (`Minecart.Stop.Lovakengj`, `Minecart.Stop.PortPiscarilius`), so a trip is `Minecart.select(Minecart.Stop.Lovakengj)` and a misspelled stop is a type error. Read from the open list on a live client.

## Minecart.select

Definition:
```luau
function Minecart.select(stop: Stop, key_probability: number?): string?
```
Chooses a stop by name. It presses the stop's key with chance `key_probability` (nil or 0 is a biometric around `KEY_CHANCE`), else clicks its row. A key that leaves the list open for `CONFIRM_TIMEOUT_MS` is followed by the click. Returns `"key"` or `"click"` for the way that worked. Returns nil, without doing anything, when no place has that name or it isn't unlocked; nil also when nothing worked. The trip itself is not waited for.

Example:
```luau
local Minecart = require("@lib/main/interfaces/mainscreen/minecart")

assert(Minecart.open(), "couldn't open the minecart list")
print("chose by", Minecart.select(Minecart.Stop.Lovakengj))
```

## Minecart.close_button

Definition:
```luau
function Minecart.close_button(): Widget?
```
The close button, nil when the list isn't open.

## Minecart.close

Definition:
```luau
function Minecart.close(key_probability: number?): boolean
```
Closes the list and waits for it to go: Escape with chance `key_probability` (nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`. True when it's closed (also if it was not open).

## Minecart.nearest

Definition:
```luau
function Minecart.nearest(): Loc?
```
The nearest "Minecart" among the objects loaded, by straight distance, with the plane you are on first. Nil when none is loaded.

## Minecart.open

Definition:
```luau
function Minecart.open(cart: Loc?, walk: boolean?): boolean
```
Opens the list: closes any other main screen interface with Escape, then uses "Travel" on the nearest minecart (or `cart`), walking closer first unless `walk` is false, and waits for the list. True when it is open, also if it already was. If the click opened a menu on something else, "Travel" is taken when what's hovered is a minecart.

Example:
```luau
local Minecart = require("@lib/main/interfaces/mainscreen/minecart")

if Minecart.open() then
	print(table.concat(Minecart.names(true) or {}, ", "))
	Minecart.close()
end
```
