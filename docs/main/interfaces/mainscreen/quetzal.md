# Main.Interfaces.Mainscreen.Quetzal

The quetzal transport map: opened by "Travel" on Renu (group 874) or "Signal" on a quetzal whistle (group 949). Both maps share a layout, so every function works on whichever is open. Site names come from each marker's `action` in memory, with no mouse movement; a marker without one is hovered once and its name kept until the script ends. The map has no keyboard shortcuts, so sites are always clicked. Works like `Main.Interfaces.Mainscreen.Chartering`.

```luau
local Quetzal = require("@lib/main/interfaces/mainscreen/quetzal")
```

A `Marker` has `index` (its place among the map's children), `area` (the widget to click) and `here` (the site you are at).

The client never receives the whistle's charges except as chat lines ("Your quetzal whistle has N charges remaining." after every flight or "Check", "Your whistle has no charges." when empty), so `Quetzal.charges` reads and tracks them from chat. "Last-destination" flies to the site in varbit 9950 (1 is the map's first marker), so it survives manual flights and restarts.

## Constants

Definition:
```luau
Quetzal.GROUP = 874
Quetzal.WHISTLE_GROUP = 949
Quetzal.MARKERS = 12
Quetzal.HERE = 13
Quetzal.CLOSE = 18
Quetzal.NPC = "Renu"
Quetzal.OPTION = "Travel"
Quetzal.WHISTLES = { 29271, 29273, 29275, 33120 }
Quetzal.WHISTLE_OPTION = "Signal"
Quetzal.INVENTORY = 93
Quetzal.LAST_OPTION = "Last-destination"
Quetzal.LAST_VARBIT = 9950
Quetzal.CHARGES_PATTERN = "^Your quetzal whistle has (%d+) charges? remaining"
Quetzal.EMPTY_MESSAGE = "Your whistle has no charges."
Quetzal.CHECK_OPTION = "Check"
Quetzal.OPEN_TIMEOUT_MS = 3000
Quetzal.HOVER_TIMEOUT_MS = 800
Quetzal.CONFIRM_TIMEOUT_MS = 4000
Quetzal.CHECK_TIMEOUT_MS = 2400
Quetzal.POLL_MS = 50
Quetzal.SETTLE_MS = 150
Quetzal.OPEN_SETTLE_MS = { 250, 500 }
Quetzal.ASK_LIMIT = 6
Quetzal.ASK_RANGE = 12
Quetzal.HOVER_MS = 350
```
Widget ids, the NPC, whistle ids and options, the inventory container, the last-site varbit, the charge chat lines, and timings. `ASK_LIMIT`, `ASK_RANGE` and `HOVER_MS` bound the hover search for a nameless Renu.

## Quetzal.is_open

Definition:
```luau
function Quetzal.is_open(): boolean
```
Whether either map is open.

## Quetzal.wait_open

Definition:
```luau
function Quetzal.wait_open(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (default `OPEN_TIMEOUT_MS`) for the map. False on timeout.

## Quetzal.markers

Definition:
```luau
function Quetzal.markers(): { Marker }?
```
The visible markers in map order, including the current site. Nil when the map isn't open.

## Quetzal.hover_name

Definition:
```luau
function Quetzal.hover_name(marker: Marker): string?
```
Hovers the marker and returns the site name the menu offers, nil if no menu shows within `HOVER_TIMEOUT_MS`.

## Quetzal.names

Definition:
```luau
function Quetzal.names(): { [number]: string }?
```
Site names keyed by marker `index` (not a sequence). Unread markers are hovered; a name another marker already has is re-read once and dropped if it repeats. Nil when the map isn't open.

Example:
```luau
for index, name in pairs(Quetzal.names() or {}) do
	print(index, name)
