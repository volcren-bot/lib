# Main.Quests

## Quests.load

Definition:
```luau
function Quests.load(): boolean
```
Reads the quest status script and the quest progress script it calls from the client's cache, then every quest's database row, and keeps them for the rest of the run. True when that worked. A failure is remembered, so a cache that isn't shaped as expected is tried once. It runs on the first question and takes about 0.1 s.

Example:
```luau
local Quests = require("@lib/main/quests")

print(Quests.load())
```

## Quests.state

Definition:
```luau
function Quests.state(name: string): State?
```
A quest's state by name (as the quest list shows it, any case): `complete`, `started` or `not_started`. It reads the quest's varp or varbit and compares it with the row's not-started and finished values, the way the game does. Nil when the cache can't be read, the quest isn't known, or the variable can't be read.

Example:
```luau
local Quests = require("@lib/main/quests")

print(Quests.state("The Ides of Milk"))
```

## Quests.is_complete

Definition:
```luau
function Quests.is_complete(name: string): boolean
```
Whether the quest is complete.

Example:
```luau
local Quests = require("@lib/main/quests")

print(Quests.is_complete("Cook's Assistant"))
```

## Quests.names

Definition:
```luau
function Quests.names(): { string }
```
The name of every quest the cache lists, sorted. Includes miniquests, and quests the quest list may not show.

Example:
```luau
local Quests = require("@lib/main/quests")

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
local Quests = require("@lib/main/quests")

Quests.reload()
```

## Quests.complete_by_varbit

Definition:
```luau
function Quests.complete_by_varbit(id: number): boolean?
```
Whether the quest whose progress is held by the varbit `id` is complete, or nil when no quest keeps its progress there (or the cache can't be read). The transport data names a varbit in some notes, like `varbit:217` for the Port Phasmatys barriers.

Example:
```luau
local Quests = require("@lib/main/quests")

print(Quests.complete_by_varbit(217))
```
