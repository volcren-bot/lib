# Main.Player

Information about your own character: name, position, plane, run energy, health, poison and whether you are walking.

```luau
local Player = require("../main/player")
```

Most functions return the value, or `nil` and an error message when it can't be read.

## Constants

Definition:
```luau
Player.STILL_MS = 400
Player.WALK_TIMEOUT = 20000
```
`STILL_MS` is how long (in milliseconds) you must stay in one place to count as stopped. `WALK_TIMEOUT` is how long the waiting functions wait for you to arrive before giving up.

## Player.is_logged_in

Definition:
```luau
function Player.is_logged_in(): boolean
```
Tells you whether you are logged in and in the game.

Example:
```luau
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")

print("moving:", Player.is_moving())
```

## Player.destination

Definition:
```luau
function Player.destination(): Tile?
```
The tile you are walking to (where the flag on the minimap is). `nil` when you aren't walking anywhere.

Example:
```luau
local Player = require("../main/player")

local to = Player.destination()
print(if to then `walking to {to.x}, {to.y}` else "not walking")
```

## Player.wait_still

Definition:
```luau
function Player.wait_still(timeout_ms: number?): boolean
```
Waits until you have stopped moving. Returns `false` if you are still moving after `timeout_ms` (20 seconds by default).

Example:
```luau
local Player = require("../main/player")

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
local Player = require("../main/player")

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
local Player = require("../main/player")
local Walker = require("../main/walker")

Walker.click_tile(assert(Walker.relative(5, 0)))
print("arrived:", Player.wait_walk())
```
