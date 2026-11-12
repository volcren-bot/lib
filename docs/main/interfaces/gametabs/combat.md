# Main.Interfaces.Gametabs.Combat

The combat options tab: the wielded weapon's category, its current combat style, and autocast through the tab's spell picker. Autocast is a setting holding the spell's number in the game's autocast list (0 for none); the picker shows one child per number the wielded weapon offers.

```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")
```

## Constants

Definition:
```luau
Combat.GROUP = 593
Combat.CHOOSE_SPELL = 28
Combat.CHOOSE_DEFENSIVE = 23
Combat.PICKER_GROUP = 201
Combat.PICKER_SPELLS = 1
Combat.PICKER_CANCEL = 0
Combat.AUTOCAST_VARBIT = 276
Combat.DEFENSIVE_VARBIT = 2668
Combat.WEAPON_CATEGORY_VARBIT = 357
Combat.AUTOCAST_CATEGORIES = { 18, 21, 22 }
Combat.AUTOCAST_ENUM = 1986
Combat.BUTTONS_ENUM = 3908
Combat.BUTTON_STYLES = {
	[3722] = "melee",
	[3723] = "melee",
	[3724] = "melee",
	[3726] = "ranged",
	[3727] = "ranged",
	[3728] = "magic",
}
Combat.DEFENSIVE_BUTTON = 3725
```
- `GROUP`, `CHOOSE_SPELL`, `CHOOSE_DEFENSIVE`: the tab and its autocast (lower) and defensive (upper) "Choose spell" buttons.
- `PICKER_GROUP`, `PICKER_SPELLS`, `PICKER_CANCEL`: the picker, the layer whose children are spells by autocast number, and the Cancel child.
- `AUTOCAST_VARBIT`, `DEFENSIVE_VARBIT`, `WEAPON_CATEGORY_VARBIT`: autocast number, defensive flag, weapon category.
- `AUTOCAST_CATEGORIES`: weapon categories with autocast (staves, powered staves, self-casting staves).
- `AUTOCAST_ENUM`: the autocast list.
- `BUTTONS_ENUM`: weapon category to an enum of attack style index (`Varps.ATTACK_STYLE`) to button struct.
- `BUTTON_STYLES`: combat style per button struct. `DEFENSIVE_BUTTON` takes the weapon's style instead.

## Combat.Style

Definition:
```luau
export type Style = "melee" | "ranged" | "magic"
```
A combat style.

## Combat.is_open

Definition:
```luau
function Combat.is_open(): boolean
```
Whether the combat tab is showing.

Example:
```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

print(Combat.is_open())
```

## Combat.open

Definition:
```luau
function Combat.open(timeout_ms: number?): boolean
```
Opens the combat tab via `SidePanels.open`. True once it shows.

Example:
```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

Combat.open()
```

## Combat.weapon_category

Definition:
```luau
function Combat.weapon_category(): number?
```
The wielded weapon's category, nil when the setting can't be read.

Example:
```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

print(Combat.weapon_category())
```

## Combat.can_autocast

Definition:
```luau
function Combat.can_autocast(): boolean
```
Whether the weapon's category is in `AUTOCAST_CATEGORIES`.

Example:
```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

if Combat.can_autocast() then
	Combat.set_autocast("Fire Strike")
end
```

## Combat.autocast_index

Definition:
```luau
function Combat.autocast_index(): number
```
The autocast number set now, 0 for none or unreadable.

Example:
```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

print(Combat.autocast_index())
```

## Combat.is_defensive

Definition:
```luau
function Combat.is_defensive(): boolean
```
Whether autocast is set to defensive.

Example:
```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

print(Combat.is_defensive())
```

## Combat.style

Definition:
```luau
function Combat.style(): Style?
```
The style the weapon attacks with now, read from settings (the tab need not be open): "magic" while autocasting on an autocast weapon, else the selected button's style; a Defensive button takes the style of the weapon's first styled button. Nil when settings can't be read or the button has no style.

Example:
```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

if Combat.style() == "melee" then
	print("attacking with melee")
end
```

## Combat.spell

Definition:
```luau
function Combat.spell(spell: Magic.SpellRef): Magic.Spell?
```
A spell by name searched across all spellbooks, or the spell table given. Nil when no book has it.

Example:
```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

local s = Combat.spell("Fire Strike")
```

## Combat.autocast_number

Definition:
```luau
function Combat.autocast_number(spell: Magic.SpellRef): number?
```
The spell's autocast number, nil for a spell no weapon autocasts.

Example:
```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

print(Combat.autocast_number("Fire Strike"))
```

## Combat.autocast_spell

Definition:
```luau
function Combat.autocast_spell(): Magic.Spell?
```
The spell autocast now, nil for none.

Example:
```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

local s = Combat.autocast_spell()
print(s and s.name)
```

## Combat.is_picker_open

Definition:
```luau
function Combat.is_picker_open(): boolean
```
Whether the spell picker is showing.

Example:
```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

print(Combat.is_picker_open())
```

## Combat.open_picker

Definition:
```luau
function Combat.open_picker(defensive: boolean?): boolean
```
Opens the combat tab and clicks the autocast or defensive button, waiting up to 2 s for the picker. True at once when a picker (of either mode) is already open; false when the weapon has no autocast button.

Example:
```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

Combat.open_picker(true)
```

## Combat.cancel_picker

Definition:
```luau
function Combat.cancel_picker(): boolean
```
Closes the picker with its Cancel, leaving autocast unchanged. True when it closes or was not open.

Example:
```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

Combat.cancel_picker()
```

## Combat.set_autocast

Definition:
```luau
function Combat.set_autocast(spell: Magic.SpellRef, defensive: boolean?): boolean
```
Sets the spell to autocast (defensively with `defensive`) by picking it in the picker; retries once if an already-open picker was the other mode. True once the settings show it, at once if already set. False for a spell no weapon autocasts, one this weapon's picker lacks (the picker is cancelled), or a weapon without autocast.

Example:
```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

Combat.set_autocast("Fire Strike")
```
