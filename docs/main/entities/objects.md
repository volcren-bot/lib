# Main.Entities.Objects

Finding and interacting with objects in the world: trees, rocks, doors, bank booths, stairs and so on. The game calls them "locs".

```luau
local Objects = require("../main/entities/objects")
```

An object is a table with `id`, `name` (can be `nil`), `x`, `y` (its south-west tile), `size_x`, `size_y`, `kind` and `clickable`. Names are matched ignoring upper/lower case.

## Constants

Definition:
```luau
Objects.WALL = 0
Objects.WALL_DECORATION = 1
Objects.GAME_OBJECT = 2
Objects.GROUND_DECORATION = 3
```
The values of an object's `kind`: what sort of thing it is.

## Objects.distance

Definition:
```luau
function Objects.distance(loc: Loc, from: Tile): number
```
How many tiles it is from a tile to the nearest tile the object covers. Big objects are measured to their closest edge.

Example:
```luau
local Objects = require("../main/entities/objects")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local tree = Objects.nearest("Tree", me)
print(tree and Objects.distance(tree, me))
```

## Objects.find

Definition:
```luau
function Objects.find(what: (string | number)?): { Loc }?
```
Lists the clickable objects around you. Give a name or an id to only get matching ones.

Example:
```luau
local Objects = require("../main/entities/objects")

for _, loc in ipairs(Objects.find("Bank booth") or {}) do
	print(loc.x, loc.y)
end
```

## Objects.nearest

Definition:
```luau
function Objects.nearest(what: (string | number)?, from: Tile): Loc?
```
The closest matching object to a tile.

Example:
```luau
local Objects = require("../main/entities/objects")
local Walker = require("../main/walker")

local tree = Objects.nearest("Tree", assert(Walker.position()))
print(if tree then `tree at {tree.x}, {tree.y}` else "no tree around")
```

## Objects.model

Definition:
```luau
function Objects.model(loc: Loc): NpcModel?
```
The shape of the object as drawn on screen right now.

Example:
```luau
local Objects = require("../main/entities/objects")
local Walker = require("../main/walker")

local tree = Objects.nearest("Tree", assert(Walker.position()))
local model = tree and Objects.model(tree)
print(model and #model.faces)
```

## Objects.clickbox

Definition:
```luau
function Objects.clickbox(loc: Loc): Clickbox?
```
The area on screen where a click lands on the object. See [Clickbox](../clickbox.md).

Example:
```luau
local Clickbox = require("../main/clickbox")
local Objects = require("../main/entities/objects")
local Walker = require("../main/walker")

local tree = Objects.nearest("Tree", assert(Walker.position()))
local box = tree and Objects.clickbox(tree)
if box then
	Clickbox.draw(box)
end
```

## Objects.owns

Definition:
```luau
function Objects.owns(loc: Loc, entry: MenuEntry): boolean
```
Whether a right-click menu line belongs to this kind of object. The menu doesn't say which tile, so objects with the same id elsewhere count too.

Example:
```luau
local Host = require("../host")
local Objects = require("../main/entities/objects")
local Walker = require("../main/walker")

local tree = Objects.nearest("Tree", assert(Walker.position()))
if tree then
	for _, entry in ipairs(Host.menu() or {}) do
		print(entry.option, Objects.owns(tree, entry))
	end
end
```

## Objects.hovered

Definition:
```luau
function Objects.hovered(loc: Loc): boolean
```
Whether the game currently has the mouse on this object.

Example:
```luau
local Objects = require("../main/entities/objects")
local Walker = require("../main/walker")

local tree = Objects.nearest("Tree", assert(Walker.position()))
if tree then
	print("mouse is on it:", Objects.hovered(tree))
end
```

## Objects.hover

Definition:
```luau
function Objects.hover(loc: Loc): boolean
```
Moves the mouse onto the object until the game confirms it is there. If the object is nearby but off screen, the camera is turned and zoomed out first.

Example:
```luau
local Objects = require("../main/entities/objects")
local Walker = require("../main/walker")

local tree = Objects.nearest("Tree", assert(Walker.position()))
if tree then
	print(Objects.hover(tree))
end
```

## Objects.click

Definition:
```luau
function Objects.click(loc: Loc, button: Mouse.Button?): boolean
```
Hovers the object and clicks it (left button by default).

Example:
```luau
local Objects = require("../main/entities/objects")
local Walker = require("../main/walker")

local tree = Objects.nearest("Tree", assert(Walker.position()))
if tree then
	print(Objects.click(tree))
end
```

## Objects.interact

Definition:
```luau
function Objects.interact(
	loc: Loc,
	option: string | { string },
	walk_timeout_ms: (number | false)?,
	face: boolean?
): boolean
```
Picks an option (such as `"Chop down"` or `"Open"`) on the object. Retries if the wrong thing got clicked, and waits for you to arrive if it made you walk. `false` skips the wait. It may turn the camera toward the object first; `face` false leaves the camera alone, for an object you know is on screen.

Example:
```luau
local Objects = require("../main/entities/objects")
local Walker = require("../main/walker")

local tree = Objects.nearest("Tree", assert(Walker.position()))
if tree then
	local ok = Objects.interact(tree, "Chop down")
	print(ok)
end
```

## Objects.projected

Definition:
```luau
function Objects.projected(loc: Loc, at: Tile): Clickbox?
```
The loc's box as the camera will show it once the player stands on `at` (add a `plane` to `at` when that is another floor): the cuboid over its footprint (see `Projection.cuboid`), since that's all we know of it from there.

Example:
```luau
local Objects = require("../main/entities/objects")
local Walker = require("../main/walker")

local loc = assert(Objects.nearest("Ferry", assert(Walker.position())))
local box = Objects.projected(loc, { x = loc.x, y = loc.y })
```

## Objects.approach

Definition:
```luau
function Objects.approach(loc: Loc, options: string | { string }, opts: Clickbox.Approach?): boolean
```
Walks to the loc and picks the first of `options` its menu has, walking early on the way when it's close (see `Clickbox.approach`).

Example:
```luau
local Objects = require("../main/entities/objects")
local Walker = require("../main/walker")

local loc = assert(Objects.nearest("Ferry", assert(Walker.position())))
local ok = Objects.approach(loc, { "Board", "Examine" })
print(ok)
```
