# Main.Interfaces.Mainscreen.Quetzal

The quetzal transport map of Varlamore: a map with a model on every landing site, opened by "Travel" on a Renu (group 874, `quetzal_menu` in the cache) or "Signal" on a quetzal whistle (group 949, `quetzalwhistle_menu`). The two are laid out alike, so everything here works on whichever is open. The markers carry no text, but the game keeps each site's name as the marker's first menu option, which the widget exposes as `action`, so names are read straight from memory with no mouse movement. Should a marker have no `action`, its name is read by hovering (the menu offers the site's name) and kept until the script ends. It works like the charter ship map, `Main.Interfaces.Mainscreen.Chartering`.

```luau
local Quetzal = require("@lib/main/interfaces/mainscreen/quetzal")
```

The map has no keyboard shortcuts: digits, letters, space and enter were all tried on a live client and none did anything. Sites are chosen by clicking their marker. How a site that isn't unlocked looks on the map is not known: the module was only checked on an account with every site unlocked.

A marker has `index` (its place among the map's children), `area` (the model: where to hover and click) and `here` (the site you are at, which the game marks with a second model).

The game never sends the whistle's charges to the client: no varp, varbit or varc holds them (checked live by name across the cache and by comparing every varp around a flight), and the server sends no packet for them but a chat line. Every flight and every "Check" prints "Your quetzal whistle has N charges remaining.", and an empty whistle says "Your whistle has no charges." and does nothing else, so `Quetzal.charges` reads the count from those lines and keeps it.

Renu and the whistle also offer "Last-destination", which flies straight to the last site. The game keeps that site itself (varbit 9950, `quetzal_last_destination`, 1 for the map's first marker and so on), so it stays right after a flight made by hand, by another script or before a restart. Moving by anything but a quetzal doesn't change it. Eight of the fourteen values were seen live: Civitas illa Fortis, Sunset Coast, Hunter Guild, Cam Torum Entrance, Aldarin, Salvager Overlook, Auburnvale and Kastori. The rest follow the map's order.

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
The interface piece numbers, the NPC and the option that open the map, the whistles and their option that do the same, the inventory's container, the option and the varbit for the last site, the chat lines that give the charges and the option that prints them, and the waits: for `wait_open`, for a hover to show the menu, for the map to go after a click, for "Check" to print the charges, between looks, for the menu to follow the mouse, and the pause `open` makes once the map shows. The last three are for finding Renu: how many nameless NPCs are asked at most, how far to look, and how long to wait after hovering one.

## Quetzal.is_open

Definition:
```luau
function Quetzal.is_open(): boolean
```
Whether the map is open.

## Quetzal.wait_open

Definition:
```luau
function Quetzal.wait_open(timeout_ms: number?): boolean
```
Waits for the map to open (`OPEN_TIMEOUT_MS` by default). False when it didn't.

## Quetzal.markers

Definition:
```luau
function Quetzal.markers(): { Marker }?
```
The sites on the map in the map's own order, including the one you are at. Nil when the map isn't open.

## Quetzal.hover_name

Definition:
```luau
function Quetzal.hover_name(marker: Marker): string?
```
Moves the mouse over the marker and returns the site the menu offers.

## Quetzal.names

Definition:
```luau
function Quetzal.names(): { [number]: string }?
```
The name of every site by marker `index`. Read from the markers' `action`, so it is instant and the mouse stays still; any marker without one is hovered (about 350 ms each). A name two markers would share is taken to be a stale read: it is read again and dropped if it repeats.

Example:
```luau
local Quetzal = require("@lib/main/interfaces/mainscreen/quetzal")

for index, name in pairs(Quetzal.names() or {}) do
	print(index, name)
end
```

## Quetzal.find

Definition:
```luau
function Quetzal.find(name: string): Marker?
```
The marker of the site called `name`, ignoring case. An exact name wins. Otherwise a name that contains the other ("Wyrm" for "Colossal Wyrm Remains") counts, but only when exactly one site fits. Markers not read before are hovered as needed.

## Quetzal.select

Definition:
```luau
function Quetzal.select(site: Site): boolean
```
Clicks the site's marker, which sends the quetzal, and waits for the map to go. On the whistle's map that spends a charge, which comes off the count `Quetzal.charges` tracks. The click only happens once the menu under the mouse offers the site that was asked for, so a marker that was misread costs nothing. `site` is one of `Quetzal.Site` (see below), so no free text is typed. False when no site has that name, the menu didn't offer it, or the map stayed open. The trip itself is not waited for.

Example:
```luau
local Quetzal = require("@lib/main/interfaces/mainscreen/quetzal")

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
Every landing site, as the game names it. `Quetzal.Site` is a frozen table of them keyed without spaces (`Quetzal.Site.TheTeomat`, `Quetzal.Site.CamTorumEntrance`), so a trip is `Quetzal.select(Quetzal.Site.Kastori)` and a misspelled site is a type error.

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
Closes the map and waits for it to go: Escape with chance `key_probability` (nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`. True when it's closed (also if it was not open).

## Quetzal.nearest

Definition:
```luau
function Quetzal.nearest(): Npc?
```
The nearest Renu. The NPC list gives Renu an empty name (the game shows the NPC as another one), so when no NPC is called Renu, the nameless NPCs near you are hovered, nearest first, and the one whose menu offers "Travel" on "Renu" is taken. Nil when there is none.

## Quetzal.open

Definition:
```luau
function Quetzal.open(npc: Npc?, walk: boolean?): boolean
```
Opens the map: closes any other main screen interface with Escape, then uses "Travel" on the nearest Renu (or `npc`), walking closer first unless `walk` is false, and waits for the map. True when it is open, also if it already was. If the click opened a menu on something else, "Travel" is taken when what's hovered is Renu.

Example:
```luau
local Quetzal = require("@lib/main/interfaces/mainscreen/quetzal")

if Quetzal.open() then
	print(table.concat(Quetzal.names() or {}, ", "))
	Quetzal.close()
end
```

## Quetzal.last_destination

Definition:
```luau
function Quetzal.last_destination(): Site?
```
The site "Last-destination" flies to, read from the game now. Nil when it has none, or one this module doesn't know.

## Quetzal.is_last

Definition:
```luau
function Quetzal.is_last(name: string): boolean
```
Whether "Last-destination" goes to the site called `name`, ignoring case. One name containing the other is enough ("Cam Torum").

## Quetzal.fly_last

Definition:
```luau
function Quetzal.fly_last(npc: Npc?, walk: boolean?): boolean
```
Flies to the last site with the nearest Renu (or `npc`), walking closer first unless `walk` is false. True when the option was clicked. The flight is not waited for.

Example:
```luau
local Quetzal = require("@lib/main/interfaces/mainscreen/quetzal")

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
The whistle's charges. By default it uses "Check" on the whistle in the inventory and reads the line that prints (up to `CHECK_TIMEOUT_MS`). With `cached`, it returns the count the module tracks, with no mouse movement, and only uses "Check" when it has none yet.

The module tracks the count from the chat: every call reads the game messages it hasn't seen yet, so "Your quetzal whistle has N charges remaining." after any flight or "Check" (by the script, by hand or by `Transports`) updates it, and "Your whistle has no charges." makes it 0. A flight this module sends with the whistle (`Quetzal.signal_last`, or `Quetzal.select` on the whistle's map) takes one off a tracked count straight away, before the line arrives; the line then sets the exact count. A line in the chat from before the script started counts too. Messages are told apart by their time and then their uid, so the uids starting again after a relog don't hide new lines. The count is as of the last such line: charges added since, another whistle picked up, or a line that scrolled out of the chat between two calls only show after the next flight or "Check". The count lasts until the script ends.

Nil when no whistle is held, or "Check" didn't print the charges in time; with `cached`, only when that happens with nothing tracked yet.

Example:
```luau
local Quetzal = require("@lib/main/interfaces/mainscreen/quetzal")

if (Quetzal.charges(true) or 0) > 0 then
	Quetzal.signal_last()
end
```

## Quetzal.signal

Definition:
```luau
function Quetzal.signal(): (boolean, string?)
```
Opens the map with the whistle in the inventory, from anywhere: closes any other main screen interface with Escape, uses "Signal" and waits for the map. True when it is open, also if it already was. When it didn't work the second result says why. An empty whistle only says so in the chat, so it shows as a map that doesn't open.

Example:
```luau
local Quetzal = require("@lib/main/interfaces/mainscreen/quetzal")

local ok, why = Quetzal.signal()
assert(ok, why)
assert(Quetzal.select(Quetzal.Site.Aldarin), "couldn't choose Aldarin")
```

## Quetzal.signal_last

Definition:
```luau
function Quetzal.signal_last(): boolean
```
Flies to the last site with the whistle in the inventory, from anywhere. True when the option was clicked. A click takes a charge off the count `Quetzal.charges` tracks. The flight is not waited for, and an empty whistle only says so in the chat, so check the position to know it worked.
