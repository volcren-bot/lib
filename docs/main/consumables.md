# Main.Consumables

Everything a player eats, drinks or otherwise uses up for its effect: food, potions and their barbarian mixes, brews, ales, raid and minigame supplies. For each, what it does to every stat it touches, and the timed effects and cures it gives (its `special`). The game keeps none of this in the client or its cache, so it's a hand-kept list: 544 families, 940 item ids.

```luau
local Consumables = require("@lib/main/consumables")
```

How long a timed effect has left is read from the vars the game's buff bar reads (CS2 `buff_bar_get_value`), scaled the way RuneLite's timers plugin scales them.

Gear that changes an amount (holy wrench, ring of endurance, sunlight cuffs, Castle Wars bracelets) and league relics aren't counted.

## Types

Definition:

```luau
export type Level = { level: number, real: number }
export type Levels = { [string]: Level }

export type Change = {
	stat: string,
	flat: number,
	percent: number,
	of_current: boolean?,
	boost: boolean?,
	up_to: number?,
	later: number?,
	amount: ((levels: Levels) -> number)?,
}

export type Special = { name: string, ticks: number? }

export type Consumable = {
	name: string,
	ids: { number },
	option: string,
	changes: { Change },
	special: { Special },
	combo: boolean,
}

export type Outcome = { from: number, low: number, high: number }
```

`Levels` are skills by name (as `Host.game_state().skills` names them), plus `"Run energy"` and `"Special attack"` in percent with a real level of 100.

A `Change` moves one stat by `flat` plus `percent` of the stat's real level (its current level with `of_current`), the percent part rounded toward zero. A negative amount lowers the stat, but not below 0. A positive one raises it up to the real level, or up to the real level plus the amount with `boost`. A stat already above that cap stays where it is. `up_to` makes the flat part random, from `flat` to `up_to`. `later` is how many ticks after the rest it lands (the second part of hunter meats). `amount`, when there, replaces `flat` and `percent`, for anglerfish, bream, the moonlight potion and the like.

