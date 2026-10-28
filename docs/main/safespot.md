# Main.SafeSpot

Safe spotting: standing where an NPC that wants to hit you can't get to you. It works out how an NPC walks at you over the scene's collision, finds the tiles where it gets stuck, and walks you there.

```luau
local SafeSpot = require("../main/safespot")
```

## How NPCs chase you

An NPC chasing you to hit you in melee doesn't plan a route like you do. Every tick:

1. If it is next to you (north, east, south or west, not diagonally) with no wall between, it attacks and doesn't move.
2. It picks the side of you it's on, split by the two diagonals through your tile, comparing its south-west tile with yours: west, north, east or south. On a diagonal it takes the north or south side, so an NPC diagonal to you steps east or west. Its destination is the tile next to you on that side (for a big NPC, where its tiles touch yours).
3. It takes one step towards that tile: diagonally if both coordinates differ and it can, else east or west, else north or south. If none of them can be taken it stays where it is.

Every NPC paths from its south-west tile, whatever its size; a bigger NPC checks every tile its edge steps onto, including the walls between them. NPCs don't walk onto tiles other NPCs stand on (players don't block them).

This is what makes the two common safe spots work:

- **Behind something**: it walks diagonally until it's straight north, east, south or west of you, then straight at you, and stops against whatever is in between.
- **Corners**: diagonal to you with a wall or object on the tile it steps east or west onto, it stays put:

```
0 0 0 0 0
0 0 X 0 0
0 E | E 0
0 0 | 0 0
```

`X` is you, `E` the NPC's south-west tile, `|` the obstacle.

You walk faster than an NPC when running (2 tiles a tick against 1), so you can usually reach a spot before it does. `SafeSpot.find` plays out the chase while you walk there too.

Things this doesn't cover:

- NPCs that attack from range (bows, magic): being out of reach isn't being safe from them.
- An NPC lured past its range from where it spawned stops chasing and walks back. For a safe spot that's as good, and `SafeSpot.trap` takes it as trapped.
- Your character walks back to an NPC that hits it while auto retaliate is on, out of any safe spot: turn it off.

## Types

| Type | What it holds |
| --- | --- |
| `Grid` | The scene's collision flags in an area (from `Host.collision`), plus `occupied`: the tiles other NPCs stand on, by `"x,y"` (see `SafeSpot.occupy`). |
| `Chaser` | An NPC as the pathfinding sees it: south-west tile `x`, `y`, `size` in tiles and, when read from the game, its `index`. |
| `Chase` | How a chase ends: `outcome` (`"reached"`, `"stuck"`, `"loop"` or `"far"`), `path` (every south-west tile, the start first), `at` (the last one) and `touched` (it got next to you while you walked). |
| `Spot` | A safe `tile`, the `distance` you walk to it, the `chases` of the NPCs (with the NPCs around standing still), the same over the walls alone (`walls`) and whether the walls alone hold every NPC (`walls_hold`). |

## SafeSpot.grid

Definition:
```luau
function SafeSpot.grid(area: Host.Corners?): (Grid?, string?)
```
The live collision of your plane in an area of the loaded scene (all of it without one). About 2 ms; read it once and reuse it while nothing opens or closes.

Example:
```luau
local SafeSpot = require("../main/safespot")

local grid = assert(SafeSpot.grid())
print(`{grid.width}x{grid.height} tiles from {grid.x},{grid.y}`)
```

## SafeSpot.grid_around

Definition:
```luau
function SafeSpot.grid_around(center: Tile, radius: number): (Grid?, string?)
```
The grid `radius` tiles around a tile, with room around it for NPCs walking in from further away.

Example:
```luau
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local grid = assert(SafeSpot.grid_around(assert(Walker.position()), 10))
print(grid.x, grid.y)
```

## SafeSpot.flags

Definition:
```luau
function SafeSpot.flags(grid: Grid, x: number, y: number): number
```
A tile's collision flags (`SafeSpot.FLAG`); a tile outside the grid has them all.

Example:
```luau
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local grid = assert(SafeSpot.grid_around(me, 1))
local north = SafeSpot.flags(grid, me.x, me.y + 1)
print("wall to the north:", bit32.band(north, SafeSpot.FLAG.WALL_SOUTH) ~= 0)
```

## SafeSpot.size

