# Main.Interfaces.Mainscreen.Gnomeglider

The gnome glider map: a map of the seven landing places, opened by the "Glider" option of any glider pilot (group 138, `gliders` in the cache). Each place is a model with its name beside it. The pilots are different NPCs by landing place and the NPC list gives them an empty name, so the option "Glider" is all that identifies one.

```luau
local Gnomeglider = require("@lib/main/interfaces/mainscreen/gnomeglider")
```

A destination has `name` and `area` (the model: where to hover and click). Quests gate the places; this module was only seen on an account with all of them done, so how a place you can't use looks is not known. The map also lists the place you are at; this module doesn't tell it apart.

## Constants

Definition:
```luau
Gnomeglider.GROUP = 138
Gnomeglider.LAST_COMPONENT = 40
Gnomeglider.CLOSE = 26
Gnomeglider.OPTION = "Glider"
Gnomeglider.OPEN_TIMEOUT_MS = 3000
Gnomeglider.HOVER_TIMEOUT_MS = 800
Gnomeglider.CONFIRM_TIMEOUT_MS = 4000
Gnomeglider.POLL_MS = 50
Gnomeglider.SETTLE_MS = 150
Gnomeglider.OPEN_SETTLE_MS = { 250, 500 }
Gnomeglider.PILOT_RANGE = 12
Gnomeglider.PILOT_ASK_LIMIT = 8
Gnomeglider.PILOT_HOVER_MS = 350
```
The interface piece numbers (how many components are searched for places, and the close button), the option that opens the map, and the waits: for `wait_open`, for a hover to show the menu, for the map to go after a click, between looks, for the menu to follow the mouse, and the pause `open` makes once the map shows. The last three are for finding the pilot: how far to look, how many NPCs to ask at most, and how long to wait after hovering one.

## Gnomeglider.Site

Definition:
```luau
export type Site = "Ta Quir Priw" | "Sindarpos" | "Lemanto Andra" | "Kar-Hewo" | "Gandius" | "Lemantolly Undri" | "Ookookolly Undri"
```
Every landing place, as the game names it. `Gnomeglider.Site` is a frozen table of them keyed without spaces or punctuation (`TaQuirPriw`, `Sindarpos`, `LemantoAndra`, `KarHewo`, `Gandius`, `LemantollyUndri`, `OokookollyUndri`), so a trip is `Gnomeglider.select(Gnomeglider.Site.KarHewo)` and a misspelled place is a type error.

## Gnomeglider.is_open

Definition:
```luau
function Gnomeglider.is_open(): boolean
```
Whether the map is open.

## Gnomeglider.wait_open

Definition:
```luau
function Gnomeglider.wait_open(timeout_ms: number?): boolean
```
Whether the map is open, polled for up to `timeout_ms` (3 seconds by default).

## Gnomeglider.destinations

Definition:
```luau
function Gnomeglider.destinations(): { Destination }?
```
The places on the map, top to bottom. The game keeps each name as its model's first menu option, which the widget exposes as `action`, so nothing is hovered. Nil when the map isn't open.

Example:
```luau
local Gnomeglider = require("@lib/main/interfaces/mainscreen/gnomeglider")

for _, d in ipairs(Gnomeglider.destinations() or {}) do
	print(d.name)
end
```

## Gnomeglider.names

Definition:
```luau
function Gnomeglider.names(): { string }?
```
The names of the places, top to bottom. Nil when the map isn't open.

## Gnomeglider.find

Definition:
```luau
function Gnomeglider.find(name: string): Destination?
```
The place called `name`, ignoring case. An exact name wins. Otherwise a name that contains the other counts, but only when exactly one place fits ("Undri" fits two, so it finds none).

## Gnomeglider.select

Definition:
```luau
function Gnomeglider.select(site: Site): boolean
```
Clicks the place's model, which sends the glider, and waits for the map to go. `site` is one of `Gnomeglider.Site`, so no free text is typed. The click only happens once the menu under the mouse offers the place that was asked for (the models overlap), so a wrong spot costs nothing. False when no place has that name, the menu didn't offer it, or the map stayed open. The flight is not waited for.

Example:
```luau
local Gnomeglider = require("@lib/main/interfaces/mainscreen/gnomeglider")

assert(Gnomeglider.open())
assert(Gnomeglider.select(Gnomeglider.Site.Sindarpos), "couldn't choose Sindarpos")
```

## Gnomeglider.close_button

Definition:
```luau
function Gnomeglider.close_button(): Widget?
```
The close button, nil when the map isn't open.

## Gnomeglider.close

Definition:
```luau
function Gnomeglider.close(key_probability: number?): boolean
```
Closes the map: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.

## Gnomeglider.find_pilot

Definition:
```luau
function Gnomeglider.find_pilot(near: Tile?, range: number?): Npc?
```
The NPC within `range` tiles (`PILOT_RANGE` by default) of `near` (you by default) that offers "Glider", found by asking: each one, nearest first, is hovered and its menu read. Nil when there is none.

## Gnomeglider.open

Definition:
```luau
function Gnomeglider.open(npc: Npc?, walk: boolean?): (boolean, string?)
```
Opens the map from the nearest pilot (or `npc`), walking closer first unless `walk` is false, and waits for it. True also when it was open already. When it didn't work, the second result says why.

Example:
```luau
local Gnomeglider = require("@lib/main/interfaces/mainscreen/gnomeglider")

local ok, why = Gnomeglider.open()
assert(ok, why)
print(table.concat(Gnomeglider.names() or {}, ", "))
```