end
```

## Quetzal.find

Definition:
```luau
function Quetzal.find(name: string): Marker?
```
The marker for `name`, case-insensitive. An exact match wins; otherwise a substring match either way counts only if exactly one site fits. Hovers unread markers as needed.

## Quetzal.select

Definition:
```luau
function Quetzal.select(site: Site): boolean
```
Hovers the site's marker, clicks only if the menu offers that site, and waits for the map to close. On the whistle map this takes one off the tracked charges. False when the site isn't found, the menu disagrees, or the map stays open. Doesn't wait for the flight.

Example:
```luau
assert(Quetzal.open(), "couldn't open the quetzal map")
assert(Quetzal.select(Quetzal.Site.Aldarin), "couldn't choose Aldarin")
```

## Quetzal.Site

Definition:
```luau
export type Site = "Civitas illa Fortis" | "The Teomat" | "Sunset Coast" | "Hunter Guild" | "Cam Torum Entrance"
	| "Colossal Wyrm Remains" | "Outer Fortis" | "Fortis Colosseum" | "Aldarin" | "Quetzacalli Gorge"
	| "Salvager Overlook" | "Tal Teklan" | "Auburnvale" | "Kastori"
```
Every landing site in map order. `Quetzal.Site` is a frozen table keyed without spaces (`Quetzal.Site.CamTorumEntrance`, `Quetzal.Site.CivitasillaFortis`).

## Quetzal.close_button

Definition:
```luau
function Quetzal.close_button(): Widget?
```
The close button, nil when the map isn't open.

## Quetzal.close

Definition:
```luau
function Quetzal.close(key_probability: number?): boolean
```
Closes the map via `Toplevel.close`: Escape with chance `key_probability` (nil or 0 uses the biometric), else the close button. True when closed, also if it wasn't open.

## Quetzal.nearest

Definition:
```luau
function Quetzal.nearest(): Npc?
```
The nearest NPC named Renu. The client often gives Renu an empty name, so failing that it hovers up to `ASK_LIMIT` nameless NPCs within `ASK_RANGE` tiles, nearest first, and returns the one offering "Travel" on Renu. Nil when none.

## Quetzal.open

Definition:
```luau
function Quetzal.open(npc: Npc?, walk: boolean?): boolean
```
Clears other interfaces with Escape, uses "Travel" on `npc` or the nearest Renu (walking closer unless `walk` is false), and waits for the map. True when open, also if it already was.

Example:
```luau
if Quetzal.open() then
	print(Quetzal.find("Kastori") ~= nil)
	Quetzal.close()
end
```

## Quetzal.last_destination

Definition:
```luau
function Quetzal.last_destination(): Site?
```
The site "Last-destination" flies to, from varbit 9950. Nil when unset or unknown.

## Quetzal.is_last

Definition:
```luau
function Quetzal.is_last(name: string): boolean
```
Whether the last destination matches `name`, case-insensitive, substring either way ("Cam Torum").

## Quetzal.fly_last

Definition:
```luau
function Quetzal.fly_last(npc: Npc?, walk: boolean?): boolean
```
Uses "Last-destination" on `npc` or the nearest Renu, walking closer unless `walk` is false. True when clicked; doesn't wait for the flight.

Example:
```luau
if Quetzal.is_last("Aldarin") then
	Quetzal.fly_last()
end
```

## Quetzal.whistle_slot

Definition:
```luau
function Quetzal.whistle_slot(): number?
```
The inventory slot of a quetzal whistle, nil when none is held.

## Quetzal.charges

Definition:
```luau
function Quetzal.charges(cached: boolean?): number?
```
The whistle's charges. By default uses "Check" and waits up to `CHECK_TIMEOUT_MS` for the chat line. With `cached`, returns the count tracked from chat (any flight or "Check" line seen since or before the script started, minus flights this module sent) and only checks when nothing is tracked yet. Nil when no whistle is held or no line arrived. The tracked count can lag recharges or a swapped whistle until the next line.

Example:
```luau
if (Quetzal.charges(true) or 0) > 0 then
	Quetzal.signal_last()
end
```

## Quetzal.signal

Definition:
```luau
function Quetzal.signal(): (boolean, string?)
```
Clears other interfaces with Escape, uses "Signal" on the whistle and waits for the map. True when open, also if it already was; otherwise false and the reason. An empty whistle shows as a map that doesn't open.

Example:
```luau
local ok, why = Quetzal.signal()
assert(ok, why)
assert(Quetzal.select(Quetzal.Site.Aldarin), "couldn't choose Aldarin")
```

## Quetzal.signal_last

Definition:
```luau
function Quetzal.signal_last(): boolean
```
Uses "Last-destination" on the whistle and takes one off the tracked charges. True when clicked. Doesn't wait for the flight, and an empty whistle only says so in chat, so check your position.
