# Main.Interfaces.Mainscreen.Mushtree

The Fossil Island mushtree list (group 608) that opens on "Use" on a Magic Mushtree. Each panel reads `1. House on the Hill` (numbered 1 to 4) and is chosen by clicking it ("Continue") or pressing its number key. The list includes the tree you're at; this module doesn't distinguish it.

```luau
local Mushtree = require("@lib/main/interfaces/mainscreen/mushtree")
```

A `Destination` is `{ number: number, name: string, panel: Widget }`.

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
Component ids (the frame holds the title and close button), the object and its option, the panel option, the highest tree number, the base chance of choosing by key, and wait lengths. `SETTLE_MS` is the random pause `open` makes after the list appears, since the game ignores keys pressed right away.

## Mushtree.is_open

Definition:
```luau
function Mushtree.is_open(): boolean
```
Whether the list is open.

Example:
```luau
print(Mushtree.is_open())
```

## Mushtree.wait_open

Definition:
```luau
function Mushtree.wait_open(timeout_ms: number?): boolean
```
Polls `is_open` for up to `timeout_ms` (default `OPEN_TIMEOUT_MS`).

Example:
```luau
print(Mushtree.wait_open())
```

## Mushtree.destinations

Definition:
```luau
function Mushtree.destinations(): { Destination }?
```
The listed trees sorted by number. Nil when the list isn't open.

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
The listed tree names in number order. Nil when the list isn't open.

Example:
```luau
print(table.concat(Mushtree.names() or {}, ", "))
```

## Mushtree.find

Definition:
```luau
function Mushtree.find(name: string): Destination?
```
Case-insensitive: an exact name wins, else a unique substring match either way ("Hill"). Nil when none or several fit, or the list is closed.

Example:
```luau
local d = Mushtree.find("swamp")
print(d and d.number)
```

## Mushtree.Tree

Definition:
```luau
export type Tree = "House on the Hill" | "Verdant Valley" | "Sticky Swamp" | "Mushroom Meadow"
```
Every tree as the list names it. `Mushtree.Tree` is a frozen table of them (`HouseOnTheHill`, `VerdantValley`, `StickySwamp`, `MushroomMeadow`), so a misspelling is a type error.

Example:
```luau
Mushtree.select(Mushtree.Tree.StickySwamp)
```

## Mushtree.select

Definition:
```luau
function Mushtree.select(tree: Tree, key_probability: number?): string?
```
Presses the tree's number key with chance `key_probability` (nil or 0: a biometric value around `KEY_CHANCE`), else clicks its panel; a key that leaves the list open for `CONFIRM_TIMEOUT_MS` falls back to a click. Returns `"key"` or `"click"`, or nil when the tree isn't listed or nothing closed the list. Doesn't wait for the trip.

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

Example:
```luau
print(Mushtree.close_button() ~= nil)
```

## Mushtree.close

Definition:
```luau
function Mushtree.close(key_probability: number?): boolean
```
Closes the list by Escape (chance `key_probability`, nil or 0 uses the biometric default) or the close button; see [Toplevel.close](toplevel.md). True once closed.

Example:
```luau
Mushtree.close(0.5)
```

## Mushtree.nearest

Definition:
```luau
function Mushtree.nearest(): Loc?
```
The nearest loaded Magic Mushtree, preferring the player's plane. Nil when none is loaded.

Example:
```luau
local tree = Mushtree.nearest()
print(tree and tree.id)
```

## Mushtree.open

Definition:
```luau
function Mushtree.open(tree: Loc?, walk: boolean?): boolean
```
Clears other main screen interfaces with Escape, then "Use"s `tree` (default `nearest()`), walking closer unless `walk` is false. If the click missed but a mushtree is hovered, picks "Use" from the menu. Waits for the list plus `SETTLE_MS`. True when open, or already was.

Example:
```luau
local Mushtree = require("@lib/main/interfaces/mainscreen/mushtree")

if Mushtree.open() then
	print(table.concat(Mushtree.names() or {}, ", "))
	Mushtree.close()
end
```
