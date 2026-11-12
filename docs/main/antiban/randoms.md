# Main.Antiban.Randoms

Handles random events: NPCs that appear next to the player and try to interact. An NPC counts only when its `interacting_player` is your own player index. Scripts usually register [`Tasks.handle_randoms`](antiban_tasks.md#taskshandle_randoms) rather than calling this directly. To support an event, add its NPC id to `Randoms.HANDLERS`.

```luau
local Randoms = require("@lib/main/antiban/randoms")
```

Handled events:

- **Genie**: `Talk-to`, continue any dialogue, wait for the lamp, then `use_lamps`.
- **Certers** (Niles, Miles, Giles): open the quiz and answer it with `Certer.solve`; if no answer fits, it is closed unanswered and logged.
- **Dunce**: accept the exam (`SurpriseExam.accept`); `handle` finishes an exam already under way first (`SurpriseExam.complete`), then `use_lamps` on the Book of Knowledge.

Lamps can't be banked and break deposit-all restocks, so lamp events always spend them on the skill set on the loader's Accounts page. `handle` has only run against a stubbed game; events can't be triggered on demand.

## Constants

Definition:

```luau
Randoms.GENIE = 326
Randoms.GENIE_LAMP = 2528
Randoms.GENIE_OPTION = "Talk-to"
Randoms.NILES = 5436
Randoms.MILES = 5437
Randoms.GILES = 5438
Randoms.GENIE_TIMEOUT_MS = 8000
Randoms.GENIE_SETTLE_MS = 600
Randoms.POLL_MS = 100
Randoms.LAMP_WAIT_MS = 3000
Randoms.LAMP_ATTEMPTS = 3
```

NPC and item ids; the genie's lamp timeout and settle time after it arrives; the poll interval; the wait for a lamp to appear or leave the inventory; and consecutive failed tries before a lamp is kept.

Example:

```luau
print(Randoms.GENIE)
```

## Randoms.HANDLERS

Definition:

```luau
export type Handler = (npc: Npc) -> boolean
Randoms.HANDLERS: { [number]: Handler }
```

Event handlers by NPC id. A handler returns true when the event was dealt with.

Example:

```luau
Randoms.HANDLERS[1234] = function(npc)
	return Npcs.interact(npc, "Dismiss")
end
```

## Randoms.LAMP_EVENTS

Definition:

```luau
Randoms.LAMP_EVENTS: { [number]: boolean }
```

NPC ids whose reward is a lamp (genie, Dunce). `handle` runs `use_lamps` after one is dealt with.

Example:

```luau
print(Randoms.LAMP_EVENTS[Randoms.GENIE])
```

## Randoms.find

Definition:

```luau
function Randoms.find(): Npc?
```

The first known event NPC interacting with you, or nil. One NPC read; cheap to call often.

Example:

```luau
local npc = Randoms.find()
```

## Randoms.handle

Definition:

```luau
function Randoms.handle(): boolean
```

Finishes an exam in progress, or handles the event interacting with you, spending lamps afterwards for lamp events. Returns true when one was dealt with.

Example:

```luau
Randoms.handle()
```

## Randoms.lamp_skill

Definition:

```luau
function Randoms.lamp_skill(): Stats.SkillName?
```

The skill set for lamps on the loader's Accounts page. Nil (and logged) when unset, unknown, or the loader can't say.

Example:

```luau
print(Randoms.lamp_skill())
```

## Randoms.use_lamps

Definition:

```luau
function Randoms.use_lamps(): boolean
```

Waits up to `LAMP_WAIT_MS` for a lamp (any of `Lamp.NAMES`), then spends every one held on `lamp_skill`, waiting for each to leave the inventory. Returns true when none is left; false when no skill is set or one failed `LAMP_ATTEMPTS` times in a row.

Example:

```luau
if not Randoms.use_lamps() then
	print("a lamp is still held")
end
```
