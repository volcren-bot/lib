# Main.Entities.Projectiles

Projectiles in flight: arrows, spells and monster attacks, for dodging or praying before they land.

```luau
local Projectiles = require("@lib/main/entities/projectiles")
```

A `Host.Projectile` has:

- `id`: graphic (spot animation) id.
- `source_x`, `source_y`, `source_plane`, `target_x`, `target_y`, `target_plane`: world tiles as sent by the server.
- `source_npc`, `source_player`, `target_npc`, `target_player`: actor indices, -1 for none. A projectile aimed at an actor follows it, landing wherever the actor is. The server often omits the source actor, even for your own shots.
- `start_cycle`, `end_cycle`, `cycle`: client cycles (50/s) when it leaves, lands, and now. It is listed as soon as the server sends it; `moving` is false until it leaves.
- `x`, `y` (world tile), `local_x`, `local_y` (fine units, 128 per tile), `height` (fine units above ground): current position, the source tile centre at `start_height` until it moves. `z` is the client's height (negative is up, from the heightmap zero) and `orientation` the heading (0-2047).
- `start_height`, `end_height`, `slope`, `start_pos`: the arc.

## Constants

Definition:

```luau
Projectiles.CYCLE_MS = 20
```

One client cycle in ms (a 600 ms game tick is 30 cycles).

Example:

```luau
print(30 * Projectiles.CYCLE_MS) -- 600
```

## Projectiles.find

Definition:

```luau
function Projectiles.find(what: (number | { number })?): { Projectile }?
```

Projectiles in flight or about to leave, optionally matching a graphic id or list of ids. Nil when unreadable.

Example:

```luau
for _, p in Projectiles.find() or {} do
	print(p.id, p.x, p.y, p.end_cycle - p.cycle)
end
```

## Projectiles.at_npc

Definition:

```luau
function Projectiles.at_npc(npc: Npc, what: (number | { number })?): { Projectile }?
```

Projectiles targeting `npc`, optionally filtered by graphic id.

Example:

```luau
print(#(Projectiles.at_npc(cow) or {}))
```

## Projectiles.at_player

Definition:

```luau
function Projectiles.at_player(player: PlayerInfo, what: (number | { number })?): { Projectile }?
```

Projectiles targeting `player`, optionally filtered by graphic id.

Example:

```luau
print(#(Projectiles.at_player(other) or {}))
```

## Projectiles.at_me

Definition:

```luau
function Projectiles.at_me(what: (number | { number })?): { Projectile }?
```

Projectiles targeting you. Nil when you can't be found in the player list.

Example:

```luau
for _, p in Projectiles.at_me() or {} do
	print(p.id, Projectiles.remaining_ms(p))
end
```

## Projectiles.from_npc

Definition:

```luau
function Projectiles.from_npc(npc: Npc, what: (number | { number })?): { Projectile }?
```

Projectiles launched by `npc`. Only finds those the server sent with a source actor.

Example:

```luau
print(#(Projectiles.from_npc(xil) or {}))
```

## Projectiles.remaining_ms

Definition:

```luau
function Projectiles.remaining_ms(projectile: Projectile): number
```

Ms until it lands, 0 once landed.

Example:

```luau
print(Projectiles.remaining_ms(p))
```

## Projectiles.departs_in_ms

Definition:

```luau
function Projectiles.departs_in_ms(projectile: Projectile): number
```

Ms until it leaves, 0 once moving.

Example:

```luau
print(Projectiles.departs_in_ms(p))
```

## Projectiles.flight_ms

Definition:

```luau
function Projectiles.flight_ms(projectile: Projectile): number
```

Total flight time from leaving to landing, in ms.

Example:

```luau
print(Projectiles.flight_ms(p))
```

## Projectiles.progress

Definition:

```luau
function Projectiles.progress(projectile: Projectile): number
```

Flight progress from 0 (not left) to 1 (landed).

Example:

```luau
print(Projectiles.progress(p))
```

## Projectiles.tile

Definition:

```luau
function Projectiles.tile(projectile: Projectile): Tile
```

The world tile it is over now.

Example:

```luau
local tile = Projectiles.tile(p)
```

## Projectiles.target

Definition:

```luau
function Projectiles.target(projectile: Projectile): Tile
```

The target tile it was sent at. For one aimed at an actor, look up `target_npc`/`target_player` to know where it actually lands.

Example:

```luau
local tile = Projectiles.target(p)
```

## Projectiles.screen

Definition:

```luau
function Projectiles.screen(projectile: Projectile): Point?
```

Its current screen position, or nil when it can't be projected.

Example:

```luau
local at = Projectiles.screen(p)
if at then
	Draw.rect(at.x - 4, at.y - 4, at.x + 4, at.y + 4, Draw.color(255, 0, 0))
end
```

## Projectiles.first_landing

Definition:

```luau
function Projectiles.first_landing(what: (number | { number })?): Projectile?
```

The projectile with the earliest `end_cycle`, optionally among the given graphic ids, or nil.

Example:

```luau
local next = Projectiles.first_landing()
```
