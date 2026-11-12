# Main.Quests

Quest states read from the client's cache and quest variables. Everything loads lazily on first use.

```luau
local Quests = require("@lib/main/quests")
```

## Quests.load

Definition:
```luau
function Quests.load(): boolean
```
Reads the quest status script (`STATUS_SCRIPT`, 4029), the progress script it calls and every quest's database row from the cache, kept for the run. True on success; a failure is remembered until `reload`. Runs on first use, about 0.1 s.

Example:
```luau
print(Quests.load())
```

## Quests.state

Definition:
```luau
function Quests.state(name: string): State?
```
`complete`, `started` or `not_started` for a quest by its quest-list name (any case), from its varp or varbit as the game compares it. Nil when the cache or variable can't be read or the quest is unknown.

Example:
```luau
print(Quests.state("The Ides of Milk"))
```

## Quests.is_complete

Definition:
```luau
function Quests.is_complete(name: string): boolean
```
Whether the quest is complete; false when unknown.

Example:
```luau
print(Quests.is_complete("Cook's Assistant"))
```

## Quests.names

Definition:
```luau
function Quests.names(): { string }
```
Every quest name in the cache, sorted, including miniquests; empty when the cache can't be read.

Example:
```luau
print(#Quests.names())
```

## Quests.reload

Definition:
```luau
function Quests.reload()
```
Forgets what was read, so the next question reads the cache again.

Example:
```luau
Quests.reload()
```

## Quests.complete_by_varbit

Definition:
```luau
function Quests.complete_by_varbit(id: number): boolean?
```
Whether the quest tracked by varbit `id` is complete; nil when no quest uses it or the cache can't be read. Used for transport notes like `varbit:217`.

Example:
```luau
print(Quests.complete_by_varbit(217))
```
