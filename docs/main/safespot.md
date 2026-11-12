# Main.SafeSpot

Safe spotting: standing where a melee NPC chasing you can't reach you. It simulates the game's NPC chase over the scene's collision, finds tiles where the NPC gets stuck, and walks you there.

```luau
local SafeSpot = require("@lib/main/safespot")
```

## How NPCs chase you

Each tick a chasing NPC:

1. Attacks without moving if it is next to you north, east, south or west with no wall between.
2. Picks the side of you it is on, comparing its south-west tile with yours and split by the diagonals through your tile; on a diagonal it takes north or south. It heads for the tile next to you on that side.
3. Steps towards it: diagonally if both coordinates differ and it can, else east/west, else north/south, else stays.

NPCs path from their south-west tile; bigger NPCs check every tile their edge steps onto. They don't walk onto other NPCs (players don't block them). So an NPC stops behind an obstacle once it is straight in line with you, or diagonal to you when the tile it would step east or west onto is blocked:

```
0 0 0 0 0
0 0 X 0 0
0 E | E 0
0 0 | 0 0
```

`X` is you, `E` the NPC's south-west tile, `|` the obstacle. Running (2 tiles a tick) usually beats the NPC there; `find` simulates the chase during your walk too.

Not covered: ranged and magic attackers; an NPC lured past its spawn range walks back (`trap` counts that as trapped); auto retaliate walks you out of the spot, so turn it off.

## Types

| Type | What it holds |
| --- | --- |
| `Grid` | Collision `flags` of an area (`x`, `y`, `width`, `height`, `plane`) from `Host.collision`, plus `occupied`: tiles other NPCs stand on, by `"x,y"`. |
| `Chaser` | An NPC's south-west tile `x`, `y`, `size` in tiles and, when read from the game, `index`. |
| `Chase` | `outcome` (`"reached"`, `"stuck"`, `"loop"` or `"far"`), `path` (south-west tiles, start first), `at` (the last) and `touched` (it got next to you while you walked). |
| `Spot` | `tile`, walk `distance`, `chases` with other NPCs standing still, `walls` (the same over walls alone), and `walls_hold` (walls alone hold every NPC). |

## Constants

Definition:
```luau
SafeSpot.FLAG = { WALL_NORTH_WEST = 0x1, WALL_NORTH = 0x2, WALL_NORTH_EAST = 0x4, WALL_EAST = 0x8, WALL_SOUTH_EAST = 0x10, WALL_SOUTH = 0x20, WALL_SOUTH_WEST = 0x40, WALL_WEST = 0x80, BLOCKED = 0x1240100 }
SafeSpot.MAX_STEPS = 64
SafeSpot.RADIUS = 10
SafeSpot.SETTLE_TICKS = 3
SafeSpot.ATTEMPTS = 3
SafeSpot.WALK_TIMEOUT_MS = 10000
SafeSpot.SETTLE_TIMEOUT_MS = 8000
SafeSpot.POLL_MS = 50
SafeSpot.LOCATE_MS = 40
```
- `FLAG`: collision bits of a tile.
- `MAX_STEPS`: chase steps before a chase is `"far"`.
- `RADIUS`: default search radius of `find`.
- `SETTLE_TICKS`, `SETTLE_TIMEOUT_MS`: how long `wait_trapped` needs the NPC still, and gives up after.
- `ATTEMPTS`: default tries of `trap`.
- `WALK_TIMEOUT_MS`: walk timeout of `trap`.
- `POLL_MS`: poll interval of `wait_trapped`.
- `LOCATE_MS`: gap between the two samples `locate` takes.

## SafeSpot.grid

Definition:
```luau
function SafeSpot.grid(area: Host.Corners?): (Grid?, string?)
```
Live collision of your plane in an area of the loaded scene, or all of it. About 2 ms; reuse it while nothing opens or closes.

Example:
```luau
local grid = assert(SafeSpot.grid())
print(`{grid.width}x{grid.height} tiles from {grid.x},{grid.y}`)
```

## SafeSpot.grid_around

Definition:
```luau
function SafeSpot.grid_around(center: Tile, radius: number): (Grid?, string?)
```
The grid `radius` tiles around `center`, padded by `MAX_STEPS / 2` for NPCs walking in from further away.

