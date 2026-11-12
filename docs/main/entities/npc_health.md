# Main.Entities.NpcHealth

Tracks NPC health. The client shows exact hitpoints only for your current target (the top-left target display, read by `target`); for other NPCs this module sums the damage of every hitsplat it sees. Call `update` every tick with the nearby NPC indices, since a hitsplat slot is overwritten by the next hit. Healing and damage taken before an NPC was first seen are invisible until `set` corrects it. See `Host.npc_hitsplats`.

```luau
local NpcHealth = require("@lib/main/entities/npc_health")
```

## Constants

Definition:

```luau
NpcHealth.HIT = 16
NpcHealth.BLOCK = 12
NpcHealth.GROUP = 303
NpcHealth.NAME_CHILD = 9
NpcHealth.HP_CHILD = 21
```

Hitsplat kinds that count as damage (a block is 0); the target display's interface group, name child and "hp / max" child.

Example:

```luau
print(NpcHealth.HIT)
```

## NpcHealth.target

Definition:

```luau
function NpcHealth.target(): (string?, number?, number?)
```

The name, hitpoints and maximum shown in the target display, or three nils when it is hidden or unreadable.

Example:

```luau
local name, hp, max = NpcHealth.target()
```

## NpcHealth.set

Definition:

```luau
function NpcHealth.set(index: number, hp: number, max_hp: number)
```

Takes `hp` of `max_hp` as the truth for NPC `index`, replacing the summed damage; later hits count from here. Feed it what `target` shows.

Example:

```luau
local _, hp, max = NpcHealth.target()
if hp and max then
	NpcHealth.set(npc.index, hp, max)
end
```

## NpcHealth.max_hp

Definition:

```luau
function NpcHealth.max_hp(index: number): number?
```

The `max_hp` last passed to `set` for this NPC, or nil.

Example:

```luau
print(NpcHealth.max_hp(npc.index))
```

## NpcHealth.update

Definition:

```luau
function NpcHealth.update(indices: { number })
```

Reads the hitsplats of `indices` and adds each new one once. NPCs missing from `indices` are forgotten.

Example:

```luau
local indices = {}
for _, npc in Host.npcs() or {} do
	table.insert(indices, npc.index)
end
NpcHealth.update(indices)
```

## NpcHealth.damage

Definition:

```luau
function NpcHealth.damage(index: number): number
```

Damage seen so far, 0 for an unseen NPC.

Example:

```luau
print(NpcHealth.damage(npc.index))
```

## NpcHealth.remaining

Definition:

```luau
function NpcHealth.remaining(index: number, max_hp: number): number
```

`max_hp - damage`, at least 0.

Example:

```luau
print(NpcHealth.remaining(npc.index, 80))
```

## NpcHealth.fraction

Definition:

```luau
function NpcHealth.fraction(index: number, max_hp: number): number
```

`remaining / max_hp`, from 1 (unhurt) to 0.

Example:

```luau
print(NpcHealth.fraction(npc.index, 80))
```

## NpcHealth.reset

Definition:

```luau
function NpcHealth.reset()
```

Forgets all tracked NPCs.

Example:

```luau
NpcHealth.reset()
```
