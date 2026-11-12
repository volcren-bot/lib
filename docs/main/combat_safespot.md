# Main.CombatSafeSpot

Safe spots for melee monsters: tiles where the monster chases you, gets stuck where it can't hit you, and stays where you can hit it with a bow, crossbow or spell. Built on [SafeSpot](safespot.md); read its "How NPCs chase you" first.

```luau
local CombatSafeSpot = require("@lib/main/combat_safespot")
```

A monster gets stuck behind walls and blocking objects (projectiles still fly over water and low objects), at the mouth of a corridor too narrow for its size, or behind other monsters while they stay put. Melee monsters only. Turn auto retaliate off first, or your character walks to whatever hits it.

## Constants

Definition:
```luau
CombatSafeSpot.FLAG = { SIGHT_NORTH = 0x400, SIGHT_EAST = 0x1000, SIGHT_SOUTH = 0x4000, SIGHT_WEST = 0x10000, SIGHT_FULL = 0x20000 }
CombatSafeSpot.WORN = 94
CombatSafeSpot.WEAPON_SLOT = 3
CombatSafeSpot.RANGE_PARAM = 13
CombatSafeSpot.STYLE_VARP = 43
CombatSafeSpot.LONGRANGE_STYLE = 3
CombatSafeSpot.LONGRANGE_BONUS = 2
CombatSafeSpot.MAX_RANGE = 10
CombatSafeSpot.AVOID_RADIUS = 16
CombatSafeSpot.ATTACK_TICKS = 3
CombatSafeSpot.ENGAGE_TICKS = 15
CombatSafeSpot.GONE_READS = 2
CombatSafeSpot.FIGHT_TIMEOUT_MS = 10 * 60 * 1000
CombatSafeSpot.REPOSITIONS = 6
```
- `FLAG`: collision flags that block projectiles.
- `WORN`, `WEAPON_SLOT`, `RANGE_PARAM`: equipment container, weapon slot and the item param holding attack range.
- `STYLE_VARP`, `LONGRANGE_STYLE`, `LONGRANGE_BONUS`, `MAX_RANGE`: longrange adds 2, capped at 10.
- `AVOID_RADIUS`: how far `chasers` looks.
- `ATTACK_TICKS`: ticks between re-clicking attack. `ENGAGE_TICKS`: how long `fight` waits on a spot for the monster to come in range.
- `GONE_READS`: missing reads before the monster counts as dead. `FIGHT_TIMEOUT_MS`: default fight limit. `REPOSITIONS`: most spot changes per fight.

## Types

| Type | What it holds |
| --- | --- |
| `CombatSpot` | `tile` to stand on, walk `distance`, where the monster ends up stuck (`at` with nearby NPCs standing still; `at_walls` from walls alone, nil when only NPCs hold it), `gap` to it, and the source `SafeSpot.Spot` (`spot`). |
| `CombatFindOptions` | Options for `find`. |
| `FightOptions` | Options for `fight`. |

## CombatSafeSpot.line_of_sight

Definition:
```luau
function CombatSafeSpot.line_of_sight(grid: SafeSpot.Grid, from: Tile, to: Tile): boolean
```
The game's projectile line-of-sight check: blocked by walls and projectile-blocking objects, not by NPCs or players.

Example:
```luau
local CombatSafeSpot = require("@lib/main/combat_safespot")
local SafeSpot = require("@lib/main/safespot")
local Walker = require("@lib/main/walker")

local me = assert(Walker.position())
local grid = assert(SafeSpot.grid_around(me, 10))
print(CombatSafeSpot.line_of_sight(grid, me, { x = me.x + 6, y = me.y + 2 }))
```

## CombatSafeSpot.nearest_tile

Definition:
```luau
function CombatSafeSpot.nearest_tile(npc: SafeSpot.Chaser, me: Tile): Tile
```
The NPC's tile nearest to `me`, which ranges and line of sight are measured to.

Example:
```luau
local CombatSafeSpot = require("@lib/main/combat_safespot")

local t = CombatSafeSpot.nearest_tile({ x = 100, y = 100, size = 3 }, { x = 105, y = 101 })
print(t.x, t.y) -- 102 101
```

## CombatSafeSpot.distance

Definition:
```luau
function CombatSafeSpot.distance(npc: SafeSpot.Chaser, me: Tile): number
```
Chebyshev distance from `me` to the NPC's nearest tile, as attack range counts it.

Example:
```luau
local CombatSafeSpot = require("@lib/main/combat_safespot")

print(CombatSafeSpot.distance({ x = 100, y = 100, size = 3 }, { x = 105, y = 101 })) -- 3
```

## CombatSafeSpot.can_attack

Definition:
```luau
function CombatSafeSpot.can_attack(grid: SafeSpot.Grid, me: Tile, npc: SafeSpot.Chaser, range: number): boolean
```
Whether `me` is within `range`, in line of sight, and not under the NPC. If false, clicking Attack walks you towards it.

