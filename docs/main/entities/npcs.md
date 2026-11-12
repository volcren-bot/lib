# Main.Entities.Npcs

Finding and interacting with NPCs. An `Npc` has `index`, `id`, `name`, world `x`, `y`, scene `local_x`, `local_y` and `head_icons`. Names match case-insensitively with colour tags stripped. NPCs that transform via a varbit or varp carry their base definition's name, often empty (e.g. Priestess Zul-Gwenwynig, id 2124): find those by id.

```luau
local Npcs = require("@lib/main/entities/npcs")
```

## Constants

Definition:

```luau
Npcs.PRAYER_ICONS = 440
Npcs.PRAYER_SPRITES = { [0] = "melee", [1] = "ranged", [2] = "magic" }
```

The prayer head icon sprite archive (`headicons_prayer`) and the protection prayer each of its first sprites shows.

Example:

```luau
print(Npcs.PRAYER_SPRITES[1])
```

## Npcs.overhead

Definition:

```luau
function Npcs.overhead(npc: Npc): string?
```

The protection prayer the NPC has up, `"melee"`, `"ranged"` or `"magic"`, from `npc.head_icons` (each `{ archive, sprite }`). Nil for none or another prayer icon. Re-read via `refresh` for NPCs that switch prayers.

Example:

```luau
for _, demon in Npcs.find("Tormented Demon") or {} do
	print(demon.index, Npcs.overhead(demon))
end
```

## Npcs.clean_name

Definition:

```luau
function Npcs.clean_name(name: string): string
```

`name` with tags like `<col=00ffff>` removed. `find` and `nearest` already compare this way.

Example:

```luau
print(Npcs.clean_name("<col=00ffff>Spirit pool</col>")) -- "Spirit pool"
```

## Npcs.distance

Definition:

```luau
function Npcs.distance(a: Tile, b: Tile): number
```

Chebyshev tile distance (diagonals count as one).

Example:

```luau
print(Npcs.distance({ x = 3200, y = 3200 }, { x = 3203, y = 3201 })) -- 3
```

## Npcs.find

Definition:

```luau
function Npcs.find(what: (string | number)?): { Npc }?
```

All loaded NPCs, or those matching a name or id. Nil when unreadable.

Example:

```luau
for _, npc in Npcs.find("Man") or {} do
	print(npc.name, npc.x, npc.y)
end
```

## Npcs.nearest

Definition:

```luau
function Npcs.nearest(what: (string | number)?, from: Tile): Npc?
```

The matching NPC closest to `from`, or nil.

Example:

```luau
local npc = Npcs.nearest("Man", assert(Walker.position()))
```

## Npcs.refresh

Definition:

```luau
function Npcs.refresh(npc: Npc): Npc?
```

The current state of the NPC with the same `index`, or nil if gone.

Example:

```luau
local now = Npcs.refresh(npc)
```

## Npcs.model

Definition:

```luau
function Npcs.model(npc: Npc): NpcModel?
```

The NPC's model as drawn now, or nil.

Example:

```luau
local model = Npcs.model(npc)
```

## Npcs.clickbox

Definition:

```luau
function Npcs.clickbox(npc: Npc): Clickbox?
```

The on-screen [Clickbox](../clickbox.md) of the NPC, or nil when not drawn.

Example:

```luau
local box = Npcs.clickbox(npc)
if box then
	Clickbox.draw(box)
end
```

## Npcs.target

Definition:

```luau
function Npcs.target(npc: Npc): Point?
```

A human-like point to click on the NPC (`Clickbox.target`), or nil.

Example:

```luau
local point = Npcs.target(npc)
```

## Npcs.owns

Definition:

```luau
function Npcs.owns(npc: Npc, entry: MenuEntry): boolean
```

Whether a menu entry belongs to this exact NPC (by index, not name).

Example:

```luau
for _, entry in Host.menu() or {} do
	print(entry.option, Npcs.owns(npc, entry))
end
```

## Npcs.hovered

Definition:

```luau
function Npcs.hovered(npc: Npc): boolean
```

Whether the current menu lists this NPC, i.e. the mouse is on it.

Example:

```luau
print(Npcs.hovered(npc))
```

## Npcs.hover

Definition:

```luau
function Npcs.hover(npc: Npc): boolean
```

Moves the mouse onto the NPC, re-aiming as it moves, until the menu lists it. Turns and zooms the camera first if it's nearby but off screen.

Example:

```luau
Npcs.hover(npc)
```

## Npcs.hover_async

Definition:

```luau
function Npcs.hover_async(npc: Npc): boolean
```

Queues the move as async input and returns at once, without turning the camera or checking the menu. False if the NPC isn't on screen.

Example:

```luau
Npcs.hover_async(npc)
```

## Npcs.click

Definition:

```luau
function Npcs.click(npc: Npc, button: Mouse.Button?, spam: number?): boolean
```

Hovers and clicks the NPC (left by default). `spam` is the chance of extra clicks, see [Interact.spam_click](../interact.md#interactspam_click).

Example:

```luau
Npcs.click(npc)
```

## Npcs.interact

Definition:

```luau
function Npcs.interact(npc: Npc, option: string | { string }, walk_timeout_ms: (number | false)?, spam: number?): boolean
```

Picks `option` (or the first available of a list) on this NPC, retrying on a misclick and waiting for the walk it caused; `walk_timeout_ms` changes that wait and `false` skips it. `spam` as in `click`.

Example:

```luau
Npcs.interact(npc, "Talk-to")
```

## Npcs.projected

Definition:

```luau
function Npcs.projected(npc: Npc, at: Tile): Clickbox?
```

The NPC's tile cuboid (`Projection.cuboid`) as the camera would show it with the player on `at`, or nil.

Example:

```luau
local box = Npcs.projected(npc, { x = npc.x, y = npc.y })
```

## Npcs.approach

Definition:

```luau
function Npcs.approach(npc: Npc, options: string | { string }, opts: Clickbox.Approach?): boolean
```

Walks towards the NPC and picks the first available of `options`, clicking early once close (see `Clickbox.approach`).

Example:

```luau
Npcs.approach(npc, { "Talk-to", "Examine" })
```
