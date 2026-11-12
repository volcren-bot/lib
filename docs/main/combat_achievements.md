# Main.CombatAchievements

Combat achievement tiers reached and claimed, from one status varbit per tier (no tab needed). Perks such as the Master tier's longer thralls need the rewards claimed from Ghommal: check `is_claimed`.

```luau
local CombatAchievements = require("@lib/main/combat_achievements")
```

## Constants

Definition:
```luau
CombatAchievements.TIERS = { "easy", "medium", "hard", "elite", "master", "grandmaster" }
CombatAchievements.STATUS_VARBITS = { easy = 12863, medium = 12864, hard = 12865, elite = 12866, master = 12867, grandmaster = 12868 }
CombatAchievements.NOT_REACHED = 0
CombatAchievements.REACHED = 1
CombatAchievements.CLAIMED = 2
```
Tiers lowest to highest (the `Tier` type), each tier's status varbit, and the status values; reached is any status at or above `REACHED`.

## CombatAchievements.status

Definition:
```luau
function CombatAchievements.status(tier: Tier): number?
```
`NOT_REACHED`, `REACHED` or `CLAIMED`; nil when the varbit can't be read.

Example:
```luau
print(CombatAchievements.status("master"))
```

## CombatAchievements.is_reached

Definition:
```luau
function CombatAchievements.is_reached(tier: Tier): boolean
```
Whether the tier's points are reached, claimed or not.

Example:
```luau
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
print(CombatAchievements.is_claimed("master"))
```

## CombatAchievements.highest_claimed

Definition:
```luau
function CombatAchievements.highest_claimed(): Tier?
```
The highest claimed tier, nil for none.

Example:
```luau
print(CombatAchievements.highest_claimed() or "none")
```
