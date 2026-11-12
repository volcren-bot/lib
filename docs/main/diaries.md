# Main.Diaries

Achievement diary progress read from the client's cache and varbits. Regions are matched by the first word of their name, any case (`"Kourend & Kebos"` is `kourend`); tiers are `easy`, `medium`, `hard`, `elite` (`Diaries.TIERS`).

```luau
local Diaries = require("@lib/main/diaries")
```

## Diaries.load

Definition:
```luau
function Diaries.load(): boolean
```
Reads the diary scripts `COMPLETE_SCRIPT` (56) and `INFO_SCRIPT` (2200) from the cache and names each region from its varbit names. Kept for the run; a failure is remembered until `reload`. About 40 ms.

Example:
```luau
print(Diaries.load())
```

## Diaries.regions

Definition:
```luau
function Diaries.regions(): { string }
```
The regions the cache lists by key (`ardougne`, `desert`, `falador`, `fremennik`, `kandarin`, `karamja`, `kourend`, `lumbridge`, `morytania`, `varrock`, `western`, `wilderness`), sorted; empty when the cache can't be read.

Example:
```luau
print(table.concat(Diaries.regions(), ", "))
```

## Diaries.tier

Definition:
```luau
function Diaries.tier(region: string, tier: string): boolean?
```
Whether a region's tier is done. Nil for an unknown region or tier, or when it can't be read.

Example:
```luau
print(Diaries.tier("Kandarin", "elite"))
```

## Diaries.complete

Definition:
```luau
function Diaries.complete(region: string): boolean?
```
Whether all four tiers are done; nil when any tier can't be read.

Example:
```luau
print(Diaries.complete("Varrock"))
```

## Diaries.started

Definition:
```luau
function Diaries.started(region: string): boolean?
```
Whether the region's diary is started; nil when unknown or unreadable.

Example:
```luau
print(Diaries.started("Falador"))
```

## Diaries.progress

Definition:
```luau
function Diaries.progress(region: string, tier: string?): Progress?
```
`{ done, total }` tasks for a region, or one tier when `tier` is given, as the diary page shows it (like 42/43). Nil for an unknown region or tier, or an unreadable count.

Example:
```luau
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
Diaries.reload()
```
