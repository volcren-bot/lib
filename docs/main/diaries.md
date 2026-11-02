# Main.Diaries

## Diaries.load

Definition:
```luau
function Diaries.load(): boolean
```
Reads the diary scripts `area_task_complete` (56) and `diary_completion_info` (2200) from the client's cache and names each region from the client's own name for its varbits. Done once and kept for the run; a failure is remembered. Takes about 40 ms.

Example:
```luau
local Diaries = require("@lib/main/diaries")

print(Diaries.load())
```

## Diaries.regions

Definition:
```luau
function Diaries.regions(): { string }
```
The regions the cache lists by key (`ardougne`, `desert`, `falador`, `fremennik`, `kandarin`, `karamja`, `kourend`, `lumbridge`, `morytania`, `varrock`, `western`, `wilderness`), sorted.

Example:
```luau
local Diaries = require("@lib/main/diaries")

print(table.concat(Diaries.regions(), ", "))
```

## Diaries.tier

Definition:
```luau
function Diaries.tier(region: string, tier: string): boolean?
```
Whether a tier (`easy`, `medium`, `hard` or `elite`) of a region is done. The region is matched by its first word, so `Kourend & Kebos` works. Nil for an unknown region or tier, or when it can't be read.

Example:
```luau
local Diaries = require("@lib/main/diaries")

print(Diaries.tier("Kandarin", "elite"))
```

## Diaries.complete

Definition:
```luau
function Diaries.complete(region: string): boolean?
```
Whether all four tiers of a region are done.

Example:
```luau
local Diaries = require("@lib/main/diaries")

print(Diaries.complete("Varrock"))
```

## Diaries.started

Definition:
```luau
function Diaries.started(region: string): boolean?
```
Whether the region's diary has been started.

Example:
```luau
local Diaries = require("@lib/main/diaries")

print(Diaries.started("Falador"))
```

## Diaries.progress

Definition:
```luau
function Diaries.progress(region: string, tier: string?): Progress?
```
Tasks done and tasks in all (`{ done, total }`) for a region, or for one of its tiers when `tier` is given. This is the number the diary page shows (like 42/43). Each count is a varbit read.

Example:
```luau
local Diaries = require("@lib/main/diaries")

local p = Diaries.progress("Kandarin")
print(p and p.done, p and p.total)
```

## Diaries.reload

Definition:
```luau
function Diaries.reload()
```
Forgets what was read, so the next question reads the cache again.

Example:
```luau
local Diaries = require("@lib/main/diaries")

Diaries.reload()
```