Example:
```luau
local grid = assert(SafeSpot.grid_around(assert(Walker.position()), 10))
```

## SafeSpot.flags

Definition:
```luau
function SafeSpot.flags(grid: Grid, x: number, y: number): number
```
A tile's collision flags (`SafeSpot.FLAG`); tiles outside the grid have every bit set.

Example:
```luau
local me = assert(Walker.position())
local north = SafeSpot.flags(assert(SafeSpot.grid_around(me, 1)), me.x, me.y + 1)
print(bit32.band(north, SafeSpot.FLAG.WALL_SOUTH) ~= 0)
```

## SafeSpot.size

Definition:
```luau
function SafeSpot.size(npc: Npc): number
```
An NPC's size in tiles from `Host.npc_sizes`, or `guess_size` when it can't be read.

Example:
```luau
local demon = assert(Npcs.nearest("Greater demon", assert(Walker.position())))
print(SafeSpot.size(demon))
```

## SafeSpot.guess_size

Definition:
```luau
function SafeSpot.guess_size(npc: Npc): number
```
2 when the NPC is drawn on a tile corner (even size), else 1. A walking NPC is taken as 1.

Example:
```luau
print(SafeSpot.guess_size(assert(Npcs.nearest("Cow", assert(Walker.position())))))
```

## SafeSpot.occupy

Definition:
```luau
function SafeSpot.occupy(grid: Grid, except: { number }?, sizes: { [string]: number }?): Grid
```
Marks the tiles nearby NPCs stand on in `grid.occupied`, skipping indices in `except`. Sizes come from the game, else `sizes` by name, else are guessed. Valid for a tick or two.

Example:
```luau
local me = assert(Walker.position())
local guard = assert(Npcs.nearest("Guard", me))
local grid = SafeSpot.occupy(assert(SafeSpot.grid_around(me, 10)), { guard.index })
```

## SafeSpot.grid_for

Definition:
```luau
function SafeSpot.grid_for(chasers: { Chaser }, center: Tile, radius: number): (Grid?, string?)
```
`grid_around` plus `occupy`, skipping `chasers`. `find` uses this when no grid is given.

Example:
```luau
local me = assert(Walker.position())
local guard = SafeSpot.chaser(assert(Npcs.nearest("Guard", me)))
print(SafeSpot.is_safe(assert(SafeSpot.grid_for({ guard }, me, 10)), guard, me))
```

## SafeSpot.can_step

Definition:
```luau
function SafeSpot.can_step(grid: Grid, x: number, y: number, dx: number, dy: number, size: number?): boolean
```
Whether something of `size` (default 1) with its south-west tile on `x, y` can step `dx, dy` (each -1, 0 or 1) past walls and objects, as the game checks it. Ignores other NPCs.

Example:
```luau
local me = assert(Walker.position())
print(SafeSpot.can_step(assert(SafeSpot.grid_around(me, 2)), me.x, me.y, 1, 1))
```

## SafeSpot.reached

Definition:
```luau
function SafeSpot.reached(grid: Grid, npc: Chaser, target: Tile): boolean
```
Whether the NPC can melee `target`: adjacent north, east, south or west with no wall between.

Example:
```luau
print(SafeSpot.reached(grid, SafeSpot.chaser(guard), me))
```

## SafeSpot.under

Definition:
```luau
function SafeSpot.under(npc: Chaser, target: Tile): boolean
```
Whether `target` is one of the NPC's tiles. Not safe: it steps off and hits you.

Example:
```luau
print(SafeSpot.under({ x = 3200, y = 3200, size = 2 }, { x = 3201, y = 3201 })) -- true
```

## SafeSpot.destination

Definition:
```luau
function SafeSpot.destination(npc: Chaser, target: Tile): Tile
```
The south-west tile the NPC heads for to hit `target` (step 2 above).

Example:
```luau
local to = SafeSpot.destination({ x = 99, y = 99, size = 1 }, { x = 100, y = 100 })
print(to.x, to.y) -- 100 99
```

## SafeSpot.step

Definition:
```luau
function SafeSpot.step(grid: Grid, npc: Chaser, target: Tile): Tile?
```
The NPC's south-west tile after its next step towards `target`; nil when it reached it or is stuck. `grid.occupied` blocks it.

Example:
```luau
print(SafeSpot.step(grid, { x = me.x + 4, y = me.y - 3, size = 1 }, me))
```

