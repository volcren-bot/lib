# Main.Interfaces.Gametabs.Journal

## Journal.refresh_quests

Definition:
```luau
function Journal.refresh_quests(): boolean
```
Reads every quest's state from the colour of its name in the Quest List rows. The rows stay in memory with their colours while another tab is showing, so this clicks nothing; only when the page isn't loaded yet does it open the journal tab on the Quest List first (green complete, yellow started, red not started). False when the page can't be opened. Folded-away sub-quests (the parts of Recipe for Disaster) aren't shown and are left out.

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

print(Journal.refresh_quests())
```

## Journal.quest

Definition:
```luau
function Journal.quest(name: string): QuestState?
```
A quest's state by name (any case), `"complete"`, `"started"` or `"not_started"`, or nil when it isn't listed or the list can't be read. Reads the tab if nothing is cached or the cache is older than `Journal.CACHE_MS` (1 minute).

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
Whether the quest is complete. False when it can't be read.

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
Every complete quest, by the name the list shows (lowercase), sorted.

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
Opens the Achievement Diaries page and reads how many tasks are done in each region. False when it can't be opened. `Journal.diaries()` only uses this when the cache can't be read; `Diaries` gives the same numbers, and per tier, without the page.

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

print(Journal.refresh_diaries())
```

## Journal.diaries

Definition:
```luau
function Journal.diaries(): { Diary }?
```
Every diary region as `{ name, done, total, complete }`, read from the game's own scripts and varbits (no tab; the names are then the first word, like `Kourend`), or from the Achievement Diaries page when that fails. Nil when neither works.

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

for _, d in ipairs(Journal.diaries() or {}) do print(d.name, d.done, d.total) end
```

## Journal.diary

Definition:
```luau
function Journal.diary(name: string): Diary?
```
One region by name ("Varrock", "Kourend & Kebos"), any case.

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

print(Journal.diary("Varrock").complete)
```

## Journal.forget

Definition:
```luau
function Journal.forget()
```
Forgets what was read, so the next question reads the tab again.

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
Whether a tier ("easy", "medium", "hard" or "elite") of a region's achievement diary is done, or nil for an unknown region or tier. Read from the game's own scripts and varbits through `Diaries`, so it needs no tab. The region is matched by its first word, so "Kourend & Kebos" and "Western Provinces" work.

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
Whether all four tiers of a region's diary are done, or nil for an unknown region. Needs no tab (see `Diaries`).

Example:
```luau
local Journal = require("@lib/main/interfaces/gametabs/journal")

print(Journal.is_diary_complete("Varrock"))
```
