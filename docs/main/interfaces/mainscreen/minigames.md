# Main.Interfaces.Mainscreen.Minigames

The minigame teleport (20 minute cooldown, varp 888), started two ways: the "Minigame Teleport" spell's scrolling list (group 951, a cell's "Select" starts the cast), or the Grouping view of the side channels tab (group 76 inside 707: pick an activity in the dropdown, then "Teleport to" it). Rat Pits then asks which pit in a dialogue (Ardougne, Varrock, Keldagrim, Port Sarim). Starting the cast is free and a walk click cancels it; the cooldown only starts when it finishes.

The two lists differ (the dropdown has extra activities like God Wars) and spell some names differently ("Giants' Foundry"/"Giant's Foundry"), so names are compared by letters only, ignoring a trailing "Minigame Teleport". Locked teleports are untested.

A `Teleport` has `name`, `location` and `area`; an `Activity` has `name`, `index` and `area`.

```luau
local Minigames = require("@lib/main/interfaces/mainscreen/minigames")
local Grouping = Minigames.Grouping
```

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
- Widget children and options of both views.
- Waits: open, hover menu, pit dialogue, poll, hover settle, random pause after opening.
- Scrolling: pixels per wheel notch, most notches per scroll, most scrolls.

## Minigames.teleport

Definition:
```luau
function Minigames.teleport(name: string, pit: string?, via: ("list" | "grouping")?): (boolean, string?)
```
Starts the teleport via the spell list or Grouping view (a biometric coin flip unless `via` is given), then answers the Rat Pits dialogue with `pit`. Does not wait for the cast. On failure returns `false` and a reason, closing a list it left open.

Example:
```luau
local ok, why = Minigames.teleport("Rat Pits", "Varrock")
assert(ok, why)
```

## Minigames.choose_pit

Definition:
```luau
function Minigames.choose_pit(pit: string): boolean
```
Waits up to `DIALOGUE_TIMEOUT_MS` for an option containing `pit` (ignoring case) and picks it by key or click, falling back to a click. `false` if none came.

Example:
```luau
Minigames.choose_pit("Keldagrim")
```

## Minigames.is_open

Definition:
```luau
function Minigames.is_open(): boolean
```
Whether the spell list is open.

Example:
```luau
print(Minigames.is_open())
```

## Minigames.wait_open

Definition:
```luau
function Minigames.wait_open(timeout_ms: number?): boolean
```
Polls for the list up to `timeout_ms` (`OPEN_TIMEOUT_MS`).

Example:
```luau
Minigames.wait_open()
```

## Minigames.open

Definition:
```luau
function Minigames.open(): (boolean, string?)
```
Clears other interfaces with Escape, opens the spellbook, casts the spell and waits for the list. `true` if open or already open; otherwise `false` and a reason.

Example:
```luau
assert(Minigames.open())
```

## Minigames.teleports

Definition:
```luau
function Minigames.teleports(): { Teleport }?
```
Every teleport in the list top to bottom, including those scrolled out of view, read without hovering. `nil` when closed.

Example:
```luau
for _, t in ipairs(Minigames.teleports() or {}) do
	print(t.name, t.location)
end
```

## Minigames.find

Definition:
```luau
function Minigames.find(name: string): Teleport?
```
The teleport matching `name` by letters. `nil` when closed or absent.

Example:
```luau
local t = Minigames.find("Giant's Foundry")
```

## Minigames.select

Definition:
```luau
function Minigames.select(name: string): boolean
```
Scrolls to the teleport, hovers it and clicks once the menu offers its "Select", starting the cast (or the pit dialogue). `false` if absent or not offered.

Example:
```luau
Minigames.select("Pest Control")
```

## Minigames.close_button

Definition:
```luau
function Minigames.close_button(): Widget?
```
The list's close button, `nil` when closed.

Example:
```luau
local button = Minigames.close_button()
```

## Minigames.close

Definition:
```luau
function Minigames.close(key_probability: number?): boolean
```
Closes the list via `Toplevel.close` (`nil` or 0 uses the Escape biometric).

Example:
```luau
Minigames.close()
```

## Grouping.is_open

Definition:
```luau
function Grouping.is_open(): boolean
```
Whether the side channels tab shows the Grouping view.

Example:
```luau
print(Grouping.is_open())
```

## Grouping.open

Definition:
```luau
function Grouping.open(): boolean
```
Opens the side channels tab and, if needed, clicks its Grouping tab. `true` when showing.

Example:
```luau
Grouping.open()
```

## Grouping.selected

Definition:
```luau
function Grouping.selected(): string?
```
The chosen activity (kept by the game between uses), `nil` when none or the view isn't showing.

Example:
```luau
print(Grouping.selected())
```

## Grouping.list_open

Definition:
```luau
function Grouping.list_open(): boolean
```
Whether the dropdown list is showing.

Example:
```luau
print(Grouping.list_open())
```

## Grouping.activities

Definition:
```luau
function Grouping.activities(): { Activity }?
```
Every dropdown activity, including those scrolled out of view. Empty until the list has been shown once; `nil` when the view isn't showing.

Example:
```luau
print(#(Grouping.activities() or {}))
```

## Grouping.choose

Definition:
```luau
function Grouping.choose(name: string): boolean
```
Opens the view and dropdown, scrolls to the activity and clicks it once the menu offers it, then waits for it to be selected. `true` at once if already chosen; `false` if absent (the list is closed again) or the choice didn't take.

Example:
```luau
Grouping.choose("Nightmare Zone")
```

## Grouping.button

Definition:
```luau
function Grouping.button(): Widget?
```
The clickable part of the teleport button, `nil` when the view isn't showing.

Example:
```luau
local button = Grouping.button()
```

## Grouping.teleport

Definition:
```luau
function Grouping.teleport(name: string): boolean
```
`choose`s the activity, then clicks the button once the menu offers "Teleport to <activity>", starting the cast (or the pit dialogue).

Example:
```luau
Grouping.teleport("Soul Wars")
```
