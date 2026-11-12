# Main.Interfaces.Mainscreen.Gnomeglider

The gnome glider map (group 138) of seven landing places, opened by "Glider" on any glider pilot. Pilots differ by place and have empty names in the NPC list, so the "Glider" option is what identifies one. Place names come from each model's `action` in memory, so nothing is hovered to read them. The current place is listed too and isn't told apart; quest-locked places were never observed.

```luau
local Gnomeglider = require("@lib/main/interfaces/mainscreen/gnomeglider")
```

A `Destination` has `name` and `area` (the model widget to click).

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
Widget ids (`LAST_COMPONENT` bounds the search), the pilot option, and timings. `PILOT_*` bound the pilot search: tile range, NPCs hovered at most, and the wait after each hover.

## Gnomeglider.Site

Definition:
```luau
export type Site = "Ta Quir Priw" | "Sindarpos" | "Lemanto Andra" | "Kar-Hewo" | "Gandius" | "Lemantolly Undri" | "Ookookolly Undri"
```
Every landing place. `Gnomeglider.Site` is a frozen table keyed without spaces or punctuation (`TaQuirPriw`, `KarHewo`, `OokookollyUndri`).

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
Waits up to `timeout_ms` (default `OPEN_TIMEOUT_MS`) for the map. False on timeout.

## Gnomeglider.destinations

Definition:
```luau
function Gnomeglider.destinations(): { Destination }?
```
The places on the map, top to bottom. Nil when the map isn't open.

Example:
```luau
for _, d in ipairs(Gnomeglider.destinations() or {}) do
	print(d.name)
end
```

## Gnomeglider.names

Definition:
```luau
function Gnomeglider.names(): { string }?
```
The place names, top to bottom. Nil when the map isn't open.

## Gnomeglider.find

Definition:
```luau
function Gnomeglider.find(name: string): Destination?
```
The place called `name`, case-insensitive. An exact match wins; otherwise a substring match either way counts only if exactly one place fits ("Undri" fits two, so nil).

## Gnomeglider.select

Definition:
```luau
function Gnomeglider.select(site: Site): boolean
```
Hovers the place's model, clicks only if the menu offers that place (the models overlap), and waits for the map to close. False when the place isn't found, the menu disagrees, or the map stays open. Doesn't wait for the flight.

Example:
```luau
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
Closes the map via `Toplevel.close`: Escape with chance `key_probability` (nil or 0 uses the biometric), else the close button. True when closed, also if it wasn't open.

## Gnomeglider.find_pilot

Definition:
```luau
function Gnomeglider.find_pilot(near: Tile?, range: number?): Npc?
```
Hovers up to `PILOT_ASK_LIMIT` NPCs within `range` tiles (default `PILOT_RANGE`) of `near` (default you), nearest first, and returns the first offering "Glider". Nil when none.

## Gnomeglider.open

Definition:
```luau
function Gnomeglider.open(npc: Npc?, walk: boolean?): (boolean, string?)
```
Clears other interfaces with Escape, uses "Glider" on `npc` or `find_pilot()` (walking closer unless `walk` is false), and waits for the map. True when open, also if it already was; otherwise false and the reason.

Example:
```luau
local ok, why = Gnomeglider.open()
assert(ok, why)
print(table.concat(Gnomeglider.names() or {}, ", "))
```
