# Main.Player

Your own character: name, position, instance, stats, combat and movement waits. Readers return `nil` when the value can't be read (for example while logged out).

```luau
local Player = require("@lib/main/player")
```

## Constants

Definition:
```luau
Player.STILL_MS = 400
Player.WALK_TIMEOUT = 20000
Player.IDLE_MS = 300
Player.HIT_KINDS = { [16] = true, [12] = true, [43] = true }
Player.COMBAT_MS = 6000
Player.INTERACTING = 0
```
- `STILL_MS`: ms on one tile to count as stopped (`wait_still`).
- `WALK_TIMEOUT`: default timeout of the `wait_*` functions.
- `IDLE_MS`: ms without moving or animating to count as idle (`wait_idle`).
- `HIT_KINDS`: hitsplat kinds that count as a hit: 16 damage, 12 block, 43 max hit (not yet seen live).
- `COMBAT_MS`: how long a landed hit keeps a fight going.
- `INTERACTING`: your interaction state while acting on an NPC.

## Player.is_logged_in

Definition:
```luau
function Player.is_logged_in(): boolean
```
Whether you are logged in and in the game.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.is_logged_in())
```

## Player.name

Definition:
```luau
function Player.name(): string?
```
Your display name.

Example:
```luau
local Player = require("@lib/main/player")

print("I am", Player.name())
```

## Player.position

Definition:
```luau
function Player.position(): Position.Position?
```
Your tile as a [Position](position.md), plane included.

Example:
```luau
local Player = require("@lib/main/player")

local pos = Player.position()
if pos then
	print(pos.x, pos.y, pos.plane)
end
```

## Player.map_chunks

Definition:
```luau
function Player.map_chunks(): { Position.Chunk }?
```
The 64x64 chunks the scene is built from, as the client lists them. In an instance these are the *source* chunks the server copied (Tempoross is always chunk 47, 44, id 12076), not where the instance sits.

Example:
```luau
local Player = require("@lib/main/player")

for _, chunk in ipairs(Player.map_chunks() or {}) do
	print(chunk.x, chunk.y, chunk:id())
end
```

## Player.in_instance

Definition:
```luau
function Player.in_instance(): boolean
```
Whether you are in an instance. Reads the client's instance flag, falling back to `Position.in_instance` on your coordinates; `false` when neither can be read.

Example:
```luau
local Player = require("@lib/main/player")

if Player.in_instance() then
	print("in an instance")
end
```

## Player.instance_chunks

Definition:
```luau
function Player.instance_chunks(): { Position.Chunk }?
```
The source chunks of the instance you are in; `nil` outside instances. Instances move every time, so this identifies which one you are in.

Example:
```luau
local Player = require("@lib/main/player")

for _, chunk in ipairs(Player.instance_chunks() or {}) do
	print(chunk:id())
end
```

## Player.instance_id

Definition:
```luau
function Player.instance_id(): number?
```
The `Chunk.id` (`x * 256 + y`) of the instance's source chunk when it copies exactly one chunk; `nil` outside instances or for multi-chunk instances (use `instance_chunks`).

Example:
```luau
local Player = require("@lib/main/player")

if Player.instance_id() == 12076 then
	print("in a Tempoross game")
end
```

## Player.plane

Definition:
```luau
function Player.plane(): number?
```
Your floor, 0 (ground) to 3.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.plane() == 1)
```

## Player.run_energy

Definition:
```luau
function Player.run_energy(): number?
```
Run energy, 0 to 100.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.run_energy())
```

## Player.weight

Definition:
```luau
function Player.weight(): number?
```
The weight you carry.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.weight())
```

## Player.hitpoints

Definition:
```luau
function Player.hitpoints(): (number?, number?)
```
Current hitpoints and real (unboosted) level.

Example:
```luau
local Player = require("@lib/main/player")

local current, max = Player.hitpoints()
print(`{current}/{max}`)
```

## Player.prayer

Definition:
```luau
function Player.prayer(): (number?, number?)
```
Current prayer points and real (unboosted) level.

Example:
```luau
local Player = require("@lib/main/player")

local current, max = Player.prayer()
print(`{current}/{max}`)
```

## Player.is_running

Definition:
```luau
function Player.is_running(): boolean
```
Whether run mode is on.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.is_running())
```

## Player.special_attack

Definition:
```luau
function Player.special_attack(): number?
```
Special attack energy, 0 to 100.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.special_attack())
```

## Player.special_attack_enabled

Definition:
```luau
function Player.special_attack_enabled(): boolean
```
Whether the special attack is switched on.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.special_attack_enabled())
```

## Player.poison

Definition:
```luau
function Player.poison(): string?
```
`"healthy"`, `"poisoned"` or `"envenomed"`.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.poison())
```

