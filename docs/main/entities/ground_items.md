# Main.Entities.GroundItems

Finding and picking up items on the ground. A `GroundItem` has `id`, `quantity`, `name` (may be nil), world `x`, `y`, `plane`, and scene `scene_x`, `scene_y`. A tile draws its top three items as one pile; the mouse points at the pile and the menu lists each item in it.

```luau
local GroundItems = require("@lib/main/entities/ground_items")
```

## Constants

Definition:

```luau
GroundItems.ITEM_PILE = 4
GroundItems.PILE_HEIGHT = 40
GroundItems.PILE_TAKE_MS = 2400
GroundItems.PILE_WALK_TILE_MS = 600
GroundItems.PILE_REACTION_MS = { 60, 250 }
GroundItems.PILE_ATTEMPTS = 3
```

`ITEM_PILE`: the loc model kind of a pile. `PILE_HEIGHT`: height (fine units) aimed at while the pile isn't drawn yet (see `Clickbox.walking`). For `take_pile`: time for a clicked item to leave, plus `PILE_WALK_TILE_MS` per tile away; the low-leaning pause between items; and clicks in a row that may take nothing before giving up.

Example:

```luau
GroundItems.PILE_ATTEMPTS = 5
```

## GroundItems.distance

Definition:

```luau
function GroundItems.distance(item: GroundItem, from: Tile): number
```

Chebyshev tile distance from `from` (diagonals count as one).

Example:

```luau
print(GroundItems.distance(item, assert(Walker.position())))
```

## GroundItems.find

Definition:

```luau
function GroundItems.find(what: (string | number)?): { GroundItem }?
```

All ground items, or those matching an id or a case-insensitive exact name. Nil when unreadable.

Example:

```luau
for _, item in GroundItems.find("Bones") or {} do
	print(item.x, item.y, item.quantity)
end
```

## GroundItems.nearest

Definition:

```luau
function GroundItems.nearest(what: (string | number)?, from: Tile): GroundItem?
```

The matching item closest to `from`, or nil.

Example:

```luau
local bones = GroundItems.nearest("Bones", assert(Walker.position()))
```

## GroundItems.refresh

Definition:

```luau
function GroundItems.refresh(item: GroundItem): GroundItem?
```

The current state of `item` (same id, tile and plane), or nil if gone.

Example:

```luau
local still = GroundItems.refresh(item) ~= nil
```

## GroundItems.model

Definition:

```luau
function GroundItems.model(item: GroundItem): NpcModel?
```

The item's pile model as drawn now, or nil.

Example:

```luau
local model = GroundItems.model(item)
```

## GroundItems.clickbox

Definition:

```luau
function GroundItems.clickbox(item: GroundItem): Clickbox?
```

The on-screen [Clickbox](../clickbox.md) of the item's pile, or nil when not drawn.

Example:

```luau
local box = GroundItems.clickbox(item)
if box then
	Clickbox.draw(box)
end
```

## GroundItems.owns

Definition:

```luau
function GroundItems.owns(item: GroundItem, entry: MenuEntry): boolean
```

Whether a menu entry is a ground-item entry for this item's id. The menu doesn't carry the tile, so the same item elsewhere also matches.

Example:

```luau
for _, entry in Host.menu() or {} do
	print(entry.option, GroundItems.owns(item, entry))
end
```

## GroundItems.hovered

Definition:

```luau
function GroundItems.hovered(item: GroundItem): boolean
```

Whether the current menu lists this item, i.e. the mouse is on it.

Example:

```luau
print(GroundItems.hovered(item))
```

## GroundItems.hover

Definition:

```luau
function GroundItems.hover(item: GroundItem): boolean
```

Moves the mouse onto the pile until the menu lists the item, turning and zooming the camera first if it's nearby but off screen.

Example:

```luau
GroundItems.hover(item)
```

## GroundItems.hover_async

Definition:

```luau
function GroundItems.hover_async(item: GroundItem): boolean
```

Queues the move as async input and returns at once, without turning the camera or checking the menu. False if the item isn't on screen.

Example:

```luau
GroundItems.hover_async(item)
```

## GroundItems.click

Definition:

```luau
function GroundItems.click(item: GroundItem, button: Mouse.Button?, spam: number?): boolean
```

Hovers and clicks the pile (left by default). `spam` is the chance of extra clicks, see [Interact.spam_click](../interact.md#interactspam_click).

Example:

```luau
GroundItems.click(item)
```

## GroundItems.interact

Definition:

```luau
function GroundItems.interact(item: GroundItem, option: string, walk_timeout_ms: (number | false)?, spam: number?): boolean
```

Picks `option` (e.g. `"Take"`) on the item, retrying on a misclick and waiting for the walk if it caused one; `false` skips that wait. `spam` as in `click`.

Example:

```luau
GroundItems.interact(item, "Take")
```

## GroundItems.approach

Definition:

```luau
function GroundItems.approach(item: GroundItem, options: string | { string }, opts: Clickbox.Approach?): boolean
```

Walks towards a distant item and picks the first available of `options`, clicking early once close (see `Clickbox.approach`). Use `interact` for items already on screen.

Example:

```luau
GroundItems.approach(item, "Take")
```

## GroundItems.fits

Definition:

```luau
function GroundItems.fits(item: GroundItem): boolean
```

Whether it can be picked up now: a free inventory slot, or it stacks and a stack is already carried. Stackability is asked of the client once per id.

Example:

```luau
if GroundItems.fits(item) then
	GroundItems.interact(item, "Take")
end
```

## GroundItems.take_pile

Definition:

```luau
function GroundItems.take_pile(tile: Tile): (number, string?)
```

Clears the tile by repeatedly left-clicking its pile, taking whatever the game puts on top, with no right-click menu. Re-hovers only when the top entry isn't Take on a pile item, waits for each item to leave, then pauses `PILE_REACTION_MS`. Returns the count taken and nil when the tile is empty, `"full"` when the top item doesn't `fit`, or `"failed"` when it can't hover, the left click isn't Take, or `PILE_ATTEMPTS` clicks took nothing. For only some items, `interact` each with "Take".

Example:

```luau
local taken, why = GroundItems.take_pile({ x = item.x, y = item.y })
```
