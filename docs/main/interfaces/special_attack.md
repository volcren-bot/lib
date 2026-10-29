# Main.Interfaces.SpecialAttack

The special attack orb on the minimap: whether the weapon in your hands has a special attack, how much energy you have, and switching it on for the next attack.

```luau
local SpecialAttack = require("../main/interfaces/special_attack")
```

The orb is hidden while the weapon has no special attack, so `available` also tells you whether the weapon has one. The energy and the switch are read from the game (`Player.special_attack`, `Player.special_attack_enabled`), so they work with any tab open.

## Constants

Definition:
```luau
SpecialAttack.GROUP = 160
SpecialAttack.ORBS = { 36, 35, 34 }
SpecialAttack.OPTION = "Use"
SpecialAttack.TOGGLE_TIMEOUT_MS = 1500
```
The orb's interface, the children that can be its button (the first showing one is clicked), the menu option it has and how long `set` waits for the switch to change.

## SpecialAttack.orb

Definition:
```luau
function SpecialAttack.orb(): (Widget?, number?)
```
The orb's button and its child number, or `nil` when it isn't showing.

Example:
```luau
local SpecialAttack = require("../main/interfaces/special_attack")

print(SpecialAttack.orb())
```

## SpecialAttack.available

Definition:
```luau
function SpecialAttack.available(): boolean
```
Whether the weapon in your hands has a special attack.

Example:
```luau
local SpecialAttack = require("../main/interfaces/special_attack")

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
local SpecialAttack = require("../main/interfaces/special_attack")

print("energy:", SpecialAttack.energy())
```

## SpecialAttack.is_enabled

Definition:
```luau
function SpecialAttack.is_enabled(): boolean
```
Whether the special attack is switched on for the next attack.

Example:
```luau
local SpecialAttack = require("../main/interfaces/special_attack")

print("on:", SpecialAttack.is_enabled())
```

## SpecialAttack.set

Definition:
```luau
function SpecialAttack.set(enabled: boolean): boolean
```
Switches the special attack on or off from the orb and waits for it to change. Does nothing if it is so already. Returns `false` when the weapon has none or the orb didn't change.

Example:
```luau
local SpecialAttack = require("../main/interfaces/special_attack")

SpecialAttack.set(true)
```

## SpecialAttack.enable

Definition:
```luau
function SpecialAttack.enable(cost: number?): boolean
```
Switches the special attack on when there is at least `cost` energy (50 by default). Returns `true` when it is on.

Example:
```luau
local SpecialAttack = require("../main/interfaces/special_attack")

if SpecialAttack.enable(50) then
	print("the next attack is a special attack")
end
```