## SafeSpot.chase

Definition:
```luau
function SafeSpot.chase(grid: Grid, npc: Chaser, target: Tile, route: { Tile }?, speed: number?): Chase
```
Simulates the chase to the end, NPC moving first each tick. With `route` you walk it at `speed` tiles a tick (default 1) and end on its last tile; without, you stand on `target`. `"stuck"` and `"loop"` mean it never reaches you, `"far"` that it was still walking after `MAX_STEPS`.

Example:
```luau
local chase = SafeSpot.chase(grid, SafeSpot.chaser(guard), me)
print(chase.outcome, #chase.path - 1)
```

## SafeSpot.is_safe

Definition:
```luau
function SafeSpot.is_safe(grid: Grid, npc: Chaser, target: Tile): boolean
```
Whether the NPC, from where it is, never reaches you standing on `target`.

Example:
```luau
print(SafeSpot.is_safe(grid, SafeSpot.chaser(guard), me))
```

## SafeSpot.chaser

Definition:
```luau
function SafeSpot.chaser(npc: Npc, size: number?, before: Npc?): Chaser
```
The NPC's south-west tile (`size` default 1) from where it is drawn. A walking NPC is drawn between tiles: given its earlier sample `before`, this is the tile it walks to (where the game already has it); without, the nearest tile. `locate` takes both samples.

Example:
```luau
local c = SafeSpot.chaser(assert(Npcs.nearest("Cow", me)), 2)
print(c.x, c.y)
```

## SafeSpot.locate

Definition:
```luau
function SafeSpot.locate(index: number, size: number?): Chaser?
```
The chaser of NPC `index`, sampled twice `SafeSpot.LOCATE_MS` apart to know where it walks to. Nil when it's gone.

Example:
```luau
local c = SafeSpot.locate(guard.index)
```

## SafeSpot.find

Definition:
```luau
function SafeSpot.find(chasers: { Chaser }, options: FindOptions?): ({ Spot }?, string?)
```
Tiles near you where no chaser reaches you, nearest walk first. Each NPC is simulated chasing you while you walk the shortest route there and then stand. A tile counts only if it holds on walls alone and with the other NPCs where they stand now. Fails with `"not logged in"` or a grid error. Options:

- `around`, `radius`: search centre and radius (default you, `RADIUS`).
- `from`: walk start (default you).
- `speed`: tiles a tick (default 2 running, else 1).
- `untouched`: drop tiles where an NPC gets next to you on the way; by default they sort after equally far tiles.
- `exclude`: tiles to skip, by `"x,y"`.
- `npcs_hold`: also accept tiles held only by NPCs in the way (`walls_hold` false); used by [CombatSafeSpot](combat_safespot.md).
- `limit`: maximum spots.
- `grid`: collision to use as is (default `grid_for`).

Example:
```luau
local guards = {}
for _, npc in ipairs(Npcs.find("Guard") or {}) do
	table.insert(guards, SafeSpot.chaser(npc))
end
local spots = assert(SafeSpot.find(guards, { limit = 3 }))
print(spots[1] and spots[1].tile.x)
```

## SafeSpot.wait_trapped

Definition:
```luau
function SafeSpot.wait_trapped(index: number, size: number?, timeout_ms: number?): (Chaser?, string?)
```
Blocks until the NPC has stood on one tile out of reach for `SETTLE_TICKS` ticks (timeout default `SETTLE_TIMEOUT_MS`) and returns it; else nil and why (it reached you, is gone, or kept moving).

Example:
```luau
local at, why = SafeSpot.wait_trapped(guard.index)
```

## SafeSpot.trap

Definition:
```luau
function SafeSpot.trap(index: number, options: TrapOptions?): (Tile?, Chaser? | string)
```
Walks to the best `find` tile (or the first safe one of `options.spots`), makes sure you stand exactly on it, and waits for NPC `index` to settle, retrying from the new position up to `attempts` times. Returns your tile and the NPC's stuck chaser, or nil and why. Options: `size` (default 1), `spots`, `find` (`FindOptions`), `attempts` (default `ATTEMPTS`). Attack the NPC first so it chases you.

Example:
```luau
local tile, how = SafeSpot.trap(frog.index, { size = 2 })
print(tile or how)
```
