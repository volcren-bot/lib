# Main.Interfaces.Gametabs.Stats

Skill levels and experience, read from game state, and hovering skills in the stats tab. Names are case-insensitive (`"Mining"`); a `Skill` has `name`, `level` (boosted), `real_level` and `xp`.

```luau
local Stats = require("@lib/main/interfaces/gametabs/stats")
```

## Constants

Definition:
```luau
Stats.GROUP = 320
Stats.CHILDREN: { [string]: number }
```
The stats tab and each lowercase skill name's child (1 to 24, attack to sailing, plus `total = 25`).

## Stats.Skill

Definition:
```luau
export type SkillName = "Attack" | "Strength" | "Defence" | "Ranged" | "Prayer" | "Magic" | "Runecraft" | "Construction" | "Hitpoints" | "Agility" | "Herblore" | "Thieving" | "Crafting" | "Fletching" | "Slayer" | "Hunter" | "Mining" | "Smithing" | "Fishing" | "Cooking" | "Firemaking" | "Woodcutting" | "Farming" | "Sailing"
```
Every skill name. `Stats.Skill` is a frozen table of them (`Stats.Skill.Herblore`), so typos are type errors.

Example:
```luau
local Stats = require("@lib/main/interfaces/gametabs/stats")

print(Stats.level(Stats.Skill.Herblore))
```

## Stats.total_experience

Definition:
```luau
function Stats.total_experience(skills: { Skill }?): number?
```
Sum of `xp` over the given skills; nil when given nil.

Example:
```luau
local Host = require("@lib/host")
local Stats = require("@lib/main/interfaces/gametabs/stats")

print(Stats.total_experience(Host.game_state().skills))
```

## Stats.total_level

Definition:
```luau
function Stats.total_level(skills: { Skill }?): number?
```
Sum of `real_level` over the given skills; nil when given nil.

Example:
```luau
local Host = require("@lib/host")
local Stats = require("@lib/main/interfaces/gametabs/stats")

print(Stats.total_level(Host.game_state().skills))
```

## Stats.get

Definition:
```luau
function Stats.get(name: string): Skill?
```
One skill by name; nil when unknown.

Example:
```luau
local Stats = require("@lib/main/interfaces/gametabs/stats")

local mining = Stats.get("Mining")
print(mining and mining.xp)
```

## Stats.level

Definition:
```luau
function Stats.level(name: string): number?
```
Current level including boosts and drains.

Example:
```luau
local Stats = require("@lib/main/interfaces/gametabs/stats")

print(Stats.level("Strength"))
```

## Stats.real_level

Definition:
```luau
function Stats.real_level(name: string): number?
```
Base level, ignoring boosts and drains.

Example:
```luau
local Stats = require("@lib/main/interfaces/gametabs/stats")

print(Stats.real_level("Strength"))
```

## Stats.xp

Definition:
```luau
function Stats.xp(name: string): number?
```
The skill's experience.

Example:
```luau
local Stats = require("@lib/main/interfaces/gametabs/stats")

print(Stats.xp("Mining"))
```

## Stats.hover

Definition:
```luau
function Stats.hover(name: string): boolean
```
Opens the stats tab and moves the mouse over a `CHILDREN` key's box (`"total"` included). False for an unknown name or a missing or hidden box.

Example:
```luau
local Stats = require("@lib/main/interfaces/gametabs/stats")

Stats.hover("Fishing")
```

## Stats.hover_async

Definition:
```luau
function Stats.hover_async(name: string): boolean
```
`hover` queued as async input; returns at once. False for an unknown name or missing box.

Example:
```luau
local Stats = require("@lib/main/interfaces/gametabs/stats")

Stats.hover_async("Fishing")
```
