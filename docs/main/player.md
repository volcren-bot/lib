# Main.Player

Information about your own character: name, position, plane, run energy, health, poison and whether you are walking.

```luau
local Player = require("@lib/main/player")
```

Most functions return the value, or `nil` and an error message when it can't be read.

## Constants

Definition:
```luau
Player.STILL_MS = 400
Player.WALK_TIMEOUT = 20000
```
`STILL_MS` is how long (in milliseconds) you must stay in one place to count as stopped. `WALK_TIMEOUT` is how long the waiting functions wait for you to arrive before giving up.

```luau
Player.HIT_KINDS = { [16] = true, [12] = true, [43] = true }
Player.COMBAT_MS = 6000
Player.INTERACTING = 0
```
These are what `Player.attacking` and `Player.is_attacked` go by:

- `HIT_KINDS`: the hitsplat kinds of a hit that involves you, dealt or taken. 16 is damage and 12 a block (both seen live). 43 is a max hit, which hasn't been seen live.
- `COMBAT_MS`: how long a landed hit keeps a fight going, set longer than the slowest attacks take.
- `INTERACTING`: your interaction state while you act on an NPC.

## Player.is_logged_in

Definition:
```luau
function Player.is_logged_in(): boolean
```
Tells you whether you are logged in and in the game.

Example:
```luau
local Player = require("@lib/main/player")

print("logged in:", Player.is_logged_in())
```

## Player.name

Definition:
```luau
function Player.name(): string?
```
Your character's display name.

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
Where you are standing, as a [Position](position.md), including the plane.

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
The 64x64 map chunks the scene around you is built from, as the game client lists them. Outdoors these are the chunks around you; in an instance they are the *source* chunks the server copied, not the chunks the instance sits on. Tempoross, for example, is always a copy of chunk 47, 44 (id 12076), wherever the instance is. `nil` when they can't be read, for example while logged out.

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
Whether you are inside an instance (a minigame, raid or other private copy of an area). It reads the game client's own "this scene is an instance" flag. With an agent that doesn't have the flag it falls back to your coordinates (`Position.in_instance`). `false` when neither can be read.

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
The 64x64 map chunks the instance you are in was copied from, as the game client lists them. `nil` when you are not in an instance or the chunks can't be read. Instances sit at different coordinates every time, so this is how to tell which one you are in.

Example:
```luau
local Player = require("@lib/main/player")

for _, chunk in ipairs(Player.instance_chunks() or {}) do
	print(chunk.x, chunk.y, chunk:id())
end
```

## Player.instance_id

Definition:
```luau
function Player.instance_id(): number?
```
The id (`x * 256 + y`, see `Chunk.id`) of the map chunk the instance you are in was copied from, when it is a copy of a single chunk. `nil` outside instances, when the chunks can't be read, or when the instance is built from more than one chunk (use `Player.instance_chunks` then). Tempoross is always chunk 47, 44: id 12076.

Example:
```luau
local Player = require("@lib/main/player")

local TEMPOROSS = 12076
if Player.instance_id() == TEMPOROSS then
	print("in a Tempoross game")
end
```

## Player.plane

Definition:
```luau
function Player.plane(): number?
```
The plane (floor) you are on: 0 is the ground floor, 1 the floor above, up to 3.

Example:
```luau
local Player = require("@lib/main/player")

if Player.plane() == 1 then
	print("upstairs")
end
```

## Player.run_energy

Definition:
```luau
function Player.run_energy(): number?
```
Your run energy as a percentage from 0 to 100.

Example:
```luau
local Player = require("@lib/main/player")

print("run energy:", Player.run_energy())
```

## Player.weight

Definition:
```luau
function Player.weight(): number?
```
The weight you are carrying.

Example:
```luau
local Player = require("@lib/main/player")

print("weight:", Player.weight())
```

## Player.hitpoints

Definition:
```luau
function Player.hitpoints(): (number?, number?)
```
Your current hitpoints, followed by your real (unboosted) level.

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
Your current prayer points, followed by your real (unboosted) level.

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
Whether run mode is switched on.

Example:
```luau
local Player = require("@lib/main/player")

print("running:", Player.is_running())
```

## Player.special_attack

Definition:
```luau
function Player.special_attack(): number?
```
Your special attack energy as a percentage from 0 to 100.

Example:
```luau
local Player = require("@lib/main/player")

print("special:", Player.special_attack())
```

## Player.special_attack_enabled

Definition:
```luau
function Player.special_attack_enabled(): boolean
```
Whether the special attack is currently switched on.

Example:
```luau
local Player = require("@lib/main/player")

print("special on:", Player.special_attack_enabled())
```

## Player.poison

Definition:
```luau
function Player.poison(): string?
```
Your poison status: `"healthy"`, `"poisoned"` or `"envenomed"`.

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
Tells you whether the server moved you to another tile in the last game tick, or in the one being received. It is exact and returns straight away; see `Host.movement`. With an agent that doesn't track the server tile, it compares your position before and after a short wait (`sample_ms`, 100 by default) instead.

Example:
```luau
local Player = require("@lib/main/player")

print("moving:", Player.is_moving())
```

