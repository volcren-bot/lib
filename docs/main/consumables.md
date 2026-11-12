# Main.Consumables

A hand-kept list of everything the player eats, drinks or uses up for its effect (food, potions, mixes, brews, raid and minigame supplies): what it does to each stat and the timed effects and cures it gives (`special`). The client holds none of this.

```luau
local Consumables = require("@lib/main/consumables")
```

Timed effects are read from the vars the game's buff bar reads. Gear that changes an amount (holy wrench, ring of endurance, sunlight cuffs, Castle Wars bracelets) and league relics aren't counted.

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

A `Change` moves one stat by `flat` plus `percent` of its real level (current level with `of_current`), the percent rounded toward zero. Negative lowers it to no less than 0; positive raises it to the real level, or real plus the amount with `boost`; a stat already above that cap stays. `up_to` makes `flat` random in `flat..up_to`. `later` delays it that many ticks (hunter meats). `amount` replaces `flat` and `percent` (anglerfish, bream, moonlight potion).

A `Consumable` is a family of ids with the same effect (a potion's doses, most-full first, plus minigame copies). `option` is the inventory option that uses it (`Eat`, `Drink`, `Guzzle`, `Apply`, ...). `combo` foods (karambwan, Gauntlet paddlefish) ignore the food delay. Names can repeat across families.

A `Special`'s `ticks` is one dose's duration, when known. Over-time effects put their first application in `changes` and the rest in `special`.

## Consumables.LIST

Definition:

```luau
Consumables.LIST: { Consumable }
```

Every family. Read-only.

## Consumables.get

Definition:

```luau
function Consumables.get(id: number): Consumable?
```

The family an item id is in, or nil when it isn't a known consumable.

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

Example:

```luau
local levels = Consumables.levels()
print(levels and levels.Prayer.level)
```

## Consumables.result

Definition:

```luau
function Consumables.result(id: number, levels: Levels?): { [string]: Outcome }?
```

Each touched stat's level before (`from`) and after (`low`..`high`, equal unless random) using the item, every change applied in order, `later` ones included. `levels` defaults to `Consumables.levels()`; stats missing from it are skipped. Nil for a non-consumable or unreadable levels.

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

Every family that would raise `stat` if it were at `at`, other levels from `levels` (default the player's). Food: `raising("Hitpoints", 1)`; prayer restores: `raising("Prayer", 0)`; boosts: `raising(stat, real)`. Empty when levels can't be read.

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

Ticks a special has left, 0 when inactive. Nil for a special with no var or an unreadable var. Most vars count in steps (see the table), so the figure can be up to one step high. `absorption` gives points, not ticks.

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

- Spicy stew has no changes: its effect depends on its spices.
- Kebabs have random effects; they're listed with the typical heal (3 + 7%, 4 + 10%).
- Xeric's aid and revitalisation potions other than (+), and quest-only items, are left out.
- Super restore and sunlight moths don't restore Sailing.
- Names and options were checked against the cache on 2026-11-08; no amount or timer has been verified in live use.
