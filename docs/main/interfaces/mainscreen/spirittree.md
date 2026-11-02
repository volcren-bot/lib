# Main.Interfaces.Mainscreen.Spirittree

The spirit tree network: the list of places that opens when you "Travel" with a spirit tree. It is group 187, the game's generic `menu` list, titled "Spirit Tree Locations". Each place is a row reading `<col=735a28>K</col>: Name`, followed by a "Cancel" row. A row is chosen by clicking it (its menu option is "Continue") or by pressing its key (1 to 9, then A, B, ...).

```luau
local Spirittree = require("@lib/main/interfaces/mainscreen/spirittree")
```

Places you haven't unlocked are drawn grey, but their rows still offer "Continue", so the colour is the only way to tell: a destination's `available` is false for them, and `select` refuses them. The list also shows the place you are standing at; this module doesn't tell it apart.

A destination has `key` (the key before the name), `name`, `available` and `row` (where to click). The keys are never a safe way to pick a place by hand: they depend on the list.

## Constants

Definition:
```luau
Spirittree.GROUP = 187
Spirittree.TITLE = 0
Spirittree.TITLE_INDEX = 1
Spirittree.TITLE_TEXT = "Spirit Tree Locations"
Spirittree.LIST = 3
Spirittree.CLOSE = 4
Spirittree.LOCKED_COLOUR = "5f5f5f"
Spirittree.CANCEL = "Cancel"
Spirittree.OBJECT = "Spirit tree"
Spirittree.OPTION = "Travel"
Spirittree.KEY_CHANCE = 0.5
Spirittree.OPEN_TIMEOUT_MS = 3000
Spirittree.CONFIRM_TIMEOUT_MS = 4000
Spirittree.POLL_MS = 50
Spirittree.SETTLE_MS = { 250, 500 }
```
The interface piece numbers and the title that tells this list from the other lists of the group, the colour tag of a place not unlocked, the tree object and the option that opens the list, the chance a biometric is rolled around for using a key rather than a click, and the waits: for `wait_open`, for the list to go after a choice, between looks, and the pause `open` makes once the list shows (the game ignores a key pressed in the first moments after it appears).

## Spirittree.is_open

Definition:
```luau
function Spirittree.is_open(): boolean
```
Whether the spirit tree list is open (the group is shared, so the title is checked too).

## Spirittree.wait_open

Definition:
```luau
function Spirittree.wait_open(timeout_ms: number?): boolean
```
Waits for the list to open (`OPEN_TIMEOUT_MS` by default). False when it didn't.

## Spirittree.destinations

Definition:
```luau
function Spirittree.destinations(): { Destination }?
```
The places in the list, top to bottom, without the Cancel row. Nil when the list isn't open.

Example:
```luau
local Spirittree = require("@lib/main/interfaces/mainscreen/spirittree")

for _, d in ipairs(Spirittree.destinations() or {}) do
	print(d.key, d.name, d.available)
end
```

## Spirittree.names

Definition:
```luau
function Spirittree.names(available_only: boolean?): { string }?
```
The names of the places; with `available_only`, only those you have unlocked.

## Spirittree.find

Definition:
```luau
function Spirittree.find(name: string): Destination?
```
The place called `name`, ignoring case. An exact name wins. Otherwise a name that contains the other ("Grand" for "Grand Exchange") counts, but only when exactly one place fits. Nil when nothing fits.

## Spirittree.key_code

Definition:
```luau
function Spirittree.key_code(d: Destination): number?
```
The key code of a destination's key (digits and capital letters are their own codes).

## Spirittree.Place

Definition:
```luau
export type Place = "Tree Gnome Village" | "Gnome Stronghold" | "Battlefield of Khazard" | "Grand Exchange" | "Feldip Hills" | "Prifddinas" | "Port Sarim" | "Etceteria" | "Brimhaven" | "Hosidius" | "Farming Guild" | "Your house (Rimmington)" | "Poison Waste" | "Laguna Aurorae"
```
Every place of the network, as the list names it. `Spirittree.Place` is a frozen table of them keyed without spaces (`Spirittree.Place.GnomeStronghold`, `Spirittree.Place.GrandExchange`), so a trip is `Spirittree.select(Spirittree.Place.Hosidius)` and a misspelled place is a type error. `YourHouse` is "Your house (Rimmington)", read from a live list; the list names the house by where it is, so another house location would not match this value exactly.

## Spirittree.select

Definition:
```luau
function Spirittree.select(place: Place, key_probability: number?): string?
```
Chooses a place by name. It presses the place's key with chance `key_probability` (nil or 0 is a biometric around `KEY_CHANCE`), else clicks its row. A key that leaves the list open for `CONFIRM_TIMEOUT_MS` is followed by the click. Returns `"key"` or `"click"` for the way that worked. Returns nil, without doing anything, when no place has that name or it isn't unlocked; nil also when nothing worked. The trip itself is not waited for.

Example:
```luau
local Spirittree = require("@lib/main/interfaces/mainscreen/spirittree")

assert(Spirittree.open(), "couldn't open the spirit tree list")
print("chose by", Spirittree.select(Spirittree.Place.GnomeStronghold))
```

## Spirittree.close_button

Definition:
```luau
function Spirittree.close_button(): Widget?
```
The close button, nil when the list isn't open.

## Spirittree.close

Definition:
```luau
function Spirittree.close(key_probability: number?): boolean
```
Closes the list and waits for it to go: Escape with chance `key_probability` (nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`. True when it's closed (also if it was not open).

## Spirittree.nearest

Definition:
```luau
function Spirittree.nearest(): Loc?
```
The nearest "Spirit tree" among the objects loaded, by straight distance, with the plane you are on first. Nil when none is loaded. Spirit trees you grew on a farming patch have the same name, so use the `tree` argument of `open` when one stands near.

## Spirittree.open

Definition:
```luau
function Spirittree.open(tree: Loc?, walk: boolean?): boolean
```
Opens the list: closes any other main screen interface with Escape, then uses "Travel" on the nearest spirit tree (or `tree`), walking closer first unless `walk` is false, and waits for the list. True when it is open, also if it already was. If the click opened a menu on something else, "Travel" is taken when what's hovered is a spirit tree.

Example:
```luau
local Spirittree = require("@lib/main/interfaces/mainscreen/spirittree")

if Spirittree.open() then
	print(table.concat(Spirittree.names(true) or {}, ", "))
	Spirittree.close()
end
```
