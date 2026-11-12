# Main.Interfaces.Mainscreen.Chartering

Charter ship destinations, picked the way a player would: by key, on the map or in the side list, chosen by chance. `Chartering.Tab` is the side list (shows each port's key), `Chartering.Map` is the map; the top-level functions work over both.

```luau
local Chartering = require("@lib/main/interfaces/mainscreen/chartering")
```

## Constants

Definition:
```luau
Chartering.KEY_CHANCE = 0.5
Chartering.MAP_CHANCE = 0.4
Chartering.CONFIRM_TIMEOUT_MS = 4000
Chartering.POLL_MS = 100
Chartering.TRADER_RANGE = 12
Chartering.TRADER_ASK_LIMIT = 8
Chartering.TRADER_HOVER_MS = 350
Chartering.SETTLE_MS = { 250, 500 }
```
- `KEY_CHANCE`, `MAP_CHANCE`: biometric centres for choosing the key, or the map over the list.
- `CONFIRM_TIMEOUT_MS`, `POLL_MS`: how long a choice may leave the interface open before the next way is tried, and the poll rate.
- `TRADER_RANGE`, `TRADER_ASK_LIMIT`, `TRADER_HOVER_MS`: trader search radius in tiles, max NPCs hovered, wait for each menu.
- `SETTLE_MS`: min/max pause after `open`; the game ignores keys pressed right after the list appears.

## Chartering.is_open

Definition:
```luau
function Chartering.is_open(): boolean
```
Whether the list or the map is showing.

## Chartering.wait_open

Definition:
```luau
function Chartering.wait_open(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (default `Tab.OPEN_TIMEOUT_MS`, 8000) for the list or the map. False on timeout.

## Chartering.find_trader

Definition:
```luau
function Chartering.find_trader(option: string, near: Tile, range: number?): Npc?
```
The NPC within `range` tiles (default `TRADER_RANGE`) of `near` whose menu offers `option`. Hovers the nearest NPCs, up to `TRADER_ASK_LIMIT`, and reads each menu, since traders differ by port. Nil when none matched.

## Chartering.open

Definition:
```luau
function Chartering.open(option: string?, near: Tile?, range: number?): (boolean, string?)
```
Finds the trader near `near` (default: your position), interacts with `option` (default "Charter"), waits for the list or map and settles `SETTLE_MS`. True at once when already open; otherwise false plus a reason. Used by `Transports.sail`.

Example:
```luau
local ok, why = Chartering.open()
assert(ok, why)
print("chose by", Chartering.select(Chartering.Port.PortKhazard))
```

## Chartering.Port

Definition:
```luau
export type Port = "Port Sarim" | "Brimhaven" | "Catherby" | "Mos Le'Harmless" | "Musa Point" | "Port Khazard" | "Port Phasmatys" | "Karamja Shipyard" | "Port Tyras" | "Corsair Cove" | "Prifddinas" | "Port Piscarilius" | "Land's End" | "Aldarin" | "Sunset Coast" | "The Pandemonium" | "The Summer Shore" | "Deepfin Point" | "Port Roberts" | "Civitas illa Fortis" | "Red Rock"
```
Charter ports by their in-game names. `Chartering.Port` is a frozen table keyed without spaces or punctuation (`Port.LandsEnd`, `Port.MosLeHarmless`), so a misspelling is a type error. A trader never offers its own port and not every other one; `select` returns nil for a port not offered. `CivitasIllaFortis` and `RedRock` come from transport data and are unconfirmed in a live list.

## Chartering.select

Definition:
```luau
function Chartering.select(port: Port, key_probability: number?, map_probability: number?): Method?
```
Sends the boat to `port` (costs the fare). Tries the key (needs the list) with chance `key_probability`, else the map with chance `map_probability`, else clicks the list; nil or 0 uses a biometric around `KEY_CHANCE`/`MAP_CHANCE`, any other number is used as is. If a way can't be used or leaves the interface open after `CONFIRM_TIMEOUT_MS`, falls back to list, then map, then key. Returns `"key"`, `"map"` or `"list"`, or nil when the port isn't offered or nothing worked. Does not wait for the sailing.

Example:
```luau
assert(Chartering.wait_open(), "no charter menu is open")
print("chose by", Chartering.select(Chartering.Port.PortKhazard))
```

## Chartering.Tab (the side list)

The side tab shown while a charter menu is open: one row per destination (`<col=ffffff>K</col> :  Name`), scrolled, about ten visible, your current port omitted. Keys differ by port, so never pick by key alone.

A `Destination` has `key`, `name`, `port` (index in the game's order), `visible` (fully inside the scroll view) and `row` (widget to click).

### Constants

Definition:
```luau
Tab.GROUP = 885
Tab.LIST = 4
Tab.TITLE = 7
Tab.OPEN_TIMEOUT_MS = 8000
Tab.POLL_MS = 150
Tab.MAX_SCROLLS = 30
```
Widget ids, `wait_open` timeout and poll rate, and the scroll attempts before `scroll_to` gives up.

## Tab.is_open

Definition:
```luau
function Tab.is_open(): boolean
```
Whether the list is showing.

Example:
```luau
print("open:", Chartering.Tab.is_open())
```

## Tab.wait_open

Definition:
```luau
function Tab.wait_open(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (default `OPEN_TIMEOUT_MS`) for the list. False on timeout.

## Tab.destinations

Definition:
```luau
function Tab.destinations(): { Destination }?
```
Every destination top to bottom, including rows scrolled out of view. Nil when the list isn't open.

Example:
```luau
for _, d in ipairs(Chartering.Tab.destinations() or {}) do
	print(d.key, d.name, d.visible)
end
```

## Tab.names

Definition:
```luau
function Tab.names(): { string }?
```
Destination names top to bottom. Nil when the list isn't open.

## Tab.find

Definition:
```luau
function Tab.find(name: string): Destination?
```
The destination called `name`, case-insensitive. An exact match wins; otherwise a substring match either way ("Shipyard" for "Karamja Shipyard") counts only if exactly one fits. Nil otherwise.

Example:
```luau
local d = Chartering.Tab.find("Catherby")
print(if d then `{d.key}: {d.name}` else "not in the list")
```

## Tab.scroll_to

Definition:
```luau
function Tab.scroll_to(name: string): Destination?
```
Mouse-wheels the list until the destination is fully visible and returns it. Nil when it isn't listed, the list stops moving, or `MAX_SCROLLS` runs out.

## Tab.select

Definition:
```luau
function Tab.select(name: string): boolean
```
Scrolls to the destination and clicks it (sends the boat, costs the fare). False when it isn't listed. Does not wait for the sailing.

Example:
```luau
assert(Chartering.Tab.wait_open(), "the list didn't open")
assert(Chartering.Tab.select("Port Khazard"), "Port Khazard isn't offered here")
```

## Tab.key_code

Definition:
```luau
function Tab.key_code(d: Destination): number?
```
The key code of a destination's single digit or letter key (its uppercase ASCII code). Nil for anything else.

## Tab.press

Definition:
```luau
function Tab.press(name: string): boolean
```
Presses the destination's key; no scrolling needed. False when it isn't listed or its key has no code. A first press after the menu sat open a while has been seen to do nothing, so prefer `Chartering.select`, which falls back to a click.

Example:
```luau
assert(Chartering.Tab.press("Catherby"), "Catherby isn't offered here")
```

## Chartering.Map (the map)

The sea chart (group 72, cache name `sailing_menu`) shown while a charter menu is open, with a marker per port. Markers carry no text: names are read by hovering each (about a second per marker on first read) and cached for the rest of the script. Map order differs from the list's.

Click squares overlap and are bigger than their pictures, so each marker's `spot` is a random point that really belongs to it. A `Marker` has `index` (child index), `picture`, `spot` and `here` (your current port; can't be sailed to).

### Constants

Definition:
```luau
Map.GROUP = 72
Map.CLOSE = 2
Map.MARKERS = 3
Map.MARKER_SPRITE = 6916
Map.HERE_SPRITE = 6918
Map.OPEN_TIMEOUT_MS = 8000
Map.HOVER_TIMEOUT_MS = 800
Map.POLL_MS = 50
Map.SETTLE_MS = 150
Map.GRID = 3
```
Widget ids, marker and current-port sprites, `wait_open` timeout, hover wait for the menu, menu poll rate, settle after moving, and the pixel step when searching for a `spot`.

## Map.is_open

Definition:
```luau
function Map.is_open(): boolean
```
Whether the map is showing.

## Map.wait_open

Definition:
```luau
function Map.wait_open(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (default `OPEN_TIMEOUT_MS`) for the map. False on timeout.

## Map.markers

Definition:
```luau
function Map.markers(): { Marker }?
```
The visible markers in map order, including your current port. Nil when the map isn't open.

Example:
```luau
for _, m in ipairs(Chartering.Map.markers() or {}) do
	print(m.index, m.here)
end
```

## Map.hover_name

Definition:
```luau
function Map.hover_name(marker: Marker): string?
```
Hovers the marker and returns the port its menu offers. Nil for `here` or when no name showed within `HOVER_TIMEOUT_MS`.

## Map.names

Definition:
```luau
function Map.names(): { [number]: string }?
```
Names of every sailable port by marker `index`, hovering unread markers. A name already held by another marker is re-read once and dropped if it repeats. Nil when the map isn't open.

Example:
```luau
for index, name in pairs(Chartering.Map.names() or {}) do
	print(index, name)
end
```

## Map.find

Definition:
```luau
function Map.find(name: string): Marker?
```
The marker for `name`, matched like `Tab.find`, hovering unread markers as needed. Nil when nothing fits.

## Map.select

Definition:
```luau
function Map.select(name: string): boolean
```
Hovers the port's marker and clicks only if the menu offers that port (sends the boat, costs the fare). False when not found or the menu shows something else. Does not wait for the sailing.

## Map.close

Definition:
```luau
function Map.close(key_probability: number?): boolean
```
Closes the map via `Toplevel.close`: Escape with chance `key_probability` (nil or 0 uses the biometric) unless "Esc to close" is off, else the close button. True once closed.
