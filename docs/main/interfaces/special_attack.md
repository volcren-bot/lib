# Main.Interfaces.SpecialAttack

The special attack orb on the minimap and the special attack bar on the Combat tab: whether the weapon in your hands has a special attack, how much energy you have, and switching it on for the next attack.

```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")
```

The orb is hidden while the weapon has no special attack, and so is the bar, so `available` also tells you whether the weapon has one. The bar only shows while the Combat tab is open, and the orb not at all when the minimap orbs are turned off in the game's settings. The energy and the switch are read from the game (`Player.special_attack`, `Player.special_attack_enabled`), so they work with any tab open.

**Learned costs.** The lib doesn't know what each weapon's special attack costs: it learns it. A weapon it hasn't seen is taken to cost `FULL` (100), so `enable` waits for a full bar. Once `enable` has switched it on, the next drop of the energy while that weapon is in hand is kept as its cost (`update` each loop, or `wait_used` to block until it happens), rounded to a whole percent, so the next `enable` with that weapon needs only what it really drains (anything that changes what it drains is learned as it is). The costs live for the run: a new run starts from `FULL` again.

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
SpecialAttack.FULL = 100
SpecialAttack.USE_TIMEOUT_MS = 3000
SpecialAttack.WORN = 94
SpecialAttack.WEAPON_SLOT = 3
```
The orb's interface, the children that can be its button (the first showing one is clicked), the menu option it has and how long `set` waits for the switch to change; the Combat tab's interface, the bar's button and its menu option, and how often `set` uses the bar instead of the orb (through `Biometrics.random_boolean`); the cost taken for a weapon not learned yet, how long `wait_used` waits for the energy to drop, and the worn items container and slot the weapon is read from.

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
function SpecialAttack.cost(weapon: number?): number
```
What a weapon's special attack costs, in percent: the learned cost of `weapon` (the one in hand when `nil`), or `FULL` when it hasn't been learned.

Example:
```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")

print("costs:", SpecialAttack.cost())
```

## SpecialAttack.known

Definition:
```luau
function SpecialAttack.known(weapon: number?): boolean
```
Whether the cost of `weapon` (the one in hand when `nil`) has been learned this run.

Example:
```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")

print("learned:", SpecialAttack.known())
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
Switches the special attack on when there is at least `cost` energy, by default the weapon's `cost()`: what it was learned to drain, or `FULL` before that. Returns `true` when it is on, and from then on watches the energy for `update` and `wait_used` to learn the cost from.

Example:
```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")

if SpecialAttack.enable() then
	print("the next attack is a special attack")
end
```

## SpecialAttack.update

Definition:
```luau
function SpecialAttack.update(): boolean
```
Checks, without waiting, whether the special attack `enable` switched on has been used: when the energy has dropped while the same weapon is in hand, keeps the drop as its cost and returns `true`. Energy that comes back meanwhile raises the mark it is measured from. Call it once per loop when the attack can go off ticks after the switch (a weapon swap delays it). Returns `false` while nothing is being watched or the energy hasn't dropped.

Example:
```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")

if SpecialAttack.update() then
	print("used it: it costs", SpecialAttack.cost())
end
```

## SpecialAttack.wait_used

Definition:
```luau
function SpecialAttack.wait_used(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (default `USE_TIMEOUT_MS`) for `update` to see the special attack used. When `enable` didn't switch it on, the energy is read when it starts. Returns `false`, learning nothing, when the energy didn't drop in time.

Example:
```luau
local SpecialAttack = require("@lib/main/interfaces/special_attack")

if SpecialAttack.enable() then
	-- click Attack on the target here
	SpecialAttack.wait_used()
	print("it costs", SpecialAttack.cost())
end
```
