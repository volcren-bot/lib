# Main.Interfaces.Gametabs.Journal

Quest and achievement diary progress. Answers come from [Quests](../../quests.md) and [Diaries](../../diaries.md) (game scripts and varbits, no tab) when they can; otherwise from the journal tab's Quest List (name colours) and Achievement Diaries pages, cached for `CACHE_MS`.

```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")
```

## Constants

Definition:
```luau
Journal.GROUP = 629
Journal.QUEST_BUTTON = 10
Journal.DIARY_BUTTON = 18
Journal.QUEST_GROUP = 399
Journal.QUEST_ROWS = 7
Journal.DIARY_GROUP = 259
Journal.DIARY_ROWS = 2
Journal.COMPLETE_COLOR = 0x0DC10D
Journal.STARTED_COLOR = 0xFFFF00
Journal.NOT_STARTED_COLOR = 0xFF0000
Journal.CACHE_MS = 60 * 1000
Journal.TIERS = { "easy", "medium", "hard", "elite" }
```
The tab, its page buttons, the quest and diary row layers, the quest state colours, the page cache lifetime and the diary tiers.

## Journal.refresh_quests

Definition:
```luau
function Journal.refresh_quests(): boolean
```
Reads every quest's state from its row colour into the cache. The rows stay loaded while another tab shows, so this clicks nothing unless the Quest List isn't loaded yet. False when the page can't be opened. Folded sub-quests are left out.

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

Journal.refresh_quests()
```

## Journal.quest

Definition:
```luau
export type QuestState = "complete" | "started" | "not_started"
function Journal.quest(name: string): QuestState?
```
A quest's state by name, from `Quests.state`, falling back to the Quest List (refreshed when older than `CACHE_MS`). Nil when unknown or unreadable.

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

print(Journal.quest("Cook's Assistant"))
```

## Journal.is_quest_complete

Definition:
```luau
function Journal.is_quest_complete(name: string): boolean
```
Whether the quest is complete; false when unreadable.

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

print(Journal.is_quest_complete("Desert Treasure I"))
```

## Journal.completed_quests

Definition:
```luau
function Journal.completed_quests(): { string }
```
Lowercase names of every complete quest, from `Quests` in its order, or sorted from the Quest List when `Quests` has no names.

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

print(#Journal.completed_quests())
```

## Journal.refresh_diaries

Definition:
```luau
function Journal.refresh_diaries(): boolean
```
Opens the Achievement Diaries page and caches each region's done/total task count. False when it can't be opened or read.

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

Journal.refresh_diaries()
```

## Journal.diaries

Definition:
```luau
export type Diary = { name: string, done: number, total: number, complete: boolean }
function Journal.diaries(): { Diary }?
```
Every diary region, from `Diaries` (names are the capitalised first word, like `Kourend`), falling back to the Achievement Diaries page. Nil when neither works.

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

for _, d in ipairs(Journal.diaries() or {}) do
	print(d.name, d.done, d.total)
end
```

## Journal.diary

Definition:
```luau
function Journal.diary(name: string): Diary?
```
One region, matched by its first word case-insensitively ("Kourend & Kebos" works).

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

local d = Journal.diary("Varrock")
print(d and d.complete)
```

## Journal.forget

Definition:
```luau
function Journal.forget()
```
Clears the page caches so the next fallback reads the tab again.

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

Journal.forget()
```

## Journal.diary_tier

Definition:
```luau
function Journal.diary_tier(region: string, tier: string): boolean?
```
Whether a tier ("easy", "medium", "hard", "elite") of a region is done, via `Diaries.tier`; no tab needed. Nil for an unknown region or tier.

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

print(Journal.diary_tier("Kandarin", "elite"))
```

## Journal.is_diary_complete

Definition:
```luau
function Journal.is_diary_complete(region: string): boolean?
```
Whether all four tiers are done, via `Diaries.complete`. Nil for an unknown region.

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

print(Journal.is_diary_complete("Varrock"))
```
