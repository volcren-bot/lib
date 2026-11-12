# Main.Interfaces.Mainscreen.Spirittree

The spirit tree travel list: group 187 (the generic `menu` list) titled "Spirit Tree Locations", opened with "Travel" on a spirit tree or "Tree" on a house Spiritual Fairy Tree. Each row reads `K: Name` and is chosen by click or by its key (1-9, then A, B, ...); keys depend on the list, so pick by name. Locked places are drawn grey but still clickable, so `available` comes from the colour. The list also shows your current place, which is not marked.

A `Destination` has `key`, `name`, `available` and `row` (the widget to click).

```luau
local Spirittree = require("@lib/main/interfaces/mainscreen/spirittree")
```

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
Spirittree.SPIRITUAL = "Spiritual Fairy Tree"
Spirittree.SPIRITUAL_OPTION = "Tree"
Spirittree.KEY_CHANCE = 0.5
Spirittree.OPEN_TIMEOUT_MS = 3000
Spirittree.CONFIRM_TIMEOUT_MS = 4000
Spirittree.POLL_MS = 50
Spirittree.SETTLE_MS = { 250, 500 }
```
- Widget children, and the title that tells this list from other users of the group.
- `LOCKED_COLOUR`: colour tag of a locked place.
- `OBJECT`/`OPTION`, `SPIRITUAL`/`SPIRITUAL_OPTION`: the trees and the options that open the list.
- `KEY_CHANCE`: mean of the biometric for choosing by key.
- Waits: open, list closing after a choice, poll, and the random pause after opening (the game ignores keys pressed right away).

## Spirittree.is_open

Definition:
```luau
function Spirittree.is_open(): boolean
```
Whether the list is open, checking the title since the group is shared.

Example:
```luau
print(Spirittree.is_open())
```

## Spirittree.wait_open

Definition:
```luau
function Spirittree.wait_open(timeout_ms: number?): boolean
```
Polls for the list up to `timeout_ms` (`OPEN_TIMEOUT_MS`).

Example:
```luau
Spirittree.wait_open()
```

## Spirittree.destinations

Definition:
```luau
function Spirittree.destinations(): { Destination }?
```
The places top to bottom, without Cancel. `nil` when closed.

Example:
```luau
for _, d in ipairs(Spirittree.destinations() or {}) do
	print(d.key, d.name, d.available)
end
```

## Spirittree.names

Definition:
```luau
function Spirittree.names(available_only: boolean?): { string }?
```
The place names; with `available_only`, only unlocked ones. `nil` when closed.

Example:
```luau
print(table.concat(Spirittree.names(true) or {}, ", "))
```

## Spirittree.find

Definition:
```luau
function Spirittree.find(name: string): Destination?
```
The place called `name`, ignoring case. An exact match wins; else a substring match either way, only if exactly one fits.

Example:
```luau
local d = Spirittree.find("grand")
```

## Spirittree.key_code

Definition:
```luau
function Spirittree.key_code(d: Destination): number?
```
The key code of `d.key` (digits and capital letters are their own codes), `nil` for anything else.

Example:
```luau
local d = Spirittree.find("Hosidius")
print(d and Spirittree.key_code(d))
```

## Spirittree.Place

Definition:
```luau
export type Place = "Tree Gnome Village" | "Gnome Stronghold" | "Battlefield of Khazard" | "Grand Exchange" | "Feldip Hills" | "Prifddinas" | "Port Sarim" | "Etceteria" | "Brimhaven" | "Hosidius" | "Farming Guild" | "Your house (Rimmington)" | "Poison Waste" | "Laguna Aurorae"
```
Every place as the list names it. `Spirittree.Place` is a frozen table of them keyed without spaces (`Spirittree.Place.GrandExchange`). `YourHouse` is "Your house (Rimmington)"; a house elsewhere is named differently and won't match.

Example:
```luau
Spirittree.select(Spirittree.Place.Hosidius)
```

## Spirittree.select

Definition:
```luau
function Spirittree.select(place: Place, key_probability: number?): string?
```
Presses the place's key with chance `key_probability` (`nil` or 0 rolls a biometric around `KEY_CHANCE`), else clicks its row; a key that leaves the list open for `CONFIRM_TIMEOUT_MS` is followed by a click. Returns `"key"` or `"click"`, or `nil` when the place is missing, locked (nothing pressed) or nothing worked. Does not wait for the trip.

Example:
```luau
assert(Spirittree.open())
print(Spirittree.select(Spirittree.Place.GnomeStronghold))
```

## Spirittree.close_button

Definition:
```luau
function Spirittree.close_button(): Widget?
```
The close button, `nil` when closed.

Example:
```luau
local button = Spirittree.close_button()
```

## Spirittree.close

Definition:
```luau
function Spirittree.close(key_probability: number?): boolean
```
Closes the list via `Toplevel.close` (`nil` or 0 uses the Escape biometric). `true` when closed or not open.

Example:
```luau
Spirittree.close()
```

## Spirittree.nearest

Definition:
```luau
function Spirittree.nearest(): Loc?
```
The nearest loaded "Spirit tree" or "Spiritual Fairy Tree" by straight distance, preferring your plane. `nil` when none. Farmed spirit trees share the name, so pass `tree` to `open` when one is near.

Example:
```luau
print(Spirittree.nearest())
```

## Spirittree.open

Definition:
```luau
function Spirittree.open(tree: Loc?, walk: boolean?): boolean
```
Clears other main screen interfaces with Escape, then uses the tree's option on `tree` or `nearest()`, walking closer unless `walk` is false, and waits for the list. If the click opened a menu instead, the option is picked when the hover text names a spirit tree. `true` when open, also if already open.

Example:
```luau
if Spirittree.open() then
	Spirittree.close()
end
```
