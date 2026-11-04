# Main.Interfaces.Gametabs.Combat

The combat options tab: the wielded weapon's category and its autocast, chosen through the tab's spell picker.

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
```
The tab's interface and its two "Choose spell" buttons (autocast, the lower one, and defensive autocast, the upper one; the defensive setting proved which is which); the picker's interface, the layer whose dynamic children are the spells (by autocast number) and the Cancel child; the settings holding the autocast number (0 for none), whether it is defensive and the weapon's category; the categories whose tab offers autocast (staves, powered staves and the staves that cast their own spell); and the game's autocast list.

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
