# Main.Interfaces.Mainscreen.Canoe

The canoe stations of the two rivers. A station goes through four steps, and the next one is what its menu offers: "Chop-down", "Shape-Canoe" (opens group 416, `canoeing`), "Float Log" or another canoe's name, and "Paddle Canoe" (opens the river's map: group 952, `canoe_map_dougne`, or group 953, `canoe_map_lum`).

```luau
local Canoe = require("@lib/main/interfaces/mainscreen/canoe")
```

The canoe sinks at the end of the trip, and the station you left starts again from "Chop-down". Each station's progress is also in a varbit (`Canoe.STATIONS`), which `travel` watches to tell when a step is done.

| Canoe | Woodcutting | Stops |
| --- | --- | --- |
| Log | 12 | 1 |
| Dugout | 27 | 2 |
| Stable dugout | 42 | 3 |
| Waka | 57 | 4, and the Wilderness Pond |

**The axe.** A trip needs an axe the player can use, held or kept by a station's NPC. The NPC's "Store-axe" does whichever is due: it takes the held axe ("I'll hold onto that axe for you.") or gives the kept one back ("Here's your axe."). Any station's NPC gives and uses the same kept axe. No varp changes when an axe is stored, and the NPC's options stay the same, so the only way to learn that none is kept is to chop: "You need an axe which you have the required Woodcutting level to use to be able to chop down this tree." That gives `Canoe.NO_AXE`.

**On the map.** Only stops the canoe reaches offer "Travel to ...", and the station you are at offers nothing. The Ardougne map's Log trip and the Lumbridge map's Waka hover were read live. The Wilderness stops are never picked by the chooser from safety, and a warning the game may show for them hasn't been seen. The option's text can be cut short ("Travel to Tree Gnome Strong"), so a click is checked by the component's id.

## Constants

- `Canoe.Kind`: `Log`, `Dugout`, `StableDugout`, `Waka`.
- `Canoe.KINDS`: each canoe's button in group 416 and its level.
- `Canoe.PLACES`: each stop by the data's name: its river's map, its button and where a trip lands.
- `Canoe.STATIONS`: each station's object id: its state varbit and its river's map.
- `Canoe.KEEPERS`: the NPC ids of the stations (`canoeing_*` in the cache).
- `Canoe.NO_AXE`, `Canoe.CANT_REACH`: what `travel` says went wrong.
- `Canoe.STEP_TIMEOUT_MS`, `Canoe.SETTLED_MS`, `Canoe.TRIP_TIMEOUT_MS`, `Canoe.OPEN_TIMEOUT_MS`, `Canoe.HOVER_TIMEOUT_MS`: how long each wait lasts.

## Canoe.kind_for_level

Definition:
```luau
function Canoe.kind_for_level(level: number?): Kind
```
The smallest canoe for a trip the data says takes this Woodcutting level. The Waka when no level is given.

Example:
```luau
local Canoe = require("@lib/main/interfaces/mainscreen/canoe")

print(Canoe.kind_for_level(27)) -- Dugout
```

## Canoe.station

Definition:
```luau
function Canoe.station(): Host.Loc?
```
The nearest canoe station within `STATION_RANGE`.

Example:
```luau
local Canoe = require("@lib/main/interfaces/mainscreen/canoe")

local station = Canoe.station()
print(station and station.id)
```

## Canoe.stage

Definition:
```luau
function Canoe.stage(): ("chop" | "shape" | "float" | "paddle")?
```
What the nearest station needs next. It hovers the station, which has to be on the screen. Nil when there's none or its menu can't be read.

Example:
```luau
local Canoe = require("@lib/main/interfaces/mainscreen/canoe")

print(Canoe.stage())
```

## Canoe.travel

Definition:
```luau
function Canoe.travel(place: string, kind: Kind?): (boolean, string?)
```
Takes a canoe from the station beside the player to `place`, the data's name for the stop, starting from whichever step the station is on. `kind` is what to shape, the Waka by default. A canoe made earlier is used as it is, so it may be too small, which gives `CANT_REACH`.

The trip takes about 20 s, through a cutscene in another part of the map, so the player's tile jumps far away and back. True once landed; else false and why.

Example:
```luau
local Canoe = require("@lib/main/interfaces/mainscreen/canoe")

local ok, why = Canoe.travel("The Clock Tower", Canoe.Kind.Log)
print(ok, why)
```

## Canoe.keeper

Definition:
```luau
function Canoe.keeper(): Host.Npc?
```
The nearest station NPC within `STATION_RANGE`.

Example:
```luau
local Canoe = require("@lib/main/interfaces/mainscreen/canoe")

local keeper = Canoe.keeper()
print(keeper and keeper.name)
```

## Canoe.swap_axe

Definition:
```luau
function Canoe.swap_axe(): boolean
```
Clicks "Store-axe" on the station's NPC and continues the reply: gives the held axe to them, or gets a kept one back. True once the reply has been continued.

Example:
```luau
local Canoe = require("@lib/main/interfaces/mainscreen/canoe")

print(Canoe.swap_axe())
```
