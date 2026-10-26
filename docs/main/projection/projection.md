# Main.Projection.Projection

Turning places in the world into places on your screen: the outline of a tile, or a box standing on the ground.

```luau
local Projection = require("../main/projection/projection")
```

## Constants

Definition:
```luau
Projection.TILE = 128
```
The size of one tile in the game's fine coordinates.

## Projection.base

Definition:
```luau
function Projection.base(): Tile?
```
The world tile at the corner of the area the game currently has loaded. Mostly useful internally for converting between world and loaded-area coordinates.

Example:
```luau
local Projection = require("../main/projection/projection")

local base = Projection.base()
print(if base then `{base.x}, {base.y}` else "unavailable")
```

## Projection.points

Definition:
```luau
function Projection.points(points: { FinePoint }): { Point }?
```
Converts points in the loaded area (in fine coordinates, 128 per tile, with a negative `z` going up) into screen pixels.

Example:
```luau
local Projection = require("../main/projection/projection")

local screen = Projection.points({ { x = 6400, y = 6400, z = 0 } })
print(screen and screen[1].x, screen and screen[1].y)
```

## Projection.tile

Definition:
```luau
function Projection.tile(tile: Tile, height: number?): Quad?
```
The four corners on screen of a world tile, as a quad. `height` lifts the quad above the ground.

Example:
```luau
local Projection = require("../main/projection/projection")
local Walker = require("../main/walker")

local quad = Projection.tile(assert(Walker.relative(1, 0)))
print(quad and quad.top.x, quad and quad.top.y)
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
A box standing on the ground, centered on a point, as a bottom and a top quad on screen. `size` is its width in tiles (1 by default) and `height` its height (200 by default). `at` shows it as seen once the player stands on that tile (see `Projection.arrival`), `shift` as seen once the camera has moved that far (see `Projection.shifted`).

Example:
```luau
local Host = require("../host")
local Projection = require("../main/projection/projection")

local state = Host.game_state()
local me = state and state.position
if me then
	local box = Projection.cuboid(me.local_x, me.local_y)
	print(box and box.top.top.x)
end
```

## Projection.bounds

Definition:
```luau
function Projection.bounds(cuboid: Cuboid): Box
```
The smallest rectangle on screen that contains the whole box.

Example:
```luau
local Host = require("../host")
local Projection = require("../main/projection/projection")

local me = (Host.game_state() or {}).position
local cuboid = me and Projection.cuboid(me.local_x, me.local_y)
if cuboid then
	local box = Projection.bounds(cuboid)
	print(box.x1, box.y1, box.x2, box.y2)
end
```

## Projection.box_on_screen

Definition:
```luau
function Projection.box_on_screen(box: Box): boolean
```
Whether a rectangle is fully inside the game window.

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Projection = require("../main/projection/projection")

print(Projection.box_on_screen(Geometry.Box.new(10, 10, 100, 100)))
```

## Projection.on_screen

Definition:
```luau
function Projection.on_screen(quad: Quad): boolean
```
Whether all four corners of a quad are inside the game window.

Example:
```luau
local Projection = require("../main/projection/projection")
local Walker = require("../main/walker")

local quad = Projection.tile(assert(Walker.position()))
print(quad and Projection.on_screen(quad))
```

## Projection.arrival

Definition:
```luau
function Projection.arrival(at: Tile): FinePoint?
```
The fine offset the camera moves by once the player stands on `at` instead of where they are, in the same frame as the points. The camera follows the player's fine position (its focal point), so `Projection.points` with `at` projects the points with the camera moved by this offset (see `Projection.shifted`).

Example:
```luau
local Projection = require("../main/projection/projection")
local Walker = require("../main/walker")

local here = assert(Walker.position())
local shift = Projection.arrival({ x = here.x + 5, y = here.y })
```

## Projection.shifted

Definition:
```luau
function Projection.shifted(points: { FinePoint }, shift: FinePoint): { Point }?
```
Like `Projection.points`, but as the camera will show the points once it has moved by `shift` (fine units, x and y). The camera follows the player, so this is the view after the player walks that far: it also rises and falls with the ground under the player, while the points keep their own ground. Pair it with `Walker.ahead` to see where things will be a moment from now while walking.

Example:
```luau
local Projection = require("../main/projection/projection")
local Walker = require("../main/walker")

local shift = Walker.ahead(300)
local soon = shift and Projection.shifted({ { x = 6400, y = 6400, z = 0 } }, shift)
print(soon and soon[1].x, soon and soon[1].y)
```
