# Main.Interfaces.Mainscreen.Mushtree

The magic mushtree network on Fossil Island: the list of trees that opens when you "Use" a Magic Mushtree (group 608, `fossil_mushtrees` in the cache). Each tree is a panel reading `<col=8f8f8f>1.</col> House on the Hill`, numbered 1 to 4. A panel is chosen by clicking it (its menu option is "Continue") or by pressing its number key.

```luau
local Mushtree = require("@lib/main/interfaces/mainscreen/mushtree")
```

A destination has `number` (the number before the name, which is also its key), `name` and `panel` (the whole panel, where to click). The list also shows the tree you are standing at; this module doesn't tell it apart.

## Constants

Definition:
```luau
Mushtree.GROUP = 608
Mushtree.FRAME = 1
Mushtree.CLOSE_INDEX = 13
Mushtree.OBJECT = "Magic Mushtree"
Mushtree.OPTION = "Use"
Mushtree.CONTINUE = "Continue"
Mushtree.MAX_TREES = 4
Mushtree.KEY_CHANCE = 0.5
Mushtree.OPEN_TIMEOUT_MS = 3000
Mushtree.CONFIRM_TIMEOUT_MS = 4000
Mushtree.POLL_MS = 50
Mushtree.SETTLE_MS = { 250, 500 }
```
The interface piece numbers (the frame holds the title and the close button), the tree object and the option that opens the list, a panel's menu option, the highest tree number, the chance a biometric is rolled around for using a number key, and the waits: for `wait_open`, for the list to go after a choice, and between looks.

## Mushtree.is_open

Definition:
```luau
function Mushtree.is_open(): boolean
```
Whether the list is open.

## Mushtree.wait_open

Definition:
```luau
function Mushtree.wait_open(timeout_ms: number?): boolean
```
Waits for the list to open (`OPEN_TIMEOUT_MS` by default). False when it didn't.

## Mushtree.destinations

Definition:
```luau
function Mushtree.destinations(): { Destination }?
```
The trees in the list in order. Nil when the list isn't open.

Example:
```luau
local Mushtree = require("@lib/main/interfaces/mainscreen/mushtree")

for _, d in ipairs(Mushtree.destinations() or {}) do
	print(d.number, d.name)
end
```

## Mushtree.names

Definition:
```luau
function Mushtree.names(): { string }?
```
The names of the trees, in order.

## Mushtree.find

Definition:
```luau
function Mushtree.find(name: string): Destination?
```
The tree called `name`, ignoring case. An exact name wins. Otherwise a name that contains the other ("Hill" for "House on the Hill") counts, but only when exactly one tree fits. Nil when nothing fits.

## Mushtree.Tree

Definition:
```luau
export type Tree = "House on the Hill" | "Verdant Valley" | "Sticky Swamp" | "Mushroom Meadow"
```
Every tree of the network, as the list names it. `Mushtree.Tree` is a frozen table of them (`HouseOnTheHill`, `VerdantValley`, `StickySwamp`, `MushroomMeadow`), so a trip is `Mushtree.select(Mushtree.Tree.StickySwamp)` and a misspelled tree is a type error. Read from the open list on a live client.

## Mushtree.select

Definition:
```luau
function Mushtree.select(tree: Tree, key_probability: number?): string?
```
Chooses a tree by name. It presses the tree's number key with chance `key_probability` (nil or 0 is a biometric around `KEY_CHANCE`), else clicks its panel. A key that leaves the list open for `CONFIRM_TIMEOUT_MS` is followed by the click. Returns `"key"` or `"click"` for the way that worked, or nil when no tree has that name or nothing worked. The trip itself is not waited for.

Example:
```luau
local Mushtree = require("@lib/main/interfaces/mainscreen/mushtree")

assert(Mushtree.open(), "couldn't open the mushtree list")
print("chose by", Mushtree.select(Mushtree.Tree.VerdantValley))
```

## Mushtree.close_button

Definition:
```luau
function Mushtree.close_button(): Widget?
```
The close button, nil when the list isn't open.

## Mushtree.close

Definition:
```luau
function Mushtree.close(key_probability: number?): boolean
```
Closes the list and waits for it to go: Escape with chance `key_probability` (nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`. True when it's closed.

## Mushtree.nearest

Definition:
```luau
function Mushtree.nearest(): Loc?
```
The nearest "Magic Mushtree" among the objects loaded, by straight distance, with the plane you are on first. Nil when none is loaded.

## Mushtree.open

Definition:
```luau
function Mushtree.open(tree: Loc?, walk: boolean?): boolean
```
Opens the list: closes any other main screen interface with Escape, then uses the nearest magic mushtree (or `tree`), walking closer first unless `walk` is false, and waits for the list. True when it is open, also if it already was. If the click opened a menu on something else, the "Use" option is taken when what's hovered is a mushtree.

Example:
```luau
local Mushtree = require("@lib/main/interfaces/mainscreen/mushtree")

if Mushtree.open() then
	print(table.concat(Mushtree.names() or {}, ", "))
	Mushtree.close()
end
```

`SETTLE_MS` is the pause (minimum and maximum, in milliseconds) `open` makes after it finds the list open: the game ignores a key pressed in the first moments after the list appears.
