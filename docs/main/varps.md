# Main.Varps

Read the game's player variables ("varps"): run toggle, special attack, poison and so on.

```luau
local Varps = require("@lib/main/varps")
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
Common varp ids.

## Varps.get

Definition:
```luau
function Varps.get(id: number): number?
```
One varp's value, or `nil` when unavailable.

Example:
```luau
local Varps = require("@lib/main/varps")

print("run toggle:", Varps.get(Varps.RUN))
```

## Varps.all

Definition:
```luau
function Varps.all(): { [number]: number }?
```
Every varp, keyed by id from 0, or `nil` when unavailable.

Example:
```luau
local Varps = require("@lib/main/varps")

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
The varps whose value differs in `after`, for finding which varp a button controls.

Example:
```luau
local Host = require("@lib/host")
local Varps = require("@lib/main/varps")

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
Maps the `POISON` value: `>= 1000000` `"envenomed"`, `> 0` `"poisoned"`, else `"healthy"`.

Example:
```luau
local Varps = require("@lib/main/varps")

print(Varps.poison_state(Varps.get(Varps.POISON) or 0))
```
