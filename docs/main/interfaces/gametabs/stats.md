# Main.Interfaces.Gametabs.Stats

Your skill levels and experience.

```luau
local Stats = require("../main/interfaces/gametabs/stats")
```

Skills are looked up by name (not case sensitive), like `"Mining"` or `"Hitpoints"`. A skill has `name`, `level` (current, including boosts), `real_level` and `xp`.

## Stats.total_experience

Definition:
```luau
function Stats.total_experience(skills: { Skill }?): number?
```
The sum of the experience of all the skills in the list you give it.

Example:
```luau
local Host = require("../host")
local Stats = require("../main/interfaces/gametabs/stats")

local state = Host.game_state()
print(Stats.total_experience(state and state.skills))
```

## Stats.total_level

Definition:
```luau
function Stats.total_level(skills: { Skill }?): number?
```
The sum of the real levels of all the skills in the list you give it.

Example:
```luau
local Host = require("../host")
local Stats = require("../main/interfaces/gametabs/stats")

local state = Host.game_state()
print(Stats.total_level(state and state.skills))
```

## Stats.get

Definition:
```luau
function Stats.get(name: string): Skill?
```
One skill, with all its numbers.

Example:
```luau
local Stats = require("../main/interfaces/gametabs/stats")

local mining = Stats.get("Mining")
if mining then
	print(mining.level, mining.real_level, mining.xp)
end
```

## Stats.level

Definition:
```luau
function Stats.level(name: string): number?
```
The current level of a skill, including any boost or drain.

Example:
```luau
local Stats = require("../main/interfaces/gametabs/stats")

print("current strength:", Stats.level("Strength"))
```

## Stats.real_level

Definition:
```luau
function Stats.real_level(name: string): number?
```
The real level of a skill, ignoring boosts and drain.

Example:
```luau
local Stats = require("../main/interfaces/gametabs/stats")

print("real strength:", Stats.real_level("Strength"))
```

## Stats.xp

Definition:
```luau
function Stats.xp(name: string): number?
```
The experience of a skill.

Example:
```luau
local Stats = require("../main/interfaces/gametabs/stats")

print("mining xp:", Stats.xp("Mining"))
```

## Stats.hover

Definition:
```luau
function Stats.hover(name: string): boolean
```
Opens the stats tab and moves the mouse over a skill's box (`"total"` is the box under them). The names are the keys of `Stats.CHILDREN`, which maps each skill to its child of the tab's group (`Stats.GROUP`, 320): 1 to 24 in columns, attack to sailing. Returns nil and a reason for an unknown name or when the box isn't there.

Example:
```luau
local Stats = require("../main/interfaces/gametabs/stats")

print(Stats.hover("Fishing"))
```

## Stats.hover_async

Definition:
```luau
function Stats.hover_async(name: string): boolean
```
Like `Stats.hover`, but queues opening the tab and moving over the skill's box as async input and returns at once. Returns `false` for an unknown name or when the box isn't there.

Example:
```luau
local Stats = require("../main/interfaces/gametabs/stats")

print(Stats.hover_async("Fishing"))
```
