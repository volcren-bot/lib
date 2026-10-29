# Main.Entities.Projectiles

Finding the projectiles in flight: arrows, bolts, spells and the attacks monsters throw at you.

```luau
local Projectiles = require("../main/entities/projectiles")
```

A projectile is a `Host.Projectile`:

- `id` is its graphic (spot animation) id, the same id RuneLite's dev tools show.
- `source_x`, `source_y`, `source_plane` and `target_x`, `target_y`, `target_plane` are the world tiles it flies between, as the server sent them.
- `source_npc`/`source_player` and `target_npc`/`target_player` are the actors it flies from and at (an NPC or player `index`, -1 for none). A projectile aimed at an actor follows it, so it lands wherever that actor is by then, not on `target_x`, `target_y`. The server often sends only a source tile, so the source actor is -1 even for your own shots.
- `start_cycle`, `end_cycle` and `cycle` are client cycles (50 a second): when it leaves, when it lands, and now. A projectile is listed from the moment the server sends it, which can be before it leaves; `moving` is false until then.
- `x`, `y` (world tile), `local_x`, `local_y` (fine units, 128 to a tile) and `height` (fine units above the ground) are where it is now. Until it moves, that is the centre of the source tile at `start_height`. `z` is the client's own height (negative is up, counted from the heightmap's zero rather than the ground) and `orientation` its heading (0 to 2047).
- `start_height`, `end_height`, `slope` and `start_pos` describe its arc.

Projectiles that are aimed at you can be dodged or prayed against before they land. `remaining_ms` says how long you have.

## Constants

Definition:
```luau
Projectiles.CYCLE_MS = 20
```
How long a client cycle lasts. The game ticks every 600 ms, which is 30 cycles.

## Projectiles.find

Definition:
```luau
function Projectiles.find(what: (number | { number })?): { Projectile }?
```
Lists the projectiles in flight, or about to leave. Give a graphic id or a list of ids to only get matching ones. Returns `nil` when they can't be read.

Example:
```luau
local Projectiles = require("../main/entities/projectiles")

for _, p in ipairs(Projectiles.find() or {}) do
	print(p.id, p.x, p.y, p.height, p.end_cycle - p.cycle)
end
```

## Projectiles.at_npc

Definition:
```luau
function Projectiles.at_npc(npc: Npc, what: (number | { number })?): { Projectile }?
```
The projectiles flying at an NPC, optionally only those with the given graphic ids.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Projectiles = require("../main/entities/projectiles")
local Walker = require("../main/walker")

local cow = Npcs.nearest("Cow", assert(Walker.position()))
if cow then
	print(#(Projectiles.at_npc(cow) or {}), "projectiles on their way to the cow")
end
```

## Projectiles.at_player

Definition:
```luau
function Projectiles.at_player(player: PlayerInfo, what: (number | { number })?): { Projectile }?
```
The projectiles flying at a player, optionally only those with the given graphic ids.

Example:
```luau
local Players = require("../main/entities/players")
local Projectiles = require("../main/entities/projectiles")

for _, player in ipairs(Players.find() or {}) do
	print(player.name, #(Projectiles.at_player(player) or {}))
end
```

## Projectiles.at_me

Definition:
```luau
function Projectiles.at_me(what: (number | { number })?): { Projectile }?
```
The projectiles flying at you, optionally only those with the given graphic ids. Returns `nil` when you can't be found.

Example:
```luau
local Projectiles = require("../main/entities/projectiles")

for _, p in ipairs(Projectiles.at_me() or {}) do
	print(`graphic {p.id} lands in {Projectiles.remaining_ms(p)} ms`)
end
```

## Projectiles.from_npc

Definition:
```luau
function Projectiles.from_npc(npc: Npc, what: (number | { number })?): { Projectile }?
```
The projectiles an NPC launched, optionally only those with the given graphic ids. Only projectiles the server sent with a source actor are found.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Projectiles = require("../main/entities/projectiles")
local Walker = require("../main/walker")

local xil = Npcs.nearest("Tok-Xil", assert(Walker.position()))
if xil then
	print(#(Projectiles.from_npc(xil) or {}), "spines in the air")
end
```

## Projectiles.remaining_ms

Definition:
```luau
function Projectiles.remaining_ms(projectile: Projectile): number
```
How long until it lands, in ms (0 once it has).

Example:
```luau
local Projectiles = require("../main/entities/projectiles")

local next = Projectiles.first_landing()
print(next and Projectiles.remaining_ms(next))
```

## Projectiles.departs_in_ms

Definition:
```luau
function Projectiles.departs_in_ms(projectile: Projectile): number
```
How long until it leaves, in ms (0 once it is moving).

Example:
```luau
local Projectiles = require("../main/entities/projectiles")

for _, p in ipairs(Projectiles.find() or {}) do
	if not p.moving then
		print(p.id, "leaves in", Projectiles.departs_in_ms(p), "ms")
	end
end
```

## Projectiles.flight_ms

Definition:
```luau
function Projectiles.flight_ms(projectile: Projectile): number
```
How long the whole flight takes, from leaving to landing, in ms.

Example:
```luau
local Projectiles = require("../main/entities/projectiles")

for _, p in ipairs(Projectiles.find() or {}) do
	print(p.id, Projectiles.flight_ms(p))
end
```

## Projectiles.progress

Definition:
```luau
function Projectiles.progress(projectile: Projectile): number
```
How far along its flight it is, from 0 (not left yet) to 1 (landed).

Example:
```luau
local Projectiles = require("../main/entities/projectiles")

for _, p in ipairs(Projectiles.find() or {}) do
	print(p.id, string.format("%.0f%%", Projectiles.progress(p) * 100))
end
```

## Projectiles.tile

Definition:
```luau
function Projectiles.tile(projectile: Projectile): Tile
```
The world tile it is over now.

Example:
```luau
local Projectiles = require("../main/entities/projectiles")

for _, p in ipairs(Projectiles.find() or {}) do
	local tile = Projectiles.tile(p)
	print(p.id, tile.x, tile.y)
end
```

## Projectiles.target

Definition:
```luau
function Projectiles.target(projectile: Projectile): Tile
```
The world tile it was sent at. A projectile aimed at an actor follows it, so look that actor up (`target_npc`, `target_player`) to know where it lands.

Example:
```luau
local Projectiles = require("../main/entities/projectiles")

for _, p in ipairs(Projectiles.find() or {}) do
	local target = Projectiles.target(p)
	print(p.id, "heading for", target.x, target.y)
end
```

## Projectiles.screen

Definition:
```luau
function Projectiles.screen(projectile: Projectile): Point?
```
Where it is drawn on the screen now, or `nil` when it can't be projected.

Example:
```luau
local Draw = require("../utils/draw")
local Projectiles = require("../main/entities/projectiles")

for _, p in ipairs(Projectiles.find() or {}) do
	local at = Projectiles.screen(p)
	if at then
		Draw.rect(at.x - 4, at.y - 4, at.x + 4, at.y + 4, Draw.color(255, 0, 0))
	end
end
```

## Projectiles.first_landing

Definition:
```luau
function Projectiles.first_landing(what: (number | { number })?): Projectile?
```
The projectile that lands first, optionally among those with the given graphic ids.

Example:
```luau
local Projectiles = require("../main/entities/projectiles")

local next = Projectiles.first_landing()
if next then
	print(`graphic {next.id} lands in {Projectiles.remaining_ms(next)} ms`)
end
```
