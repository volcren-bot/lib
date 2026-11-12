# Main.Interfaces.Mainscreen.Canoe

The canoe stations on the two rivers. A station steps through "Chop-down", "Shape-Canoe" (group 416), "Float ..." and "Paddle Canoe" (map group 952 for Ardougne, 953 for Lumbridge); its menu shows the next step, and its varbit in `Canoe.STATIONS` changes as each finishes. After a trip the canoe sinks and the station resets to "Chop-down".

```luau
local Canoe = require("@lib/main/interfaces/mainscreen/canoe")
```

| Canoe | Woodcutting | Stops |
| --- | --- | --- |
| Log | 12 | 1 |
| Dugout | 27 | 2 |
| Stable dugout | 42 | 3 |
| Waka | 57 | 4, and the Wilderness Pond |

A trip needs a usable axe, held or kept by any station NPC ("Store-axe" toggles between the two). Nothing shows whether an axe is kept, so a missing one is only found by chopping, which gives `Canoe.NO_AXE`. On the map only reachable stops offer "Travel to ..."; clicks are checked by component id since the option text can be truncated.

## Constants

- `Canoe.Kind`: `Log`, `Dugout`, `StableDugout`, `Waka`.
- `Canoe.KINDS`: each canoe's button in group 416 and its level.
- `Canoe.PLACES`: each stop by name: its map, button and landing tile.
- `Canoe.STATIONS`: station object id to its state varbit and map.
- `Canoe.KEEPERS`: station NPC ids.
- `Canoe.NO_AXE`, `Canoe.CANT_REACH`: `travel` failure reasons.
- `Canoe.STATION_RANGE`: tiles searched for a station or keeper.
- `Canoe.STEP_TIMEOUT_MS`, `Canoe.SETTLED_MS`, `Canoe.TRIP_TIMEOUT_MS`, `Canoe.OPEN_TIMEOUT_MS`, `Canoe.HOVER_TIMEOUT_MS`: wait lengths.

## Canoe.kind_for_level

Definition:
```luau
function Canoe.kind_for_level(level: number?): Kind
```
The cheapest canoe whose level is at least `level`; the Waka when `level` is nil or above every canoe.

Example:
```luau
local Canoe = require("@lib/main/interfaces/mainscreen/canoe")

print(Canoe.kind_for_level(27)) -- Dugout
```

## Canoe.station

Definition:
```luau
function Canoe.station(): Loc?
```
The nearest known canoe station within `STATION_RANGE`, or nil.

Example:
```luau
local Canoe = require("@lib/main/interfaces/mainscreen/canoe")

local station = Canoe.station()
print(station and station.id)
```

## Canoe.stage

Definition:
```luau
function Canoe.stage(): Stage?
```
`"chop"`, `"shape"`, `"float"` or `"paddle"`: the nearest station's next step, read by hovering it (it must be on screen). Nil when there's no station or no matching menu entry.

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
Runs the nearby station from its current step to a trip to `place` (a `Canoe.PLACES` key), shaping `kind` (default Waka) if needed. An existing canoe is used as is, so it may be too small (`CANT_REACH`). The trip is a ~20 s cutscene during which the player's tile jumps away. True once landed; otherwise false and a reason.

Example:
```luau
local Canoe = require("@lib/main/interfaces/mainscreen/canoe")

local ok, why = Canoe.travel("The Clock Tower", Canoe.Kind.Log)
print(ok, why)
```

## Canoe.keeper

Definition:
```luau
function Canoe.keeper(): Npc?
```
The nearest station NPC within `STATION_RANGE`, or nil.

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
Clicks "Store-axe" on the nearest keeper, which stores the held axe or returns the kept one, then continues the reply. False when no keeper is near or no reply appears within `OPEN_TIMEOUT_MS`.

Example:
```luau
local Canoe = require("@lib/main/interfaces/mainscreen/canoe")

print(Canoe.swap_axe())
```