## Player.destination

Definition:
```luau
function Player.destination(): Tile?
```
The tile you are walking to (where the flag on the minimap is). `nil` when you aren't walking anywhere. It clears on the server's last step, a few tiles before you get there: use [`Player.in_transit`](#playerin_transit) to know whether you have stopped.

Example:
```luau
local Player = require("@lib/main/player")

local to = Player.destination()
print(if to then `walking to {to.x}, {to.y}` else "not walking")
```

## Player.in_transit

Definition:
```luau
function Player.in_transit(): boolean
```
Whether you are still on the way somewhere: you have a destination, or the client still has steps of your path to animate. Anything aimed on screen has to allow for this, because the camera keeps following you until those steps are done.

Example:
```luau
local Player = require("@lib/main/player")

print(if Player.in_transit() then "on the way" else "arrived")
```

## Player.animation

Definition:
```luau
function Player.animation(): number?
```
The id of the animation the player is playing, or `-1` when there is none: an obstacle, a search, an attack. Walking and running are not animations (the client reports them as the pose). `nil` when it can't be read.

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
The id of the player's pose: what it does when no animation plays, like standing, walking or riding a magic carpet. Nil when the player can't be found.

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
The NPC the player is fighting, or `nil`. It takes all three of these:

1. **Acting on an NPC:** the player's interaction state is `Player.INTERACTING` (0). The client sets it to 2 once the NPC dies and to 3 once the player walks off or the action ends, so a stale target never counts.
2. **In the scene:** that NPC is still there.
3. **Hits landing:** one of the player's hits (`Player.HIT_KINDS`) landed on it within `Player.COMBAT_MS`, or one of the player's projectiles is flying at it. The client often stores only where a projectile starts, so one that leaves the player's tile for the target counts as the player's. Projectiles show up as soon as the attack starts, before they leave, so a long shot counts while it flies.

It is `nil` while the player walks up to an NPC it clicked, until the first hit or projectile. A thrall's hits on the target count as the player's.

Example:
```luau
local Player = require("@lib/main/player")

local npc = Player.attacking()
print(if npc then `fighting {npc.name}` else "not fighting")
```

## Player.is_attacked

Definition:
```luau
function Player.is_attacked(): boolean
```
Whether the player is being attacked: a hit on it (`Player.HIT_KINDS`, a miss included) within `Player.COMBAT_MS`, or any projectile flying at it. An NPC that only walks up to the player doesn't count until it attacks.

Example:
```luau
local Player = require("@lib/main/player")

if Player.is_attacked() then
	print("under attack")
end
```

## Player.in_combat

Definition:
```luau
function Player.in_combat(): boolean
```
Whether the player is attacking an NPC (`Player.attacking`) or being attacked (`Player.is_attacked`).

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
Runs `drink`, a click that restores the player such as a pool's "Drink", and waits up to `timeout_ms` for it to take: hitpoints, prayer or run energy going up, or all of them already full. False and why. `House.restore` and `Ferox.restore` use it.

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
Whether the player is playing an animation (see `Player.animation`).

Example:
```luau
local Host = require("@lib/host")
local Player = require("@lib/main/player")

while Player.is_animating() do
	Host.sleep(50)
end
```

## Player.wait_idle

Definition:
```luau
function Player.wait_idle(timeout_ms: number?, on_poll: (() -> ())?): boolean
```
Waits until the player has neither moved nor played an animation for `Player.IDLE_MS` (300 ms), so a crossing is over. Returns `false` if that hasn't happened after `timeout_ms` (20 seconds by default). `on_poll`, if given, is called on every check, to log what the player is doing meanwhile.

Example:
```luau
local Player = require("@lib/main/player")

print("idle:", Player.wait_idle(8000))
```

## Player.wait_still

Definition:
```luau
function Player.wait_still(timeout_ms: number?): boolean
```
Waits until you have stopped moving. Returns `false` if you are still moving after `timeout_ms` (20 seconds by default).

Example:
```luau
local Player = require("@lib/main/player")

print("stopped:", Player.wait_still(5000))
```

## Player.wait_server_still

Definition:
```luau
function Player.wait_server_still(timeout_ms: number?): boolean
```
Waits until the server stops moving you: it returns at the first game tick that leaves you on the same tile, which can be before your character's model has finished walking there (`Player.wait_still` waits for that). Returns `false` if you are still moving after `timeout_ms` (20 seconds by default). With an agent that doesn't track the server tile, it does what `Player.wait_still` does.

Example:
```luau
local Player = require("@lib/main/player")

print("stopped:", Player.wait_server_still(5000))
```

## Player.wait_walk

Definition:
```luau
function Player.wait_walk(timeout_ms: number?): boolean
```
Call this right after clicking somewhere. If the click didn't make you walk it returns straight away, otherwise it waits until you arrive and stand still. Returns `false` if you are still on your way after `timeout_ms`.

Example:
```luau
local Player = require("@lib/main/player")
local Walker = require("@lib/main/walker")

Walker.click_tile(assert(Walker.relative(5, 0)))
print("arrived:", Player.wait_walk())
```
