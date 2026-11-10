# Main.Interfaces.Gametabs.Combat

The combat options tab: the wielded weapon's category, the combat style its selected button attacks with, and its autocast, chosen through the tab's spell picker.

```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")
```

Autocast is a number the game keeps in a setting: the spell's place in its autocast list (an enum of the spells any weapon can autocast). The picker that opens from the tab's "Choose spell" buttons shows the spells the wielded weapon offers, one dynamic child per number, so a spell the weapon can't autocast isn't there. Which weapons have the buttons at all is decided by the weapon's category, a setting the server sets when the weapon changes.

```luau
local Combat = require("@lib/main/interfaces/gametabs/combat")

if Combat.can_autocast() then
	Combat.set_autocast("Fire Strike")
end
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
The tab's interface and its two "Choose spell" buttons (autocast, the lower one, and defensive autocast, the upper one; the defensive setting proved which is which); the picker's interface, the layer whose dynamic children are the spells (by autocast number) and the Cancel child; the settings holding the autocast number (0 for none), whether it is defensive and the weapon's category; the categories whose tab offers autocast (staves, powered staves and the staves that cast their own spell); and the game's autocast list.

`BUTTONS_ENUM` is the game's list of each category's style buttons: weapon category to an enum of button number (the attack style setting, `Varps.ATTACK_STYLE`) to the button's struct. The structs are Accurate (3722), Aggressive (3723), Controlled (3724), Defensive (3725), Ranging (3726), Longrange (3727), Casting (3728) and Other (3721, an empty or non-attacking slot). `BUTTON_STYLES` is the combat style of each struct that has one of its own. Defensive takes the weapon's: it is melee on a melee weapon and magic on a powered staff.

## Combat.Style

Definition:
```luau
export type Style = "melee" | "ranged" | "magic"
```
A combat style.

## Combat.is_open / Combat.open

Definition:
```luau
function Combat.is_open(): boolean
function Combat.open(timeout_ms: number?): boolean
```
Whether the tab is showing, and opening it (`SidePanels.open`).

## Combat.weapon_category

Definition:
```luau
function Combat.weapon_category(): number?
```
The wielded weapon's category, the number the tab lays its buttons out by.

## Combat.can_autocast

Definition:
```luau
function Combat.can_autocast(): boolean
```
Whether the wielded weapon's tab offers autocast.

## Combat.autocast_index / Combat.is_defensive

Definition:
```luau
function Combat.autocast_index(): number
function Combat.is_defensive(): boolean
```
The autocast number set now (0 for none), and whether autocast is defensive.

## Combat.style

Definition:
```luau
function Combat.style(): Style?
```
The combat style the wielded weapon attacks with now: "magic" while autocasting, otherwise the style of the selected button, looked up by the weapon's category in `BUTTONS_ENUM`. A Defensive button takes the style of the weapon's first button that has one. The answer follows the button, so a salamander is melee, ranged or magic by the one picked, and a staff is melee until it autocasts. It is read from settings, so the combat tab doesn't need to be open. Nil when the settings can't be read, and for a category or button without a style (the "Other" slots, or a category missing from the list).

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
A spell by name in any of the books (`Magic.spell` looks in the current one unless told a book), or the spell given.

## Combat.autocast_number

Definition:
```luau
function Combat.autocast_number(spell: Magic.SpellRef): number?
```
The spell's autocast number, nil for one no weapon autocasts.

## Combat.autocast_spell

Definition:
```luau
function Combat.autocast_spell(): Magic.Spell?
```
The spell autocast now, from the number and the spellbooks, nil for none.

## Combat.is_picker_open / Combat.open_picker / Combat.cancel_picker

Definition:
```luau
function Combat.is_picker_open(): boolean
function Combat.open_picker(defensive: boolean?): boolean
function Combat.cancel_picker(): boolean
```
The spell picker: whether it is open, opening it with the autocast or the defensive button (false when the weapon has no autocast), and closing it with its Cancel, leaving the autocast as it was.

## Combat.set_autocast

Definition:
```luau
function Combat.set_autocast(spell: Magic.SpellRef, defensive: boolean?): boolean
```
Sets the spell to autocast, defensively with `defensive`: opens the picker from the right button and picks the spell by its menu option. A picker that was already open may be the other mode's; the pick then lands in the wrong mode and is done again from the right button. True once the settings show it set, at once when it already is. False for a spell no weapon autocasts, one the wielded weapon's picker doesn't offer (the picker is cancelled), or a weapon without autocast.

## Combat.is_open

Definition:
```luau
function Combat.is_open(): boolean
```
TODO...

Example:
```luau

```

## Combat.open

Definition:
```luau
function Combat.open(timeout_ms: number?): boolean
```
TODO...

Example:
```luau

```

## Combat.autocast_index

Definition:
```luau
function Combat.autocast_index(): number
```
TODO...

Example:
```luau

```

## Combat.is_defensive

Definition:
```luau
function Combat.is_defensive(): boolean
```
TODO...

Example:
```luau

```

## Combat.is_picker_open

Definition:
```luau
function Combat.is_picker_open(): boolean
```
TODO...

Example:
```luau

```

## Combat.open_picker

Definition:
```luau
function Combat.open_picker(defensive: boolean?): boolean
```
TODO...

Example:
```luau

```

## Combat.cancel_picker

Definition:
```luau
function Combat.cancel_picker(): boolean
```
TODO...

Example:
```luau

```
