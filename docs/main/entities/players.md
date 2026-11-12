# Main.Entities.Players

Finding and interacting with players. A `PlayerInfo` has `index`, `name`, world `x`, `y` and scene `local_x`, `local_y`. Names match case-insensitively.

```luau
local Players = require("@lib/main/entities/players")
```

## Players.distance

Definition:

```luau
function Players.distance(a: Tile, b: Tile): number
```

Chebyshev tile distance (diagonals count as one).

Example:

```luau
print(Players.distance({ x = 10, y = 10 }, { x = 14, y = 12 })) -- 4
```

## Players.find

Definition:

```luau
function Players.find(name: string?): { PlayerInfo }?
```

All loaded players including yourself, or those named `name`. Nil when unreadable.

Example:

```luau
for _, p in Players.find() or {} do
	print(p.name, p.x, p.y)
end
```

## Players.me

Definition:

```luau
function Players.me(): PlayerInfo?
```

Your own entry in the player list, or nil.

Example:

```luau
local me = Players.me()
```

## Players.nearest

Definition:

```luau
function Players.nearest(from: Tile): PlayerInfo?
```

The other player closest to `from` (never yourself), or nil.

Example:

```luau
local other = Players.nearest(assert(Walker.position()))
```

## Players.refresh

Definition:

```luau
function Players.refresh(player: PlayerInfo): PlayerInfo?
```

The current state of the player with the same `index`, or nil if gone.

Example:

```luau
local now = Players.refresh(other)
```

## Players.model

Definition:

```luau
function Players.model(player: PlayerInfo): NpcModel?
```

The player's model as drawn now, or nil.

Example:

```luau
local model = Players.model(other)
```

## Players.clickbox

Definition:

```luau
function Players.clickbox(player: PlayerInfo): Clickbox?
```

The on-screen [Clickbox](../clickbox.md) of the player, or nil when not drawn.

Example:

```luau
local box = Players.clickbox(other)
if box then
	Clickbox.draw(box)
end
```

## Players.owns

Definition:

```luau
function Players.owns(player: PlayerInfo, entry: MenuEntry): boolean
```

Whether a non-NPC, non-loc menu entry's target starts with the player's name (followed by nothing or a space).

Example:

```luau
for _, entry in Host.menu() or {} do
	print(entry.option, Players.owns(other, entry))
end
```

## Players.hovered

Definition:

```luau
function Players.hovered(player: PlayerInfo): boolean
```

Whether the current menu lists this player, i.e. the mouse is on them.

Example:

```luau
print(Players.hovered(other))
```

## Players.hover

Definition:

```luau
function Players.hover(player: PlayerInfo): boolean
```

Moves the mouse onto the player, re-aiming as they move, until the menu lists them. Turns and zooms the camera first if they're nearby but off screen.

Example:

```luau
Players.hover(other)
```

## Players.hover_async

Definition:

```luau
function Players.hover_async(player: PlayerInfo): boolean
```

Queues the move as async input and returns at once, without turning the camera or checking the menu. False if the player isn't on screen.

Example:

```luau
Players.hover_async(other)
```

## Players.click

Definition:

```luau
function Players.click(player: PlayerInfo, button: Mouse.Button?, spam: number?): boolean
```

Hovers and clicks the player (left by default). `spam` is the chance of extra clicks, see [Interact.spam_click](../interact.md#interactspam_click).

Example:

```luau
Players.click(other)
```

## Players.interact

Definition:

```luau
function Players.interact(player: PlayerInfo, option: string, walk_timeout_ms: (number | false)?, spam: number?): boolean
```

Picks `option` (e.g. `"Trade with"`) on the player, retrying on a misclick and waiting for the walk it caused. `"Follow"` never waits unless `walk_timeout_ms` is given; `false` skips the wait for any option. `spam` as in `click`.

Example:

```luau
Players.interact(other, "Follow")
```