Definition:
```luau
function SafeSpot.size(npc: Npc): number
```
An NPC's size in tiles as the game has it (`Host.npc_sizes`), or guessed with `guess_size` when it can't be read.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local demon = assert(Npcs.nearest("Greater demon", assert(Walker.position())))
local c = SafeSpot.chaser(demon, SafeSpot.size(demon))
print(`a {c.size}x{c.size} with its south-west tile on {c.x},{c.y}`)
```

## SafeSpot.guess_size

Definition:
```luau
function SafeSpot.guess_size(npc: Npc): number
```
An NPC's size when you don't know it: 2 when it stands drawn on a tile corner (an even size), else 1. A walking NPC can't be told and is taken as 1. Pass the size yourself when you know it.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local SafeSpot = require("../main/safespot")

for _, npc in ipairs(Npcs.find("Cow") or {}) do
	print(npc.index, SafeSpot.guess_size(npc))
end
```

## SafeSpot.occupy

Definition:
```luau
function SafeSpot.occupy(grid: Grid, except: { number }?, sizes: { [string]: number }?): Grid
```
Marks the tiles the NPCs around stand on in `grid.occupied`, leaving out the NPCs whose indices are in `except` (the ones you're working out). Sizes come from the game, else from `sizes` (by name), else they're guessed. NPCs walk on, so this is right for a tick or two.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local guard = assert(Npcs.nearest("Guard", me))
local grid = SafeSpot.occupy(assert(SafeSpot.grid_around(me, 10)), { guard.index })
local next_tile = SafeSpot.step(grid, SafeSpot.chaser(guard), me)
print(if next_tile then `it steps to {next_tile.x},{next_tile.y}` else "it stays")
```

## SafeSpot.can_step

Definition:
```luau
function SafeSpot.can_step(grid: Grid, x: number, y: number, dx: number, dy: number, size: number?): boolean
```
Whether something of `size` (1 by default) with its south-west tile on `x, y` can take a step of `dx, dy` (each -1, 0 or 1) past the walls and objects, the way the game checks it. Other NPCs aren't looked at.

Example:
```luau
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local grid = assert(SafeSpot.grid_around(me, 2))
print("north-east is open:", SafeSpot.can_step(grid, me.x, me.y, 1, 1))
```

## SafeSpot.reached

Definition:
```luau
function SafeSpot.reached(grid: Grid, npc: Chaser, target: Tile): boolean
```
Whether the NPC can hit `target` in melee: next to it north, east, south or west, with no wall between.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local guard = assert(Npcs.nearest("Guard", me))
print(SafeSpot.reached(assert(SafeSpot.grid_around(me, 2)), SafeSpot.chaser(guard), me))
```

## SafeSpot.under

Definition:
```luau
function SafeSpot.under(npc: Chaser, target: Tile): boolean
```
Whether `target` is one of the NPC's tiles. Standing under an NPC isn't safe: it steps off and hits you.

Example:
```luau
local SafeSpot = require("../main/safespot")

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
local SafeSpot = require("../main/safespot")

-- diagonal to you, south-west: it goes for the tile south of you
local to = SafeSpot.destination({ x = 99, y = 99, size = 1 }, { x = 100, y = 100 })
print(to.x, to.y) -- 100 99
```

## SafeSpot.step

Definition:
```luau
function SafeSpot.step(grid: Grid, npc: Chaser, target: Tile): Tile?
```
The NPC's south-west tile after its next step chasing `target`, or `nil` when it doesn't move: it reached it, or it is stuck. NPCs in `grid.occupied` block it.

Example:
```luau
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local grid = assert(SafeSpot.grid_around(me, 10))
local npc = { x = me.x + 4, y = me.y - 3, size = 1 }
print(SafeSpot.step(grid, npc, me))
```

## SafeSpot.chase

Definition:
```luau
function SafeSpot.chase(grid: Grid, npc: Chaser, target: Tile, route: { Tile }?, speed: number?): Chase
```
Plays out the NPC chasing you to the end, one step a tick. Without `route` you stand on `target`; with one you walk it first (you first, `speed` tiles a tick, 1 by default) and stand on its last tile. The NPC moves first in a tick. `"stuck"` and `"loop"` mean it never reaches you, `"far"` that it was still walking after `SafeSpot.MAX_STEPS`.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local guard = assert(Npcs.nearest("Guard", me))
local chase = SafeSpot.chase(assert(SafeSpot.grid_around(me, 10)), SafeSpot.chaser(guard), me)
print(chase.outcome, `ends on {chase.at.x},{chase.at.y} after {#chase.path - 1} steps`)
```

## SafeSpot.is_safe

Definition:
```luau
function SafeSpot.is_safe(grid: Grid, npc: Chaser, target: Tile): boolean
```
Whether the NPC, from where it is, can never reach you standing on `target`.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local guard = assert(Npcs.nearest("Guard", me))
print(SafeSpot.is_safe(assert(SafeSpot.grid_around(me, 10)), SafeSpot.chaser(guard), me))
```

## SafeSpot.chaser

Definition:
```luau
function SafeSpot.chaser(npc: Npc, size: number?, before: Npc?): Chaser
```
The NPC's south-west tile (`size` 1 by default), from where it's drawn. While it walks it's drawn between tiles: with how it was drawn a moment `before`, it's the tile it walks to, which is where the game already has it; without, the nearest tile. `SafeSpot.locate` does the two looks for you.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local cow = assert(Npcs.nearest("Cow", assert(Walker.position())))
local c = SafeSpot.chaser(cow, 2)
print(`south-west tile {c.x},{c.y}`)
```

## SafeSpot.locate

Definition:
```luau
function SafeSpot.locate(index: number, size: number?): Chaser?
```
The chaser of the NPC with `index`, looked at twice `SafeSpot.LOCATE_MS` apart to know where it is walking to. `nil` when it's gone.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local guard = assert(Npcs.nearest("Guard", assert(Walker.position())))
local c = SafeSpot.locate(guard.index)
print(c and c.x, c and c.y)
```

## SafeSpot.find

Definition:
```luau
function SafeSpot.find(chasers: { Chaser }, options: FindOptions?): ({ Spot }?, string?)
```
The tiles around you where none of `chasers` can reach you, nearest walk first. Each NPC is played out chasing you from where it is while you walk to the tile (the shortest walk, 2 tiles a tick when running) and then while you stand there. A tile only counts when the NPC gets stuck on the walls alone *and* with the other NPCs standing where they are now: they may walk off, so a spot never relies on them. Options:

- `around`, `radius`: where to look (default you, `SafeSpot.RADIUS` tiles).
- `from`: where you start walking (default you).
- `speed`: tiles you walk a tick (default 2 running, else 1).
- `untouched`: `true` drops tiles an NPC gets next to you on the way to (one hit). By default they come after the others as far away.
- `exclude`: tiles not to stand on, by `"x,y"`.
- `npcs_hold`: `true` also takes tiles where only the NPCs standing in the way stop it (`walls_hold` is false on those). Off by default, since they may walk off; `CombatSafeSpot` uses it.
- `limit`: the most spots returned.
- `grid`: the collision to use, as is (default: read, with the other NPCs in `occupied`).

Example:
```luau
local Npcs = require("../main/entities/npcs")
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local guards = {}
for _, npc in ipairs(Npcs.find("Guard") or {}) do
	if Npcs.distance(npc, me) <= 12 then
		table.insert(guards, SafeSpot.chaser(npc))
	end
end
-- safe from every guard around
local spots = assert(SafeSpot.find(guards, { limit = 3 }))
for _, spot in ipairs(spots) do
	print(`{spot.tile.x},{spot.tile.y}, {spot.distance} tiles away`)
end
```

## SafeSpot.wait_trapped

Definition:
```luau
function SafeSpot.wait_trapped(index: number, size: number?, timeout_ms: number?): (Chaser?, string?)
```
Waits until the NPC has stood on one tile out of your reach for `SafeSpot.SETTLE_TICKS` ticks (up to `SafeSpot.SETTLE_TIMEOUT_MS`), and returns where. Otherwise `nil` and why: it reached you, it's gone, or it kept moving.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local guard = assert(Npcs.nearest("Guard", assert(Walker.position())))
local at, why = SafeSpot.wait_trapped(guard.index)
print(if at then `stuck on {at.x},{at.y}` else why)
```

## SafeSpot.trap

Definition:
```luau
function SafeSpot.trap(index: number, options: TrapOptions?): (Tile?, Chaser? | string)
```
Gets the NPC with `index` stuck where it can't hit you: walks to the best tile `SafeSpot.find` gives (or the first safe one of `options.spots`), makes sure you stand on that exact tile, and waits for the NPC to settle. When it still reaches you it tries again from where it is, up to `SafeSpot.ATTEMPTS` times. Returns your tile and where the NPC is stuck, or `nil` and why not. Options: `size` (the NPC's, default 1), `spots`, `find` (`FindOptions`), `attempts`.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local frog = assert(Npcs.nearest("Giant frog", assert(Walker.position())))
-- a giant frog is 2x2; attack it first, so it chases you
local tile, how = SafeSpot.trap(frog.index, { size = 2 })
if tile then
	print(`safe on {tile.x},{tile.y}, it's stuck on {(how :: SafeSpot.Chaser).x},{(how :: SafeSpot.Chaser).y}`)
else
	print("not trapped:", how)
end
```