## Player.is_moving

Definition:
```luau
function Player.is_moving(sample_ms: number?): boolean
```
Whether the server moved you a tile in the last or incoming tick (`Host.movement`), exact and immediate. Without server tracking it compares your position across a `sample_ms` wait (default 100); `false` when the position can't be read.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.is_moving())
```

## Player.destination

Definition:
```luau
function Player.destination(): Tile?
```
The minimap flag tile you are walking to, or `nil`. It clears on the server's last step, a few tiles early: use [`Player.in_transit`](#playerin_transit) to know you have stopped.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.destination())
```

## Player.in_transit

Definition:
```luau
function Player.in_transit(): boolean
```
Whether you have a destination or the client still has path steps to animate. The camera follows you until then, so on-screen aiming must allow for it.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.in_transit())
```

## Player.animation

Definition:
```luau
function Player.animation(): number?
```
Your current animation id, `-1` for none. Walking and running are poses, not animations.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.animation())
```

## Player.pose

Definition:
```luau
function Player.pose(): number?
```
Your pose id (standing, walking, riding a carpet); `nil` when you can't be found.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.pose())
```

## Player.attacking

Definition:
```luau
function Player.attacking(): Host.Npc?
```
The NPC you are fighting, or `nil`. All of: your interaction state is `INTERACTING` (2 after the NPC dies, 3 after you walk off), the NPC is in the scene, and one of your `HIT_KINDS` landed on it within `COMBAT_MS` or your projectile is flying at it (one leaving your tile counts as yours). `nil` while walking up before the first hit; thrall hits count as yours.

Example:
```luau
local Player = require("@lib/main/player")

local npc = Player.attacking()
print(if npc then npc.name else "not fighting")
```

## Player.is_attacked

Definition:
```luau
function Player.is_attacked(): boolean
```
Whether a hit (`HIT_KINDS`, misses included) landed on you within `COMBAT_MS` or a projectile is flying at you. An NPC walking up doesn't count.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.is_attacked())
```

## Player.in_combat

Definition:
```luau
function Player.in_combat(): boolean
```
`attacking() ~= nil or is_attacked()`.

Example:
```luau
local Player = require("@lib/main/player")

if not Player.in_combat() then
	print("safe to bank")
end
```

## Player.restore_with

Definition:
```luau
function Player.restore_with(drink: () -> boolean, timeout_ms: number): (boolean, string?)
```
Runs `drink` (a restoring click such as a pool's "Drink") and waits up to `timeout_ms` for hitpoints, prayer or run energy to rise, or all to be full. Returns `false` and why on failure. Used by `House.restore` and `Ferox.restore`.

Example:
```luau
local Objects = require("@lib/main/entities/objects")
local Player = require("@lib/main/player")

local pool = Objects.nearest("Pool of Refreshment", assert(Player.position()))
if pool then
	print(Player.restore_with(function()
		return Objects.approach(pool, "Drink")
	end, 10000))
end
```

## Player.is_animating

Definition:
```luau
function Player.is_animating(): boolean
```
Whether `Player.animation()` is set and not `-1`.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.is_animating())
```

## Player.wait_idle

Definition:
```luau
function Player.wait_idle(timeout_ms: number?, on_poll: (() -> ())?): boolean
```
Waits until you neither move nor animate for `IDLE_MS`; `false` after `timeout_ms` (default `WALK_TIMEOUT`). `on_poll` runs on every check.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.wait_idle(8000))
```

## Player.wait_still

Definition:
```luau
function Player.wait_still(timeout_ms: number?): boolean
```
Waits until your model stays on one spot for `STILL_MS`; `false` after `timeout_ms` (default `WALK_TIMEOUT`) or when the position can't be read.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.wait_still(5000))
```

## Player.wait_server_still

Definition:
```luau
function Player.wait_server_still(timeout_ms: number?): boolean
```
Returns at the first tick the server leaves you on the same tile, possibly before your model finishes walking; `false` after `timeout_ms` (default `WALK_TIMEOUT`). Without server tracking it behaves like `wait_still`.

Example:
```luau
local Player = require("@lib/main/player")

print(Player.wait_server_still(5000))
```

## Player.wait_walk

Definition:
```luau
function Player.wait_walk(timeout_ms: number?): boolean
```
Call right after a click: returns `true` at once if there is no destination, otherwise waits for it to clear and then `wait_still`. `false` after `timeout_ms` (default `WALK_TIMEOUT`).

Example:
```luau
local Player = require("@lib/main/player")
local Walker = require("@lib/main/walker")

Walker.click_tile(assert(Walker.relative(5, 0)))
print(Player.wait_walk())
```
