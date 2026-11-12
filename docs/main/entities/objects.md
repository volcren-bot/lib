# Main.Entities.Objects

Finding and interacting with world objects ("locs"): trees, rocks, doors, booths, stairs. A `Loc` has `id`, `name` (may be nil), south-west world tile `x`, `y`, `size_x`, `size_y`, scene `scene_x`, `scene_y`, `kind` and `clickable`. Names match case-insensitively with colour tags stripped.

```luau
local Objects = require("@lib/main/entities/objects")
```

## Constants

Definition:

```luau
Objects.WALL = 0
Objects.WALL_DECORATION = 1
Objects.GAME_OBJECT = 2
Objects.GROUND_DECORATION = 3
```

Values of `loc.kind`.

Example:

```luau
if loc.kind == Objects.WALL then
	print("a wall or door")
end
```

## Objects.distance

Definition:

```luau
function Objects.distance(loc: Loc, from: Tile): number
```

Chebyshev tile distance from `from` to the nearest tile the object covers.

Example:

```luau
print(Objects.distance(tree, assert(Walker.position())))
```

## Objects.find

Definition:

```luau
function Objects.find(what: (string | number)?): { Loc }?
```

Clickable objects only, optionally matching a name or id. Nil when unreadable.

Example:

```luau
for _, loc in Objects.find("Bank booth") or {} do
	print(loc.x, loc.y)
end
```

## Objects.nearest

Definition:

```luau
function Objects.nearest(what: (string | number)?, from: Tile): Loc?
```

The matching clickable object closest to `from`, or nil.

Example:

```luau
local tree = Objects.nearest("Tree", assert(Walker.position()))
```

## Objects.model

Definition:

```luau
function Objects.model(loc: Loc): NpcModel?
```

The object's model as drawn now, or nil.

Example:

```luau
local model = Objects.model(tree)
```

## Objects.clickbox

Definition:

```luau
function Objects.clickbox(loc: Loc): Clickbox?
```

The on-screen [Clickbox](../clickbox.md) of the object, or nil when not drawn.

Example:

```luau
local box = Objects.clickbox(tree)
if box then
	Clickbox.draw(box)
end
```

## Objects.owns

Definition:

```luau
function Objects.owns(loc: Loc, entry: MenuEntry): boolean
```

Whether a menu entry is a loc entry for this object's id. The menu doesn't carry the tile, so same-id objects elsewhere also match.

Example:

```luau
for _, entry in Host.menu() or {} do
	print(entry.option, Objects.owns(tree, entry))
end
```

## Objects.hovered

Definition:

```luau
function Objects.hovered(loc: Loc): boolean
```

Whether the current menu lists this object, i.e. the mouse is on it.

Example:

```luau
print(Objects.hovered(tree))
```

## Objects.hover

Definition:

```luau
function Objects.hover(loc: Loc): boolean
```

Moves the mouse onto the object until the menu lists it. Turns and zooms the camera first if it's nearby but off screen.

Example:

```luau
Objects.hover(tree)
```

## Objects.hover_async

Definition:

```luau
function Objects.hover_async(loc: Loc, at: Tile?): boolean
```

Queues a move onto the object and returns at once, without turning the camera. Pass `at`, the tile you'll stand on when clicking, to aim at where the object will be drawn after a walk. False when there's nothing on screen to aim at.

Example:

```luau
Objects.hover_async(door)
```

## Objects.click

Definition:

```luau
function Objects.click(loc: Loc, button: Mouse.Button?, spam: number?): boolean
```

Hovers and clicks the object (left by default). `spam` is the chance of extra clicks, see [Interact.spam_click](../interact.md#interactspam_click).

Example:

```luau
Objects.click(tree)
```

## Objects.interact

Definition:

```luau
function Objects.interact(
	loc: Loc,
	option: string | { string },
	walk_timeout_ms: (number | false)?,
	face: boolean?,
	spam: number?
): boolean
```

Picks `option` (or the first available of a list) on the object, retrying on a misclick and waiting for the walk it caused; `false` skips that wait. May turn the camera towards it first; `face = false` leaves the camera alone. `spam` as in `click`.

Example:

```luau
Objects.interact(tree, "Chop down")
```

## Objects.projected

Definition:

```luau
function Objects.projected(loc: Loc, at: Tile): Clickbox?
```

The cuboid over the object's footprint (`Projection.cuboid`) as the camera would show it with the player on `at` (give `at` a `plane` for another floor), or nil.

Example:

```luau
local box = Objects.projected(loc, { x = loc.x, y = loc.y })
```

## Objects.approach

Definition:

```luau
function Objects.approach(loc: Loc, options: string | { string }, opts: Clickbox.Approach?): boolean
```

Walks towards the object and picks the first available of `options`, clicking early once close (see `Clickbox.approach`).

Example:

```luau
Objects.approach(loc, { "Board", "Examine" })
```
