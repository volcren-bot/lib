# Main.Interfaces.Mainscreen.Chartering

Picking a charter destination the way a player would: with the keyboard, on the map or in the side list, chosen by chance. Both interfaces live in this module: `Chartering.Tab` is the side list (which shows each port's key) and `Chartering.Map` is the map. The functions below work over both.

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
How far from a tile to look for the trader, how many NPCs to ask at most, and how long to wait after hovering one for its menu. The chance a biometric is rolled around for pressing the destination's key, and for using the map instead of the list; how long an interface may stay open after a choice before the next way is tried; how often that is looked at.

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
Waits for the list or the map to open (8 seconds by default). False when neither did.

## Chartering.find_trader

Definition:
```luau
function Chartering.find_trader(option: string, near: Tile, range: number?): Npc?
```
The NPC within `range` tiles (`TRADER_RANGE` by default) of `near` that offers `option`, found by asking: each one, nearest first, is hovered and its menu read. The traders are different NPCs by port, so the option is all that identifies one.

## Chartering.open

Definition:
```luau
function Chartering.open(option: string?, near: Tile?, range: number?): (boolean, string?)
```
Opens the charter menu: talks to the trader near `near` (your position by default) with `option` ("Charter" by default) and waits for the list or the map. True also when it was open already. When it didn't work, the second result says why. This is what `Transports.sail` uses.

Example:
```luau
local Chartering = require("@lib/main/interfaces/mainscreen/chartering")

local ok, why = Chartering.open()
assert(ok, why)
print("chose by", Chartering.select(Chartering.Port.PortKhazard))
```

## Chartering.Port

Definition:
```luau
export type Port = "Port Sarim" | "Brimhaven" | "Catherby" | "Mos Le'Harmless" | "Musa Point" | "Port Khazard" | "Port Phasmatys" | "Karamja Shipyard" | "Port Tyras" | "Corsair Cove" | "Prifddinas" | "Port Piscarilius" | "Land's End" | "Aldarin" | "Sunset Coast" | "The Pandemonium" | "The Summer Shore" | "Deepfin Point" | "Port Roberts" | "Civitas illa Fortis" | "Red Rock"
```
The charter ports, as the game names them. `Chartering.Port` is a frozen table of them keyed without spaces or punctuation (`Chartering.Port.LandsEnd`, `Chartering.Port.MosLeHarmless`), so a trip is `Chartering.select(Chartering.Port.Catherby)` and a misspelled port is a type error. A trader never offers its own port and not every other one, so a port that isn't offered makes `select` return nil. `CivitasIllaFortis` (key D) and `RedRock` (key K) come from the transport data and haven't been seen in a live list. The game's keys G, H and L are not covered yet: none has been seen anywhere. `KaramjaShipyard` is the game's name for the port the transport data calls "Shipyard".

## Chartering.select

Definition:
```luau
function Chartering.select(port: Port, key_probability: number?, map_probability: number?): Method?
```
Chooses the destination by name, which sends the boat and costs the fare. The way is picked by chance, in this order:

1. The keyboard, with chance `key_probability`. It needs the list, which shows the port's key.
2. Else the map, with chance `map_probability`. It needs the map.
3. Else the side list, clicked.

A chance of nil or 0 is a biometric around `KEY_CHANCE` or `MAP_CHANCE`. Any other number is used as it is, so 1 always takes that way when it is possible and a small number almost never does.

If a way is sent but the interface is still open after `CONFIRM_TIMEOUT_MS`, or a way can't be used (the key's list isn't open, the name isn't there), the next way is tried: clicking the list, then the map, then the key. Returns `"key"`, `"map"` or `"list"` for the way that worked, or nil when the name isn't offered or nothing worked. The sailing is not waited for.

Example:
```luau
local Chartering = require("@lib/main/interfaces/mainscreen/chartering")

assert(Chartering.wait_open(), "no charter menu is open")
local how = Chartering.select(Chartering.Port.PortKhazard)
print("chose by", how)
```

`SETTLE_MS` is the pause (minimum and maximum, in milliseconds) `open` makes after it finds the list open: the game ignores a key pressed in the first moments after the list appears.

## Chartering.Tab (the side list)

The charter ship list: the game tab that takes the place of the side panel while a charter trader's menu is open. It lists the ports you can sail to, one row each (`<col=ffffff>K</col> :  Name`), in a scrolled list that shows about ten at once. The port you are in is not listed. The same ports are drawn on a map in the middle of the screen, see `Chartering.Map`.

