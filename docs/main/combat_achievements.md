# Main.CombatAchievements

Which combat achievement tiers the account has reached, and which it has claimed the rewards of. The game keeps one status varbit per tier (`ca_tier_status_easy` to `ca_tier_status_grandmaster`), so there is nothing to load and no tab to open. Its own scripts treat 2 as claimed (script 6931) and anything above 0 as reached (script 10255).

```luau
local CombatAchievements = require("@lib/main/combat_achievements")
```

A tier's perks, like the Master tier's longer thralls, need its rewards claimed from Ghommal, not only the points: use `is_claimed` for those.

## Constants

Definition:
```luau
CombatAchievements.TIERS = { "easy", "medium", "hard", "elite", "master", "grandmaster" }
CombatAchievements.STATUS_VARBITS = { easy = 12863, medium = 12864, hard = 12865, elite = 12866, master = 12867, grandmaster = 12868 }
CombatAchievements.NOT_REACHED = 0
CombatAchievements.REACHED = 1
CombatAchievements.CLAIMED = 2
```
The tiers from lowest to highest (the `Tier` type), each tier's status varbit, and what a status means.

## CombatAchievements.status

Definition:
```luau
function CombatAchievements.status(tier: Tier): number?
```
A tier's status: `NOT_REACHED`, `REACHED` or `CLAIMED`. Nil when it can't be read.

Example:
```luau
local CombatAchievements = require("@lib/main/combat_achievements")

print(CombatAchievements.status("master"))
```

## CombatAchievements.is_reached

Definition:
```luau
function CombatAchievements.is_reached(tier: Tier): boolean
```
Whether the account has the points for the tier, its rewards claimed or not.

Example:
```luau
local CombatAchievements = require("@lib/main/combat_achievements")

print(CombatAchievements.is_reached("hard"))
```

## CombatAchievements.is_claimed

Definition:
```luau
function CombatAchievements.is_claimed(tier: Tier): boolean
```
Whether the tier's rewards are claimed.

Example:
```luau
local CombatAchievements = require("@lib/main/combat_achievements")

print(CombatAchievements.is_claimed("master"))
```

## CombatAchievements.highest_claimed

Definition:
```luau
function CombatAchievements.highest_claimed(): Tier?
```
The highest tier whose rewards are claimed, nil for none.

Example:
```luau
local CombatAchievements = require("@lib/main/combat_achievements")

print(CombatAchievements.highest_claimed() or "none")
```
