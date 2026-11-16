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

Whether a menu entry is a loc entry for this object: same id and the entry's `x`, `y` on its origin tile, so same-id objects on other tiles don't match.

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
	spam: number?,
	menu: boolean?
): boolean
```

Picks `option` (or the first available of a list) on the object, retrying on a misclick and waiting for the walk it caused; `false` skips that wait. May turn the camera towards it first; `face = false` leaves the camera alone. `spam` as in `click`. `menu = true` always picks the option from the right-click menu, even when it is the left-click one, for an object something else (a wandering character) may step in front of between the hover and the click.

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

## Objects.stand_tiles

Definition:

```luau
function Objects.stand_tiles(loc: Loc): { Tile }?
```

The walkable tiles beside an object's footprint (north, south, east and west of it) with no wall between them and the object, read from live collision: where a player can stand to use it. A ground decoration (a trapdoor, say) also counts its own tiles when they are walkable. Nil for walls and wall decorations, whose reach works differently, and for an object on another plane.

Example:

```luau
for _, t in ipairs(Objects.stand_tiles(loc) or {}) do
	print(t.x, t.y)
end
```

## Objects.plain_walk

Definition:

```luau
function Objects.plain_walk(loc: Loc): boolean
```

Whether one click on the object walks all the way to it: one of its `stand_tiles` (the `Clickbox.STAND_CANDIDATES` nearest) is reached with no door, climb or shortcut (`Walker.plain_walk`). A tile next to the object across a wall doesn't count. For objects without stand tiles it is `Walker.plain_walk` to within 1 tile of the object.

Example:

```luau
if Objects.plain_walk(loc) then
	Objects.interact(loc, "Cook")
end
```

## Objects.approach

Definition:

```luau
function Objects.approach(loc: Loc, options: string | { string }, opts: Clickbox.Approach?): boolean
```

Walks towards the object and picks the first available of `options`, clicking early once close (see `Clickbox.approach`). Unless `opts.stand` is given, it passes `Objects.stand_tiles(loc)`, so a game object or ground decoration behind a wall or a counter is walked round to, through doors.

Example:

```luau
Objects.approach(loc, { "Board", "Examine" })
```