The list opens when you talk to a trader with the option "Charter" (for example `Npcs.interact(trader, "Charter")`).

A destination has `key` (the letter or digit before the name), `name`, `port` (the port's place in the game's own order), `visible` (fully inside the scrolled list) and `row` (the interface piece to click). The key is never a safe way to pick a port: the letters differ by port.

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
The interface piece numbers, how long `wait_open` waits, how often it looks, and how many scrolls are tried before giving up on a destination.

### Tab.is_open

Definition:
```luau
function Tab.is_open(): boolean
```
Whether the list is showing.

Example:
```luau
local Tab = require("@lib/main/interfaces/mainscreen/chartering").Tab

print("open:", Tab.is_open())
```

### Tab.wait_open

Definition:
```luau
function Tab.wait_open(timeout_ms: number?): boolean
```
Waits for the list to open (`OPEN_TIMEOUT_MS` by default). False when it didn't.

### Tab.destinations

Definition:
```luau
function Tab.destinations(): { Destination }?
```
Every port in the list, top to bottom, including ones scrolled out of view. Nil when the list isn't open.

Example:
```luau
local Tab = require("@lib/main/interfaces/mainscreen/chartering").Tab

for _, d in ipairs(Tab.destinations() or {}) do
	print(d.key, d.name, d.visible)
end
```

### Tab.names

Definition:
```luau
function Tab.names(): { string }?
```
The names of the ports in the list, top to bottom.

### Tab.find

Definition:
```luau
function Tab.find(name: string): Destination?
```
The destination called `name`, ignoring case. An exact name wins. Otherwise a name that contains the other ("Shipyard" for "Karamja Shipyard") counts, but only when exactly one port fits. Nil when nothing fits.

Example:
```luau
local Tab = require("@lib/main/interfaces/mainscreen/chartering").Tab

local d = Tab.find("Catherby")
print(if d then `{d.key}: {d.name}` else "not in the list")
```

### Tab.scroll_to

Definition:
```luau
function Tab.scroll_to(name: string): Destination?
```
Scrolls the list with the mouse wheel until the destination is fully shown, and returns it. Nil when the name isn't in the list or the list stops moving.

### Tab.select

Definition:
```luau
function Tab.select(name: string): boolean
```
Scrolls to the destination and clicks it, which sends the boat and costs the fare. False when the name isn't in the list. The sailing is not waited for.

Example:
```luau
local Tab = require("@lib/main/interfaces/mainscreen/chartering").Tab

assert(Tab.wait_open(), "the list didn't open")
assert(Tab.select("Port Khazard"), "Port Khazard isn't offered here")
```

### Tab.key_code

Definition:
```luau
function Tab.key_code(d: Destination): number?
```
The key code for a destination's key (digits and capital letters are their own codes). Nil for anything else.

### Tab.press

Definition:
```luau
function Tab.press(name: string): boolean
```
Presses the key the destination's row shows, which should send the boat like a click does. No scrolling is needed. False when the name isn't in the list. The game takes the key: checked live with keys 0 and 5 (one press sent the boat). Once, the very first press after the menu had been left open for a while did nothing, so use `Chartering.select`, which falls back to a click. To choose between the keyboard, the map and the list by chance, use `Chartering.select`.

Example:
```luau
local Tab = require("@lib/main/interfaces/mainscreen/chartering").Tab

assert(Tab.press("Catherby"), "Catherby isn't offered here")
```

## Chartering.Map (the map)

The charter ship map: the sea chart in the middle of the screen while a charter trader's menu is open, with a marker on every port. It is group 72, which the game's cache calls `sailing_menu`; this module has only been checked against the charter trader's menu. The list of the same ports in the side tab is `Chartering.Tab`.

The markers carry no text. The game offers the port's name as the menu option while the mouse is over a marker, so names are read by hovering. The first read of a map moves the mouse over every marker (about a second each); what was read is kept until the script ends. The map's order is not the list's, so the two are not matched by position.

Two details the module takes care of: each marker's click square is bigger than its picture, and the squares of later markers lie on top of earlier ones, so the centre of a picture can belong to another port. A marker's `spot` is a point that really belongs to it. And a marker under the mouse is drawn with another picture, so the picture is only used to tell the port you are in (`here`).