Example:
```luau
local CombatSafeSpot = require("@lib/main/combat_safespot")
local Npcs = require("@lib/main/entities/npcs")
local SafeSpot = require("@lib/main/safespot")
local Walker = require("@lib/main/walker")

local me = assert(Walker.position())
local demon = assert(Npcs.nearest("Greater demon", me))
local grid = assert(SafeSpot.grid_around(me, 10))
print(CombatSafeSpot.can_attack(grid, me, SafeSpot.chaser(demon, SafeSpot.size(demon)), 7))
```

## CombatSafeSpot.weapon_range

Definition:
```luau
function CombatSafeSpot.weapon_range(): number?
```
The worn weapon's `RANGE_PARAM`, plus `LONGRANGE_BONUS` on longrange, capped at `MAX_RANGE`; 1 unarmed, nil when unreadable. Ignores spells: pass `range = 10` when casting.

Example:
```luau
local CombatSafeSpot = require("@lib/main/combat_safespot")

print("range:", CombatSafeSpot.weapon_range())
```

## CombatSafeSpot.find

Definition:
```luau
function CombatSafeSpot.find(target: SafeSpot.Chaser, options: CombatFindOptions?): ({ CombatSpot }?, string?)
```
Tiles where `target`, chasing you (as in `SafeSpot.find`), gets stuck at least `min_gap` away and hittable, and `others` can't reach you. Stuck positions assume nearby NPCs stay put; when walls alone also hold it, it must be hittable there too. Wall-held spots first, then by walk distance. Nil and why when the range or position can't be read.

- `range` (default `weapon_range()`), `min_gap` (default 2).
- `others`: extra chasers to avoid (see `chasers`).
- `npcs_hold`: false keeps only wall-held spots (default true).
- `attack_now`: also require it to be hittable where it stands now.
- `around`, `radius` (default range + 4), `from`, `speed`, `untouched`, `exclude`, `limit`, `grid`: as for `SafeSpot.find`.

Example:
```luau
local CombatSafeSpot = require("@lib/main/combat_safespot")
local SafeSpot = require("@lib/main/safespot")
local Walker = require("@lib/main/walker")

local demon = assert(CombatSafeSpot.free_target("Black demon"))
local target = SafeSpot.chaser(demon, SafeSpot.size(demon))
local spots = assert(CombatSafeSpot.find(target, { limit = 3 }))
for _, s in ipairs(spots) do
	print(`{s.tile.x},{s.tile.y}: it stops on {s.at.x},{s.at.y}, {s.gap} tiles off`)
end
```

## CombatSafeSpot.chasers

Definition:
```luau
function CombatSafeSpot.chasers(names: { string }, center: Tile, except: number?): { SafeSpot.Chaser }
```
NPCs named one of `names` (any case) within `AVOID_RADIUS` of `center`, as sized chasers, excluding index `except`. Pass as `others`.

Example:
```luau
local CombatSafeSpot = require("@lib/main/combat_safespot")
local Walker = require("@lib/main/walker")

local around = CombatSafeSpot.chasers({ "Lesser demon", "Black demon" }, assert(Walker.position()))
print(#around, "demons around")
```

## CombatSafeSpot.fought_by

Definition:
```luau
function CombatSafeSpot.fought_by(index: number): string?
```
The name of another player targeting NPC `index`, or nil.

Example:
```luau
local CombatSafeSpot = require("@lib/main/combat_safespot")
local Npcs = require("@lib/main/entities/npcs")
local Walker = require("@lib/main/walker")

local demon = assert(Npcs.nearest("Greater demon", assert(Walker.position())))
print(CombatSafeSpot.fought_by(demon.index) or "free")
```

## CombatSafeSpot.free_target

Definition:
```luau
function CombatSafeSpot.free_target(name: string, from: Tile?): Npc?
```
The nearest NPC named `name` (any case) to `from` (default you) that no other player is fighting; nil when none.

Example:
```luau
local CombatSafeSpot = require("@lib/main/combat_safespot")

local demon = CombatSafeSpot.free_target("Lesser demon")
print(demon and demon.index)
```

## CombatSafeSpot.fight

Definition:
```luau
function CombatSafeSpot.fight(index: number, options: FightOptions?): (boolean, string?)
```
Fights NPC `index` from safe spots until it's gone. Walks first to a spot where it's already in range (else waits up to `ENGAGE_TICKS` on a spot for it to come in range), attacks, and moves spot whenever it's no longer held and hittable, at most `REPOSITIONS` times. True when the monster is gone; false and why when another player fights it, `on_tick` stops, it times out, or no spot holds.

- `range`, `min_gap`, `npcs_hold`, `radius`: as for `find`.
- `avoid`: NPC names to stay safe from too.
- `on_tick(npc, me)`: every tick; return false to stop. Eat here.
- `timeout_ms`: default `FIGHT_TIMEOUT_MS`.

Example:
```luau
local CombatSafeSpot = require("@lib/main/combat_safespot")

local demon = assert(CombatSafeSpot.free_target("Lesser demon"))
local killed, why = CombatSafeSpot.fight(demon.index, { avoid = { "Black demon" } })
print(if killed then "killed it" else `stopped: {why}`)
```
