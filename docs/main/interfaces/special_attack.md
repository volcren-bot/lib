# Main.Interfaces.SpecialAttack

The special attack orb (minimap) and bar (Combat tab): energy, cost and toggling.

```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")
```

The orb shows whatever the weapon, so it can't tell whether the weapon has a special attack: use `cost`. The bar is hidden for weapons without one and shows only with the Combat tab open; the orb not at all when minimap orbs are off. Energy and the toggle come from `Player.special_attack`/`Player.special_attack_enabled`, so they work with any tab open. Costs come from cache enum `COST_ENUM` (item id to drain in tenths of a percent), read once; a weapon missing from it has no special attack. A few entries aren't plain drains (charge shields 0; some weapons 1 to 10, which `cost` returns as 0.1% to 1%).

## Constants

Definition:
```luau
SpecialAttack.GROUP = 160
SpecialAttack.ORBS = { 36, 35, 34 }
SpecialAttack.OPTION = "Use"
SpecialAttack.TOGGLE_TIMEOUT_MS = 1500
SpecialAttack.BAR_GROUP = 593
SpecialAttack.BAR = 41
SpecialAttack.BAR_OPTION = "Use Special Attack"
SpecialAttack.BAR_CHANCE = 0.5
SpecialAttack.WORN = 94
SpecialAttack.WEAPON_SLOT = 3
SpecialAttack.COST_ENUM = 906
SpecialAttack.COST_SCALE = 10
```
- `GROUP`, `ORBS`, `OPTION`: orb interface, candidate children (first showing wins), menu option.
- `TOGGLE_TIMEOUT_MS`: how long `set` waits for the toggle.
- `BAR_GROUP`, `BAR`, `BAR_OPTION`: Combat tab bar widget and option.
- `BAR_CHANCE`: biometric chance `set` uses the bar instead of the orb.
- `WORN`, `WEAPON_SLOT`: container and slot the weapon is read from.
- `COST_ENUM`, `COST_SCALE`: cost table and its scale (300 is 30%).

## SpecialAttack.orb

Definition:
```luau
function SpecialAttack.orb(): (Widget?, number?)
```
The orb button and its child, nil when hidden.

Example:
```luau
print(SpecialAttack.orb())
```

## SpecialAttack.bar

Definition:
```luau
function SpecialAttack.bar(): Widget?
```
The Combat tab bar, nil when the tab is closed or the weapon has no special.

Example:
```luau
print(SpecialAttack.bar())
```

## SpecialAttack.energy

Definition:
```luau
function SpecialAttack.energy(): number?
```
Special attack energy, 0 to 100.

Example:
```luau
print(SpecialAttack.energy())
```

## SpecialAttack.weapon

Definition:
```luau
function SpecialAttack.weapon(): number?
```
Item id in the weapon slot, nil when empty.

Example:
```luau
print(SpecialAttack.weapon())
```

## SpecialAttack.cost

Definition:
```luau
function SpecialAttack.cost(weapon: number?): number?
```
Special attack cost in percent of `weapon` (default the wielded one). Nil without a special, with no weapon, or when the cache can't be read.

Example:
```luau
print(SpecialAttack.cost())
```

## SpecialAttack.is_enabled

Definition:
```luau
function SpecialAttack.is_enabled(): boolean
```
Whether the special is toggled on for the next attack.

Example:
```luau
print(SpecialAttack.is_enabled())
```

## SpecialAttack.set

Definition:
```luau
function SpecialAttack.set(enabled: boolean): boolean
```
Toggles the special to `enabled` and waits up to `TOGGLE_TIMEOUT_MS`; no-op when already so. Clicks the bar (opening the Combat tab) with `BAR_CHANCE`, else the orb, falling back to the other. `false` when neither is available or it didn't change.

Example:
```luau
SpecialAttack.set(true)
```

## SpecialAttack.enable

Definition:
```luau
function SpecialAttack.enable(cost: number?): boolean
```
`set(true)` when energy is at least `cost` (default `cost()`); `false` without clicking otherwise.

Example:
```luau
if SpecialAttack.enable() then
	print("special queued")
end
```