A marker has `index` (its place among the map's children), `picture`, `spot` (where to hover and click) and `here` (the port you are in; it can't be sailed to).

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
The interface piece numbers, the pictures of a marker and of the port you are in, and the waits: how long `wait_open` waits, how long a hover waits for the menu, how often the menu is looked at, how long the menu is given to follow the mouse, and the spacing in pixels of the points tried when looking for a marker's `spot`.

### Map.is_open

Definition:
```luau
function Map.is_open(): boolean
```
Whether the map is showing.

### Map.wait_open

Definition:
```luau
function Map.wait_open(timeout_ms: number?): boolean
```
Waits for the map to open (`OPEN_TIMEOUT_MS` by default). False when it didn't.

### Map.markers

Definition:
```luau
function Map.markers(): { Marker }?
```
The ports the map shows, in the map's own order, including the one you are in. Ports the game hides from this trader are left out. Nil when the map isn't open.

Example:
```luau
local Map = require("@lib/main/interfaces/mainscreen/chartering").Map

for _, m in ipairs(Map.markers() or {}) do
	print(m.index, m.here)
end
```

### Map.hover_name

Definition:
```luau
function Map.hover_name(marker: Marker): string?
```
Moves the mouse over the marker and returns the port the menu offers. Nil for the port you are in or when no name showed.

### Map.names

Definition:
```luau
function Map.names(): { [number]: string }?
```
The name of every port you can sail to, by marker `index`. Markers not read before are hovered now. A name two markers would share is taken to be a stale read: it is read again and dropped if it repeats.

Example:
```luau
local Map = require("@lib/main/interfaces/mainscreen/chartering").Map

for index, name in pairs(Map.names() or {}) do
	print(index, name)
end
```

### Map.find

Definition:
```luau
function Map.find(name: string): Marker?
```
The marker of the port called `name`, ignoring case. An exact name wins. Otherwise a name that contains the other counts, but only when exactly one port fits. Markers not read before are hovered as needed.

### Map.select

Definition:
```luau
function Map.select(name: string): boolean
```
Clicks the port's marker, which sends the boat and costs the fare. The click only happens once the menu under the mouse offers the port that was asked for; if it offers anything else, nothing is clicked and this returns false. False also when no port has that name. The sailing is not waited for.

### Map.close

Definition:
```luau
function Map.close(key_probability: number?): boolean
```
Closes the map and waits for it to go: Escape with chance `key_probability` (nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`. True when it's closed.

## Tab.is_open

Definition:
```luau
function Tab.is_open(): boolean
```
TODO...

Example:
```luau

```

## Tab.wait_open

Definition:
```luau
function Tab.wait_open(timeout_ms: number?): boolean
```
TODO...

Example:
```luau

```

## Tab.destinations

Definition:
```luau
function Tab.destinations(): { Destination }?
```
TODO...

Example:
```luau

```

## Tab.find

Definition:
```luau
function Tab.find(name: string): Destination?
```
TODO...

Example:
```luau

```

## Tab.names

Definition:
```luau
function Tab.names(): { string }?
```
TODO...

Example:
```luau

```

## Tab.scroll_to

Definition:
```luau
function Tab.scroll_to(name: string): Destination?
```
TODO...

Example:
```luau

```

## Tab.select

Definition:
```luau
function Tab.select(name: string): boolean
```
TODO...

Example:
```luau

```

## Tab.key_code

Definition:
```luau
function Tab.key_code(d: Destination): number?
```
TODO...

Example:
```luau

```

## Tab.press

Definition:
```luau
function Tab.press(name: string): boolean
```
TODO...

Example:
```luau

```

## Map.is_open

Definition:
```luau
function Map.is_open(): boolean
```
TODO...

Example:
```luau

```

## Map.wait_open

Definition:
```luau
function Map.wait_open(timeout_ms: number?): boolean
```
TODO...

Example:
```luau

```

## Map.markers

Definition:
```luau
function Map.markers(): { Marker }?
```
TODO...

Example:
```luau

```

## Map.hover_name

Definition:
```luau
function Map.hover_name(marker: Marker): string?
```
TODO...

Example:
```luau

```

## Map.names

Definition:
```luau
function Map.names(): { [number]: string }?
```
TODO...

Example:
```luau

```

## Map.find

Definition:
```luau
function Map.find(name: string): Marker?
```
TODO...

Example:
```luau

```

## Map.select

Definition:
```luau
function Map.select(name: string): boolean
```
TODO...

Example:
```luau

```

## Map.close

Definition:
```luau
function Map.close(key_probability: number?): boolean
```
TODO...

Example:
```luau

```
