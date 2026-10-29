# Main.Entities.NpcHealth

How hurt an NPC is. The game client shows the exact hitpoints of the NPC you are fighting in its target display (top left), and only that one. `target` reads it and `set` takes it as the truth for that NPC; for the others the client keeps only their last hitsplats, so this adds up the damage of every hit it sees and takes it off the maximum.

```luau
local NpcHealth = require("../main/entities/npc_health")
```

Call `NpcHealth.update` every tick with the indices of the NPCs around you (a hitsplat is replaced by the next hit in its slot, so reading less often can miss hits). An NPC that is already hurt when it is first seen counts from there on, and healing is not seen, until it is the NPC you fight and `set` corrects it. See `Host.npc_hitsplats`.

## Constants

Definition:
```luau
NpcHealth.HIT = 16
NpcHealth.BLOCK = 12
```
The hitsplat types that carry damage: a hit, and a block (which shows 0).

```luau
NpcHealth.GROUP = 303
NpcHealth.NAME_CHILD = 9
NpcHealth.HP_CHILD = 21
```
The target display's interface, the child with the NPC's name and the child with its "hitpoints / maximum" text.

## NpcHealth.target

Definition:
```luau
function NpcHealth.target(): (string?, number?, number?)
```
The name, hitpoints and maximum hitpoints the target display shows (the NPC you are fighting), or `nil` when it shows none.

Example:
```luau
local NpcHealth = require("../main/entities/npc_health")

local name, hp, max = NpcHealth.target()
print(name, hp, max)
```

## NpcHealth.set

Definition:
```luau
function NpcHealth.set(index: number, hp: number, max_hp: number)
```
Takes `hp` of `max_hp` as the truth for the NPC with `index`: the damage seen before and any healing are corrected, and the hits seen after count from here. Use it with what `target` shows for the NPC you are fighting.

Example:
```luau
local NpcHealth = require("../main/entities/npc_health")

local _, hp, max = NpcHealth.target()
if hp and max then
	NpcHealth.set(1234, hp, max)
end
```

## NpcHealth.max_hp

Definition:
```luau
function NpcHealth.max_hp(index: number): number?
```
The maximum hitpoints the target display showed for the NPC, `nil` when it never did.

Example:
```luau
local NpcHealth = require("../main/entities/npc_health")

print(NpcHealth.max_hp(1234))
```

## NpcHealth.update

Definition:
```luau
function NpcHealth.update(indices: { number })
```
Reads the hitsplats of the NPCs with `indices` and adds the hits that are new. NPCs that are not in the list any more are forgotten.

Example:
```luau
local Host = require("../host")
local NpcHealth = require("../main/entities/npc_health")

local indices = {}
for _, npc in ipairs(Host.npcs() or {}) do
	table.insert(indices, npc.index)
end
NpcHealth.update(indices)
```

## NpcHealth.damage

Definition:
```luau
function NpcHealth.damage(index: number): number
```
The damage seen on the NPC so far, 0 for one not seen.

Example:
```luau
local NpcHealth = require("../main/entities/npc_health")

print(NpcHealth.damage(1234))
```

## NpcHealth.remaining

Definition:
```luau
function NpcHealth.remaining(index: number, max_hp: number): number
```
The hitpoints left of an NPC that has `max_hp`, at least 0.

Example:
```luau
local NpcHealth = require("../main/entities/npc_health")

print(NpcHealth.remaining(1234, 80))
```

## NpcHealth.fraction

Definition:
```luau
function NpcHealth.fraction(index: number, max_hp: number): number
```
How much of its hitpoints an NPC that has `max_hp` has left, from 1 (unhurt) to 0.

Example:
```luau
local NpcHealth = require("../main/entities/npc_health")

print(NpcHealth.fraction(1234, 80))
```

## NpcHealth.reset

Definition:
```luau
function NpcHealth.reset()
```
Forgets everything seen, for a new fight.

Example:
```luau
local NpcHealth = require("../main/entities/npc_health")

NpcHealth.reset()
```
