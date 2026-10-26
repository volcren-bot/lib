# Main.Varps

Named access to the game's saved settings ("varps"): run toggle, special attack, poison and so on.

```luau
local Varps = require("../main/varps")
```

## Constants

Definition:
```luau
Varps.ATTACK_STYLE = 43
Varps.ACTIVE_PRAYERS = 83
Varps.QUEST_POINTS = 101
Varps.POISON = 102
Varps.RUN = 173
Varps.TUTORIAL_PROGRESS = 281
Varps.SPECIAL_ATTACK = 300
Varps.SPECIAL_ATTACK_ENABLED = 301
Varps.SLAYER_TASK_SIZE = 394
Varps.SLAYER_TASK_CREATURE = 395
Varps.LAST_HOME_TELEPORT = 892
```
The ids of a few commonly used settings.

## Varps.get

Definition:
```luau
function Varps.get(id: number): number?
```
Reads one setting.

Example:
```luau
local Varps = require("../main/varps")

print("run toggle:", Varps.get(Varps.RUN))
```

## Varps.all

Definition:
```luau
function Varps.all(): { [number]: number }?
```
Reads every setting at once, as a table keyed by id.

Example:
```luau
local Varps = require("../main/varps")

local all = Varps.all()
if all then
	print("special attack:", all[Varps.SPECIAL_ATTACK])
end
```

## Varps.changes

Definition:
```luau
function Varps.changes(
	before: { [number]: number },
	after: { [number]: number }
): { [number]: { before: number?, after: number } }
```
Compares two snapshots from `Varps.all` and returns only the settings that changed. Useful to discover which setting a button controls.

Example:
```luau
local Host = require("../host")
local Varps = require("../main/varps")

local before = assert(Varps.all())
print("change something in the game, you have 5 seconds")
Host.sleep(5000)
local after = assert(Varps.all())
for id, change in pairs(Varps.changes(before, after)) do
	print(id, change.before, "->", change.after)
end
```

## Varps.poison_state

Definition:
```luau
function Varps.poison_state(value: number): string
```
Turns the poison setting's value into `"healthy"`, `"poisoned"` or `"envenomed"`.

Example:
```luau
local Varps = require("../main/varps")

print(Varps.poison_state(Varps.get(Varps.POISON) or 0))
```
