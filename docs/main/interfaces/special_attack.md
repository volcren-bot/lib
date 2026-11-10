# Main.Interfaces.SpecialAttack

The special attack orb on the minimap and the special attack bar on the Combat tab: whether the weapon in your hands has a special attack, how much energy you have, and switching it on for the next attack.

```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")
```

The orb is hidden while the weapon has no special attack, and so is the bar, so `available` also tells you whether the weapon has one. The bar only shows while the Combat tab is open, and the orb not at all when the minimap orbs are turned off in the game's settings. The energy and the switch are read from the game (`Player.special_attack`, `Player.special_attack_enabled`), so they work with any tab open.

**Costs.** A weapon's special attack cost comes from a table in the game's cache, enum `COST_ENUM`: item id to the energy it drains in tenths of a percent (Dragon claws 500, the Crystal halberd 300, the Saradomin sword 1000). It is read once and kept, so the cost is known before the weapon is ever wielded, with nothing learned or assumed. A weapon the table leaves out has no special attack, and `cost` gives nil for it. Every wieldable variant checked (those of the Granite maul and the Abyssal tentacle) has its own entry, and every item with a special attack description (enum 1739) has a cost; noted copies and placeholders have none. A handful of entries aren't a plain drain: shields that spend charges are 0, and a few weapons with special attacks that work differently have small values (the Soulreaper axe 1, the Lithic sceptre 5, the Sunlight spear 7, the Rondache 10), which `cost` passes on as 0.1% to 1%.

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
The orb's interface, the children that can be its button (the first showing one is clicked), the menu option it has and how long `set` waits for the switch to change; the Combat tab's interface, the bar's button and its menu option, and how often `set` uses the bar instead of the orb (through `Biometrics.random_boolean`); the worn items container and slot the weapon is read from, and the cache table of special attack costs with the scale of its values (300 is 30%).

## SpecialAttack.orb

Definition:
```luau
function SpecialAttack.orb(): (Widget?, number?)
```
The orb's button and its child number, or `nil` when it isn't showing.

Example:
```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")

print(SpecialAttack.orb())
```

## SpecialAttack.bar

Definition:
```luau
function SpecialAttack.bar(): Widget?
```
The Combat tab's special attack bar, or `nil` when it isn't showing (the tab is closed, or the weapon has no special attack).

Example:
```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")

print(SpecialAttack.bar())
```

## SpecialAttack.available

Definition:
```luau
function SpecialAttack.available(): boolean
```
Whether the weapon in your hands has a special attack: the orb or the bar is showing.

Example:
```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")

print("special attack:", SpecialAttack.available())
```

## SpecialAttack.energy

Definition:
```luau
function SpecialAttack.energy(): number?
```
Your special attack energy from 0 to 100.

Example:
```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")

print("energy:", SpecialAttack.energy())
```

## SpecialAttack.weapon

Definition:
```luau
function SpecialAttack.weapon(): number?
```
The item id in the weapon slot, or `nil` when the hands are empty.

Example:
```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")

print("weapon:", SpecialAttack.weapon())
```

## SpecialAttack.cost

Definition:
```luau
function SpecialAttack.cost(weapon: number?): number?
```
What a weapon's special attack costs, in percent, from the cache table: `weapon`, or the one in hand when `nil`. Nil for a weapon without a special attack, with no weapon in hand, or when the cache can't be read.

Example:
```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")

print("costs:", SpecialAttack.cost())
```

## SpecialAttack.is_enabled

Definition:
```luau
function SpecialAttack.is_enabled(): boolean
```
Whether the special attack is switched on for the next attack.

Example:
```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")

print("on:", SpecialAttack.is_enabled())
```

## SpecialAttack.set

Definition:
```luau
function SpecialAttack.set(enabled: boolean): boolean
```
Switches the special attack on or off and waits for it to change. Does nothing if it is so already. It clicks the Combat tab's bar (opening the tab first) `BAR_CHANCE` of the time, biometrically, and the orb otherwise; when the one it picked isn't there (the orb turned off, the tab won't open) it uses the other. Returns `false` when the weapon has none or the switch didn't change.

Example:
```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")

SpecialAttack.set(true)
```

## SpecialAttack.enable

Definition:
```luau
function SpecialAttack.enable(cost: number?): boolean
```
Switches the special attack on when there is at least `cost` energy, by default the cost of the weapon in hand (`cost()`). Returns `true` when it is on, and `false` without clicking when there isn't enough energy or the weapon has no special attack.

Example:
```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")

if SpecialAttack.enable() then
	print("the next attack is a special attack")
end
```
