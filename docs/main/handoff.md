# Main.Handoff

What a queueable script does at the edges of a queue entry: notice that the loader wants it to wrap up, leave the account settled, and say why it ended. A queueable script starts from any safe idle state, so the next one can take over from wherever this one stops.

```luau
local Handoff = require("@lib/main/handoff")
```

## Constants

Definition:
```luau
Handoff.COMBAT_TIMEOUT_MS = 30000
```
- `COMBAT_TIMEOUT_MS`: how long `settle` waits to drop out of combat.

## Handoff.finishing

Definition:
```luau
function Handoff.finishing(): boolean
```
True once the queue asked the script to wrap up ([Host.finish_requested](../host.md)). Check it between units of work (a kill, a bank trip, a round), never in the middle of one.

Example:
```luau
while not Handoff.finishing() do
	-- one unit of work
end
```

## Handoff.done

Definition:
```luau
function Handoff.done(reason: string?)
```
Reports a clean end; `reason` is logged. Returning without it counts the same.

Example:
```luau
Handoff.done("reached the goal")
```

## Handoff.blocked

Definition:
```luau
function Handoff.blocked(reason: string)
```
Reports that the script can't go on but left the account safe; the queue moves to its next entry. Call it, then return.

Example:
```luau
Handoff.blocked("out of food")
return
```

## Handoff.settle

Definition:
```luau
function Handoff.settle(timeout_ms: number?): (boolean, string?)
```
Cancels queued input, logs in if needed, closes the open interface and waits up to `timeout_ms` (default `COMBAT_TIMEOUT_MS`) to be out of combat. Leaving an instance or a minigame is the script's own job before this. Returns false and why when the account isn't settled.

Example:
```luau
local settled, why = Handoff.settle()
if not settled then
	error(why, 0)
end
```
