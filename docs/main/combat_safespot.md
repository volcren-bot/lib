# Main.CombatSafeSpot

Safe spots to fight from: tiles where a melee monster chases you, gets stuck where it can't hit you, and stays where you can still hit it with a bow, a crossbow or a spell. It's built on [SafeSpot](safespot.md), which works out how NPCs chase you; read its "How NPCs chase you" first.

```luau
local CombatSafeSpot = require("../main/combat_safespot")
```

What makes a good spot:

- **Behind something, in sight**: the monster walks at you until a wall, a rock or an object stops it, short of you. Projectiles fly over what doesn't block them (water, low objects), so you can often shoot over the thing that stops it.
- **Narrow corridors**: a big monster (2x2, 3x3...) can't walk where it doesn't fit, so it gets stuck at the mouth of a corridor you stand in. A 3x3 demon at the end of a 1 or 2 tile wide passage is a classic.
- **Behind other monsters**: a monster can't walk through another one, so the one behind gets stuck too. This holds only while the one in front stays put; `fight` moves on when it doesn't.

It only covers monsters that fight in melee. Turn auto retaliate off before fighting from a spot, or your character walks up to whatever hits it. `fight` won't start on a monster another player is fighting.

## Types

| Type | What it holds |
| --- | --- |
| `CombatSpot` | A `tile` to fight from, the `distance` you walk to it, where the monster ends up stuck (`at`, with the NPCs around standing still, and `at_walls` over the walls alone, `nil` when only NPCs hold it), the `gap` between you then and the `SafeSpot.Spot` it came from (`spot`). |

## CombatSafeSpot.line_of_sight

Definition:
```luau
function CombatSafeSpot.line_of_sight(grid: SafeSpot.Grid, from: Tile, to: Tile): boolean
```
Whether a projectile flies from one tile to another, as the game checks it: a line over the tiles between, stopped by walls across it and by objects that block projectiles. NPCs and players don't block it.

Example:
```luau
local CombatSafeSpot = require("../main/combat_safespot")
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local grid = assert(SafeSpot.grid_around(me, 10))
print(CombatSafeSpot.line_of_sight(grid, me, { x = me.x + 6, y = me.y + 2 }))
```

## CombatSafeSpot.nearest_tile

Definition:
```luau
function CombatSafeSpot.nearest_tile(npc: SafeSpot.Chaser, me: Tile): Tile
```
The tile of the NPC nearest to you, the one ranges and lines of sight are measured to.

Example:
```luau
local CombatSafeSpot = require("../main/combat_safespot")

local t = CombatSafeSpot.nearest_tile({ x = 100, y = 100, size = 3 }, { x = 105, y = 101 })
print(t.x, t.y) -- 102 101
```

## CombatSafeSpot.distance

Definition:
```luau
function CombatSafeSpot.distance(npc: SafeSpot.Chaser, me: Tile): number
```
How far you are from the NPC's nearest tile, diagonal steps counting as one: what attack ranges are counted in.

Example:
```luau
local CombatSafeSpot = require("../main/combat_safespot")

print(CombatSafeSpot.distance({ x = 100, y = 100, size = 3 }, { x = 105, y = 101 })) -- 3
```

## CombatSafeSpot.can_attack

Definition:
```luau
function CombatSafeSpot.can_attack(grid: SafeSpot.Grid, me: Tile, npc: SafeSpot.Chaser, range: number): boolean
```
Whether you can hit the NPC from `me` with an attack range of `range`: within range, in sight, and not standing under it. Clicking "Attack" on an NPC you can't hit like this walks you towards it.

Example:
```luau
local CombatSafeSpot = require("../main/combat_safespot")
local Npcs = require("../main/entities/npcs")
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

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
Your attack range: the range of the weapon you wear (its param 13; 7 for a crossbow), plus `LONGRANGE_BONUS` on the longrange style, at most `MAX_RANGE`. 1 with nothing in your hands. `nil` when it can't be read. Spells aren't looked at: pass `range = 10` yourself when you cast.

Example:
```luau
local CombatSafeSpot = require("../main/combat_safespot")

