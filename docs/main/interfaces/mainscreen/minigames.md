# Main.Interfaces.Mainscreen.Minigames

The minigame teleports, a spell on a 20 minute cooldown (varp 888), in its two ways. This file holds both.

```luau
local Minigames = require("@lib/main/interfaces/mainscreen/minigames")
local Grouping = Minigames.Grouping
```

- **The spell's list:** the "Minigame Teleport" spell opens a scrolling list (group 951, `minigames` in the cache). A cell's "Select" starts the cast.
- **The Grouping view:** the Grouping view of the side channels tab (group 76, `grouping`, inside group 707) picks an activity from a dropdown. Its button then reads "Teleport to" that activity.

Either way, Rat Pits first asks which pit in a dialogue: `Ardougne (kittens)`, `Varrock (grown cats)`, `Keldagrim (overgrown cats)`, `Port Sarim (wily cats)` or `Cancel`.

Starting a cast costs nothing. The animation is 4847, as for a home teleport, and a walk click stops it. The cooldown only starts when it finishes, so every path can be tested free.

The two lists differ: the dropdown has activities with no entry in the spell's list, like God Wars, and they name some differently from the transport data ("Giants' Foundry" and "Giant's Foundry", "Sorceress's Garden" and "Sorceress Garden"). So names are compared by their letters, with or without "Minigame Teleport" after them. Only an account with everything unlocked has been seen, so how a locked teleport looks isn't known.

A teleport has `name`, `location` and `area` (the cell). An activity has `name`, `index` (its place in the list) and `area` (the row).

## Constants

Definition:
```luau
Minigames.GROUP = 951
Minigames.VIEW = 4
Minigames.FRAME = 2
Minigames.CLOSE_INDEX = 11
Minigames.LAST_COMPONENT = 40
Minigames.LABEL_INDEX = 4
Minigames.SPELL = "Minigame Teleport"
Minigames.SELECT = "Select"
Minigames.RAT_PITS = "Rat Pits"
Minigames.OPEN_TIMEOUT_MS = 3000
Minigames.HOVER_TIMEOUT_MS = 800
Minigames.DIALOGUE_TIMEOUT_MS = 3000
Minigames.POLL_MS = 50
Minigames.SETTLE_MS = 150
Minigames.OPEN_SETTLE_MS = { 250, 500 }
Minigames.NOTCH_PIXELS = 79
Minigames.MAX_NOTCHES = 3
Minigames.MAX_SCROLLS = 40
Grouping.GROUP = 76
Grouping.PANEL = 707
Grouping.TAB = 5
Grouping.DROPDOWN = 6
Grouping.SELECTED = 11
Grouping.LIST = 18
Grouping.ROWS = 22
Grouping.BUTTON = 32
Grouping.NO_ACTIVITY = "Select an activity..."
Grouping.TELEPORT = "Teleport to"
```
The interface piece numbers and options, the waits, and how far a notch of the wheel scrolls, the most notches at a time and how many scrolls to try.

## Minigames.teleport

Definition:
```luau
function Minigames.teleport(name: string, pit: string?, via: ("list" | "grouping")?): (boolean, string?)
```
Starts the teleport by the spell's list or the Grouping view, as the account's biometrics favour unless `via` says which. `pit` answers Rat Pits ("Ardougne", "Varrock", "Keldagrim" or "Port Sarim"). The cast itself is not waited for. When it didn't work the second result says why, and a list left open is closed.

Example:
```luau
local Minigames = require("@lib/main/interfaces/mainscreen/minigames")

local ok, why = Minigames.teleport("Rat Pits", "Varrock")
assert(ok, why)
```

## Minigames.choose_pit

Definition:
```luau
function Minigames.choose_pit(pit: string): boolean
```
Answers the dialogue that asks which rat pit, by key or click, by click if the key doesn't take. False when it doesn't come or doesn't offer it.

## Minigames.is_open

Definition:
```luau
function Minigames.is_open(): boolean
```
Whether the spell's list is open.

## Minigames.wait_open

Definition:
```luau
function Minigames.wait_open(timeout_ms: number?): boolean
```
Whether the list is open, polled for up to `timeout_ms` (`OPEN_TIMEOUT_MS` by default).

## Minigames.open

Definition:
```luau
function Minigames.open(): (boolean, string?)
```
Casts the spell, which opens the list, and waits for it. True when it is open, also if it already was. When it didn't work the second result says why.

## Minigames.teleports

Definition:
```luau
function Minigames.teleports(): { Teleport }?
```
Every teleport in the list, top to bottom, read without hovering, including those scrolled out of view. Nil when the list isn't open.

Example:
```luau
local Minigames = require("@lib/main/interfaces/mainscreen/minigames")

assert(Minigames.open())
for _, t in ipairs(Minigames.teleports() or {}) do
	print(t.name, t.location)
end
assert(Minigames.close())
```

## Minigames.find

Definition:
```luau
function Minigames.find(name: string): Teleport?
```
The teleport called `name`, by its letters. Nil when the list isn't open or has none.

## Minigames.select

Definition:
```luau
function Minigames.select(name: string): boolean
```
Clicks a teleport in the list, scrolling to it first, which starts the cast (or for Rat Pits asks which pit). The click only happens once the menu under the mouse offers that cell. False when it isn't in the list or the click didn't happen.

## Minigames.close_button

Definition:
```luau
function Minigames.close_button(): Widget?
```
The list's close button, nil when it isn't open.

## Minigames.close

Definition:
```luau
function Minigames.close(key_probability: number?): boolean
```
Closes the list: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.

## Grouping.is_open

Definition:
```luau
function Grouping.is_open(): boolean
```
Whether the Grouping view is showing.

## Grouping.open

Definition:
```luau
function Grouping.open(): boolean
```
Opens the side channels tab and its Grouping view. True when it is showing, also if it already was.

## Grouping.selected

Definition:
```luau
function Grouping.selected(): string?
```
The activity chosen now, nil when none is or the view isn't showing. The game keeps the choice after it has been made.

## Grouping.list_open

Definition:
```luau
function Grouping.list_open(): boolean
```
Whether the dropdown's list is showing.

## Grouping.activities

Definition:
```luau
function Grouping.activities(): { Activity }?
```
Every activity of the dropdown, top to bottom, including those scrolled out of view. Empty until its list has been shown once. Nil when the view isn't showing.

## Grouping.choose

Definition:
```luau
function Grouping.choose(name: string): boolean
```
Chooses an activity in the dropdown, opening its list and scrolling to it. True at once when it is chosen already. False when it isn't in the list, which also closes the list, or the choice didn't take.

## Grouping.button

Definition:
```luau
function Grouping.button(): Widget?
```
The clickable part of the button, nil when the view isn't showing.

## Grouping.teleport

Definition:
```luau
function Grouping.teleport(name: string): boolean
```
Chooses the activity and clicks the button, which starts the cast (or for Rat Pits asks which pit). The click only happens once the menu under the mouse offers that activity's teleport.
