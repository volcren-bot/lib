# Main.Transports

## Transports.add

Definition:
```luau
function Transports.add(transport: Transport)
```
Registers a ladder, staircase or other object that takes you somewhere else. `from` is the tile you stand on to use it and `to` where you end up; `option` is the menu option and `name` the object's name or id. Nothing is registered by default: the walker only knows the transports you add.

Example:
```luau
local Transports = require("../main/transports")

Transports.add({
	name = "Ladder",
	option = "Climb-up",
	from = { x = 3209, y = 3214, plane = 0 },
	to = { x = 3209, y = 3216, plane = 1 },
})
```

## Transports.add_two_way

Definition:
```luau
function Transports.add_two_way(name: string | number, lower: Location, upper: Location, up: string, down: string)
```
Registers both directions of a ladder or staircase: `up` from `lower` to `upper`, and `down` back. A staircase between two middle planes needs two of these, one per flight.

Example:
```luau
local Transports = require("../main/transports")

Transports.add_two_way(
	"Staircase",
	{ x = 3205, y = 3209, plane = 0 },
	{ x = 3205, y = 3209, plane = 1 },
	"Climb-up",
	"Climb-down"
)
```

## Transports.all

Definition:
```luau
function Transports.all(): { Transport }
```
A copy of the registered transports.

Example:
```luau
local Transports = require("../main/transports")

print(#Transports.all())
```

## Transports.clear

Definition:
```luau
function Transports.clear()
```
Removes every registered transport.

Example:
```luau
local Transports = require("../main/transports")

Transports.clear()
```

## Transports.discover

Definition:
```luau
function Transports.discover(area: Host.Corners): number
```
Registers the staircases and ladders of the game cache inside an area, loaded or not (`Host.cache_locs`): every object with a "Climb-up" or "Climb-down" option, paired with the closest one (up to `Transports.PAIR_RADIUS` tiles away) on the plane it leads to that has the opposite option. The tiles to use each from and where it lands are the standable ones around the objects, so where it lands is a guess, which is enough because a walk plans again from where it ends up. Ones found before are not added again. Returns how many were added.

Example:
```luau
local Transports = require("../main/transports")
local Walker = require("../main/walker")

local me = assert(Walker.position())
print(Transports.discover({ x1 = me.x - 40, y1 = me.y - 40, x2 = me.x + 40, y2 = me.y + 40 }))
```

## Transports.discover_around

Definition:
```luau
function Transports.discover_around(a: Location, b: Location): number
```
Registers the transports around two tiles and between them (`Transports.DISCOVER_MARGIN` tiles around), or just around each when that is more than a few map squares. `PlaneWalker.walk` does it before planning.

Example:
```luau
local Transports = require("../main/transports")

print(Transports.discover_around({ x = 1619, y = 3678, plane = 0 }, { x = 1615, y = 3683, plane = 2 }))
```

## Transports.plan

Definition:
```luau
function Transports.plan(from: Location, to: Location): Plan?
```
Plans the cheapest way between two tiles that may be on different planes. It picks the transports to use, in order, by walking distance (`Host.find_path`) between them, so the closest ladder that leads towards the destination wins, and planes in between are crossed by walking from the arrival of one transport to the next. Returns `nil` when there is no way. The plan has the transports and the tile to use each from; walking to each is implied. The walks are priced by the cache's world path, which takes closed doors for walls: when that finds no way, it plans again pricing such walks by their distance instead.

Example:
```luau
local Transports = require("../main/transports")

local plan = Transports.plan({ x = 3200, y = 3200, plane = 0 }, { x = 3210, y = 3210, plane = 2 })
print(if plan then `{#plan.transports} transports, about {plan.cost} tiles` else "no way")
```

## Transports.discover_doors

Definition:
```luau
function Transports.discover_doors(area: Host.Corners): number
```
Registers the doors of the game cache inside an area, loaded or not, as ways between the two tiles beside them, one for each direction. The cache has every door closed, which is how the planner takes them: a route can go through one. Whether it really is closed is read when the walk gets there (`PlaneWalker.cross`). `Transports.discover_around` does this too. Returns how many doors were added.

Example:
```luau
local Transports = require("../main/transports")
local Walker = require("../main/walker")

local me = assert(Walker.position())
print(Transports.discover_doors({ x1 = me.x - 30, y1 = me.y - 30, x2 = me.x + 30, y2 = me.y + 30 }))
```