A `Consumable` is a family of ids that do the same thing: the doses of a potion, most-full first, and the copies of an item that minigames and modes have. `option` is the inventory option that uses it: `Eat`, `Drink`, or another like `Invigorate`, `Guzzle`, `Apply`, `Crack` or `Heal`. `combo` foods (karambwan, the Gauntlet's paddlefish) ignore the delay other food sets. Names can repeat across families with different effects (`Cooked chicken` is also the undead one).

A `Special`'s `ticks` is how long one dose lasts, when known. Over-time effects (silk dressing, blessed crystal scarab, Menaphite remedy, prayer regeneration) have their first application as a change and the rest as their special.

## Consumables.LIST

Definition:

```luau
Consumables.LIST: { Consumable }
```

Every family. Read it, don't change it.

## Consumables.get

Definition:

```luau
function Consumables.get(id: number): Consumable?
```

The family an item id is in, or nil when using it doesn't do anything this list knows of.

Example:

```luau
local Consumables = require("@lib/main/consumables")

local shark = Consumables.get(385)
print(shark and shark.name, shark and shark.option)
```

## Consumables.levels

Definition:

```luau
function Consumables.levels(): Levels?
```

The player's levels now, as `result` takes them. Nil while the game state or the special attack varp can't be read.

## Consumables.result

Definition:

```luau
function Consumables.result(id: number, levels: Levels?): { [string]: Outcome }?
```

What using the item would leave each stat it touches at: `from` the level before, `low` and `high` after (the same unless the amount is random), with every change applied in order, the later ones included. `levels` defaults to `Consumables.levels()`. Nil for an id that isn't a consumable or when the levels can't be read. A change to a stat missing from `levels` is skipped.

Example:

```luau
local Consumables = require("@lib/main/consumables")

local r = Consumables.result(6685)
if r then
	print(`brew: hitpoints {r.Hitpoints.from} -> {r.Hitpoints.low}, attack -> {r.Attack.low}`)
end
```

## Consumables.raising

Definition:

```luau
function Consumables.raising(stat: string, at: number, levels: Levels?): { Consumable }
```

Every family that would raise `stat` if it were at `at`, other levels as in `levels` (default the player's). Food is `raising("Hitpoints", 1)`. Prayer restores are `raising("Prayer", 0)`. Boosts are `raising(stat, real)` with the stat's real level. Empty when the levels can't be read.

Example:

```luau
local Consumables = require("@lib/main/consumables")

for _, c in ipairs(Consumables.raising("Hitpoints", 1)) do
	print(c.name)
end
```

## Consumables.with_special

Definition:

```luau
function Consumables.with_special(name: string): { Consumable }
```

Every family whose `special` has `name`.

Example:

```luau
local Consumables = require("@lib/main/consumables")

for _, c in ipairs(Consumables.with_special("antifire")) do
	print(c.name, c.special[1].ticks)
end
```

## Consumables.remaining

Definition:

```luau
function Consumables.remaining(name: string): number?
```

How many ticks a special has left, 0 when it isn't active, from the var the game's buff bar reads. Nil for a special with no var, or when the var can't be read. Most vars count in steps (30 ticks for antipoison and antifire, 25 for overloads), so the figure is up to one step high. `absorption` gives points left, not ticks.

| Special                                                                                                                                        | Given by                                                | Per dose     | Read from                                                     |
| ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- | ------------ | ------------------------------------------------------------- |
| `antipoison`                                                                                                                                   | antipoison family, mixes, sanfew serum, anti-venoms     | 150 to 1700  | varp 102 below 0 (immune to poison while immune to venom too) |
| `antivenom`                                                                                                                                    | anti-venom family                                       | 30 to 600    | varp 102 below -38                                            |
| `antifire`                                                                                                                                     | antifire, extended antifire, mixes                      | 600, 1200    | varbit 3981 × 30                                              |
| `super_antifire`                                                                                                                               | super and extended super antifire, mixes                | 300, 600     | varbit 6101 × 20                                              |
| `stamina`                                                                                                                                      | stamina, extended stamina, stamina mix                  | 200, 400     | varbit 24 × 10 while varbit 25 is 1                           |
| `divine_attack`, `divine_strength`, `divine_defence`, `divine_ranging`, `divine_magic`, `divine_combat`, `divine_bastion`, `divine_battlemage` | the divine potions                                      | 500          | varbits 8429-8433, 13663-13665                                |
| `moonlight`                                                                                                                                    | moonlight potion                                        |              | varbit 10029                                                  |
| `overload`                                                                                                                                     | Nightmare Zone overload                                 | 500          | varbit 3955 × 25                                              |
| `xeric_overload`                                                                                                                               | Chambers of Xeric overloads                             | 500          | varbit 5418 × 25                                              |
| `blighted_overload`                                                                                                                            | blighted overload                                       |              | varbit 10954 × 25                                             |
| `imbued_heart`                                                                                                                                 | imbued heart, saturated heart (the cooldown they share) | 700 (imbued) | varbit 5361 × 10                                              |
| `surge`                                                                                                                                        | surge potion (its cooldown)                             | 500          | varbit 16270 × 10                                             |
| `stat_renewal`                                                                                                                                 | Menaphite remedy (restores again every 25 ticks)        | 500          | varbit 14448 × 25                                             |
| `prayer_regeneration`                                                                                                                          | prayer regeneration potion (1 point every 12 ticks)     | 800          | varbit 11361 × 12                                             |
| `goading`                                                                                                                                      | goading potion                                          |              | varbit 11294 × 6                                              |
| `smelling_salts`                                                                                                                               | smelling salts                                          |              | varbit 14344 × 25                                             |
| `prayer_enhance`                                                                                                                               | prayer enhance (-), normal, (+)                         |              | varbit 5417 × varbit 5419                                     |
| `absorption`                                                                                                                                   | absorption (50 points a dose, up to 1000)               |              | varbit 3956, in points                                        |
| `liquid_adrenaline`                                                                                                                            | liquid adrenaline                                       | 250          | none                                                          |
| `silk_dressing`                                                                                                                                | silk dressing (5 every 5 ticks, may go 5 over)          | 100          | none                                                          |
| `blessed_crystal_scarab`                                                                                                                       | blessed crystal scarab (8 prayer every 4 ticks)         | 40           | none                                                          |
| `cure_disease`                                                                                                                                 | relicym's balm and mix, sanfew serum                    |              | none                                                          |
| `cure_bleed`                                                                                                                                   | haemostatic dressing (heals 5 when it stops a bleed)    |              | none                                                          |

Example:

```luau
local Consumables = require("@lib/main/consumables")

local left = Consumables.remaining("antifire")
if left and left < 30 then
	print("antifire is about to run out")
end
```

## What isn't covered

- The spicy stew is listed with no changes: what it does depends on the spices in it.
- Kebabs, super kebabs and the Varlamorian kebab have random effects. They're listed with the wiki's typical heal (3 + 7%, 4 + 10%).
- Xeric's aid and revitalisation potions other than (+) are left out, since their formulas aren't published. Quest-only items are also left out.
- Super restore and sunlight moths don't restore Sailing, as in RuneLite's lists.
- Every id's name and option were checked against the client's cache on 2026-11-08. No amount or timer has been watched in a real use yet.