print("range:", CombatSafeSpot.weapon_range())
```

## CombatSafeSpot.find

Definition:
```luau
function CombatSafeSpot.find(target: SafeSpot.Chaser, options: CombatFindOptions?): ({ CombatSpot }?, string?)
```
Tiles to fight `target` from. It chases you there (played out while you walk, as in `SafeSpot.find`) and gets stuck at least `min_gap` tiles away, where you can hit it; `others` can't reach you there either. Where it gets stuck is worked out with the NPCs around standing where they are; when the walls alone hold it you must be able to hit it where they do too. Spots the walls hold come first, then the nearest walk. Options:

- `range`: your attack range (default `weapon_range()`).
- `min_gap`: the least distance it may be stuck at (default 2, so never next to you, even across a wall).
- `others`: more chasers to be safe from, like the other monsters around (see `chasers`).
- `npcs_hold`: `false` takes only spots the walls alone hold it at (default true).
- `attack_now`: you can hit it where it is now too, so the fight starts from the spot.
- `around`, `radius` (default range + 4), `from`, `speed`, `untouched`, `exclude`, `limit`, `grid`: as for `SafeSpot.find`.

Example:
```luau
local CombatSafeSpot = require("../main/combat_safespot")
local SafeSpot = require("../main/safespot")
local Walker = require("../main/walker")

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
The NPCs called one of `names` (any case) within `AVOID_RADIUS` of `center`, as chasers with their sizes from the game, leaving out the one with index `except`. Pass them as `others` to stay safe from the rest of a group.

Example:
```luau
local CombatSafeSpot = require("../main/combat_safespot")
local Walker = require("../main/walker")

local around = CombatSafeSpot.chasers({ "Lesser demon", "Black demon" }, assert(Walker.position()))
print(#around, "demons around")
```

## CombatSafeSpot.fought_by

Definition:
```luau
function CombatSafeSpot.fought_by(index: number): string?
```
The name of another player fighting the NPC with `index` (it's their target), or `nil`. Leave those alone: people don't like their kills taken.

Example:
```luau
local CombatSafeSpot = require("../main/combat_safespot")
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local demon = assert(Npcs.nearest("Greater demon", assert(Walker.position())))
print(CombatSafeSpot.fought_by(demon.index) or "free")
```

## CombatSafeSpot.free_target

Definition:
```luau
function CombatSafeSpot.free_target(name: string, from: Tile?): Npc?
```
The nearest NPC called `name` (any case) to `from` (default you) that no other player is fighting.

Example:
```luau
local CombatSafeSpot = require("../main/combat_safespot")

local demon = CombatSafeSpot.free_target("Lesser demon")
print(demon and demon.index)
```

## CombatSafeSpot.fight

Definition:
```luau
function CombatSafeSpot.fight(index: number, options: FightOptions?): (boolean, string?)
```
Fights the NPC with `index` from a safe spot until it's gone (killed) or `on_tick` says stop. It reads the monster's size from the game and won't start on one another player is fighting. Before the fight starts it walks to a spot `find` gives where the monster is in range already, so attacking doesn't walk you up to it (if there is none it waits on a spot `ENGAGE_TICKS` for the monster to come in range). Then it attacks, and walks to another spot whenever the monster isn't stuck where you can hit it any more: an NPC it was stuck behind walked off, or a click missed and walked you away. Returns `true` when the monster is gone, else `false` and why. Options:

- `range`, `min_gap`, `npcs_hold`, `radius`: as for `find`.
- `avoid`: names of NPCs to stay safe from as well, like the other monsters of the area.
- `on_tick(npc, me)`: called every tick with where the monster and you are; return `false` to stop. Eat here.
- `timeout_ms`: the longest it fights (default `FIGHT_TIMEOUT_MS`).

Example:
```luau
local CombatSafeSpot = require("../main/combat_safespot")
local Inventory = require("../main/interfaces/gametabs/inventory")
local Player = require("../main/player")

local demon = assert(CombatSafeSpot.free_target("Lesser demon"))
local killed, why = CombatSafeSpot.fight(demon.index, {
	avoid = { "Lesser demon", "Black demon" },
	on_tick = function()
		if (Player.hitpoints() or 99) < 40 then
			for _, item in ipairs(Inventory.items() or {}) do
				if item.name == "Shark" then
					Inventory.interact_slot(item.slot, "Eat")
					break
				end
			end
		end
		return nil
	end,
})
print(if killed then "killed it" else `stopped: {why}`)
```
