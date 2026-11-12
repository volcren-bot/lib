# Main.Projection.Projection

Projects world positions to screen pixels: tile outlines and ground-standing boxes.

```luau
local Projection = require("@lib/main/projection/projection")
```

Fine coordinates are local to the loaded area, 128 per tile, with negative `z` going up. An `at` tile projects as seen once the player stands there (give it a `plane` field for another floor); a `shift` projects as seen once the camera has moved that many fine units.

## Constants

Definition:
```luau
Projection.TILE = 128
```
Fine units per tile.

## Projection.base

Definition:
```luau
function Projection.base(): Tile?
```
World tile at the loaded area's corner; nil when not logged in.

Example:
```luau
local base = Projection.base()
print(base and `{base.x}, {base.y}`)
```

## Projection.points

Definition:
```luau
function Projection.points(points: { FinePoint }, at: Tile?): { Point }?
```
Screen pixels of fine points, optionally as seen from `at` (via `arrival` and `shifted`).

Example:
```luau
local screen = Projection.points({ { x = 6400, y = 6400, z = 0 } })
print(screen and screen[1].x, screen and screen[1].y)
```

## Projection.tile

Definition:
```luau
function Projection.tile(tile: Tile, height: number?, at: Tile?): Quad?
```
Screen quad of a world tile's corners, raised by `height` fine units, optionally as seen from `at`.

Example:
```luau
local Walker = require("@lib/main/walker")

local quad = Projection.tile(assert(Walker.relative(1, 0)))
print(quad and quad.top.x)
```

## Projection.cuboid

Definition:
```luau
function Projection.cuboid(
	fine_x: number,
	fine_y: number,
	size: number?,
	height: number?,
	at: Tile?,
	shift: FinePoint?
): Cuboid?
```
A ground-standing box centred on the fine point, as `bottom` and `top` quads. `size` in tiles (default 1), `height` in fine units (default 200). `shift`, when given, wins over `at`.

Example:
```luau
local Host = require("@lib/host")

local me = Host.game_state().position
local box = me and Projection.cuboid(me.local_x, me.local_y)
print(box and box.top.top.x)
```

## Projection.bounds

Definition:
```luau
function Projection.bounds(cuboid: Cuboid): Box
```
Smallest screen box enclosing the cuboid.

Example:
```luau
local Host = require("@lib/host")

local me = Host.game_state().position
local cuboid = me and Projection.cuboid(me.local_x, me.local_y)
print(cuboid and Projection.bounds(cuboid).x1)
```

## Projection.box_on_screen

Definition:
```luau
function Projection.box_on_screen(box: Box): boolean
```
Whether the box is fully inside the client.

Example:
```luau
local Geometry = require("@lib/utils/math/geometry")

print(Projection.box_on_screen(Geometry.Box.new(10, 10, 100, 100)))
```

## Projection.on_screen

Definition:
```luau
function Projection.on_screen(quad: Quad): boolean
```
Whether all four corners are inside the client.

Example:
```luau
local Walker = require("@lib/main/walker")

local quad = Projection.tile(assert(Walker.position()))
print(quad and Projection.on_screen(quad))
```

## Projection.arrival

Definition:
```luau
function Projection.arrival(at: Tile): FinePoint?
```
Fine offset the camera focal point moves by once the player stands on `at`. Nil when not logged in.

Example:
```luau
local Walker = require("@lib/main/walker")

local here = assert(Walker.position())
print(Projection.arrival({ x = here.x + 5, y = here.y }))
```

## Projection.shifted

Definition:
```luau
function Projection.shifted(points: { FinePoint }, shift: FinePoint, plane: number?): { Point }?
```
`points` as seen after the camera moves by `shift` (x, y), optionally on `plane`. The camera also follows the ground height under the player while points keep their own. Pair with `Walker.ahead` to predict positions while walking.

Example:
```luau
local Walker = require("@lib/main/walker")

local shift = Walker.ahead(300)
local soon = shift and Projection.shifted({ { x = 6400, y = 6400, z = 0 } }, shift)
print(soon and soon[1].x)
```
