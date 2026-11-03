# Main.Transports

## Transports.split

Definition:
```luau
function Transports.split(name: string): (string, string?)
```
Splits a spell row's name into the game's spell and the menu option: `Varrock Teleport: Grand Exchange` is the spell `Varrock Teleport` with option `Grand Exchange`, `Teleport to House (Inside)` the option `Inside`.

Example:
```luau
local Transports = require("@lib/main/transports")

print(Transports.split("Camelot Teleport: Seers'"))
```

## Transports.wilderness_level

Definition:
```luau
function Transports.wilderness_level(x: number, y: number): number
```
The wilderness level of a tile, 0 outside it.

Example:
```luau
local Transports = require("@lib/main/transports")

print(Transports.wilderness_level(3100, 3600))
```

## Transports.quests_done

Definition:
```luau
function Transports.quests_done(t: Transport): boolean
```
Whether every quest a transport needs is complete, read through `Journal`. Only asked after the cheaper checks pass.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.quests_done(transport)
```

## Transports.walk_ticks

Definition:
```luau
function Transports.walk_ticks(a: Tile, b: Tile): number
```
An estimate of the game ticks to walk between two tiles.

Example:
```luau
local Transports = require("@lib/main/transports")

print(Transports.walk_ticks({ x = 0, y = 0 }, { x = 100, y = 40 }))
```

## Transports.choose

Definition:
```luau
function Transports.choose(from: Tile, goal: Tile, options: Options?): Choice?
```
The first transport to use on the best way from `from` to `goal`, or nil to walk. The way is a shortest path over the start, the goal and the ends of every usable transport: walking joins two points only when they are on the same landmass (`Host.landmasses`), so a goal across the water is reached through a ship; a spell leaves from anywhere; a ship leaves from its dock. The first transport is a spell to cast now, a ship (it walks to the dock first), a gate, a lever to pull or a mushtree ride. Nil when walking is possible and no transport saves `MIN_SAVING_TICKS`, when none is usable, or when the goal can't be reached at all. Usable means the row's varbit tests hold, its skills, quests and (for ships) coins are met, it ends outside the wilderness (levers excepted, see `LEVERS_INTO_WILDERNESS`), and for a spell the game says it can be cast. A lever that lands inside the wilderness is left out unless `LEVERS_INTO_WILDERNESS` is true (the default is false). The cost of a ship's fare is not weighed against time.

Example:
```luau
local Transports = require("@lib/main/transports")

local choice = Transports.choose({ x = 3162, y = 3488, plane = 0 }, { x = 3213, y = 3424, plane = 0 })
print(choice and choice.transport.name)
```

## Transports.settle

Definition:
```luau
function Transports.settle(at: Tile)
```
Waits for the new scene to load after a teleport: until then planning a route fails with "not logged in".

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.settle(position)
```

## Transports.cast

Definition:
```luau
function Transports.cast(choice: Choice): boolean
```
Casts the chosen teleport and waits to land. False when it didn't work; that spell is then left alone for `RETRY_AFTER_MS`.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.cast(choice)
```

## Transports.travel

Definition:
```luau
function Transports.travel(from: Tile, goal: Tile, options: Options?): (boolean, boolean)
```
Takes the best transport toward `goal` if one is worth it. Returns whether one was used and whether one failed all its attempts. After a failure the caller plans again from where it is: the failed one is out of the new plan, so another way is chosen. `Walker.walk` does this.

Example:
```luau
local Transports = require("@lib/main/transports")

print(Transports.travel({ x = 3162, y = 3488, plane = 0 }, { x = 2757, y = 3478, plane = 0 }))
```
Takes the best transport toward `goal` if one is worth it. Returns whether one was used and whether one failed all its attempts. After a failure the caller plans again from where it is: the failed one is out of the new plan, so another way is chosen. `Walker.walk` does this.


Example:
```luau
local Transports = require("@lib/main/transports")

print(Transports.travel({ x = 3162, y = 3488, plane = 0 }, { x = 2757, y = 3478, plane = 0 }))
```

## Transports.levels

Definition:
```luau
function Transports.levels(): { [string]: number }?
```
The player's levels by lowercase skill name (`magic`, `agility`, ...), plus `total` (the total level) and `combat` (the combat level), as the data's `Skills` column names them. Skill levels are the current ones, boosts included, the way the game checks them; total and combat use the real levels. Nil when the skills can't be read.

Example:
```luau
local Transports = require("@lib/main/transports")

local levels = Transports.levels()
print(levels and levels.combat)
```

## Transports.skills_met

Definition:
```luau
function Transports.skills_met(t: Transport, levels: { [string]: number }?): boolean
```
Whether the skill levels a transport needs are met, against `Transports.levels()` unless `levels` is given. A skill the data names that isn't known counts as not met, and is logged once. `choose` checks this before it asks the game whether a spell can be cast.

Example:
```luau
local Transports = require("@lib/main/transports")

print(Transports.skills_met({ skills = { { name = "Magic", level = 25 } } } :: any, { magic = 60 }))
```

## Transports.items_met

Definition:
```luau
function Transports.items_met(t: Transport, counts: { [number]: number }?): boolean
```
Whether the items a transport needs are in the inventory. The `items` column is any-of groups (`|`) of all-of items (`&`), `&` binding tighter; each item is `NAME=amount` or `id=amount`, a name being a group from the data's item-variations (`COINS`, `AXE`, ...) of which any id counts. `counts` is the inventory's amounts by item id unless given. A token that can't be counted (an unlock such as `UNLOCK_XERICS_HONOUR`, an equipment slot such as `HEADSLOT`) makes its group not met, and is logged once. Spells don't use this: the game's own check covers their runes.

Example:
```luau
local Transports = require("@lib/main/transports")

local coins = { items = "COINS=2500" }
print(Transports.items_met(coins, { [995] = 3000 }))
```

## Transports.sail

Definition:
```luau
function Transports.sail(choice: Choice): boolean
```
Takes the chosen charter ship: walks to its dock, talks to the trader (found from the id the data names, by the client's name for it), picks the destination in the list, waits for the boat and crosses the gangplank onto the dock the data names. The fare is taken when the destination is chosen. False when it didn't work; that trip is then left alone for `RETRY_AFTER_MS`.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.sail(choice)
```

## Transports.allowed_climbs

Definition:
```luau
function Transports.allowed_climbs(options: { shortcuts: boolean? }?): { string }
```
The stairs, ladders, ropes and cave mouths, the links across obstacles (stiles, logs, objects that are doors) and the agility shortcuts, that ask for something (a quest, a level, an item, a varbit) and that the player has what they ask for, as `"x,y,plane>x,y,plane"`. The planner has every climb that asks for nothing already; `Walker.walk` passes these as `allow_climbs` to `Host.nav_plan`. Kept for `VALID_FOR_MS`.

A shortcut is judged on the real (unboosted) levels, because a boost can run out on the way, and is left out when it starts or ends in the Wilderness. `shortcuts = false` (default `Transports.SHORTCUTS`) leaves all of them out. The shortcuts are the data's `agility_shortcuts`, the short hops of at most 40 tiles within one world.

Example:
```luau
local Transports = require("@lib/main/transports")

print(#Transports.allowed_climbs({ shortcuts = false }))
```

## Transports.ride

Definition:
```luau
function Transports.ride(choice: Choice): boolean
```
Rides the magic mushtrees on Fossil Island: walks to the start tile the data names, uses the nearest mushtree (see `Main.Interfaces.Mainscreen.Mushtree`), picks the destination in the list by its name and waits to land. The list only shows the trees you can go to, so a tree that isn't there fails the ride. False when it didn't work; that ride is then left alone for `RETRY_AFTER_MS`. A ride needs the quests in `Transports.EXTRA_QUESTS` (Bone Voyage), because the data names none.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.ride(choice)
```

## Transports.hub

Definition:
```luau
function Transports.hub(choice: Choice): boolean
```
Takes a trip of one of the networks whose data lists the starts and the ends apart: the quetzals (`quetzals`), spirit trees (`spirit_trees`), the Lovakengj minecarts (`minecarts`), gnome gliders (`gnome_gliders`) and fairy rings (`fairy_rings`). It walks to the start tile beside the tree, ring or pilot, has the interface module choose the destination by its name (`Quetzal.select`, `Spirittree.select`, `Gnomeglider.select`, or `Fairyring.travel` with the code), and waits to land. A spirit tree place that is drawn grey (not unlocked) fails the trip. False when it didn't work; that trip is then left alone for `RETRY_AFTER_MS`.

The chooser pairs the starts and the ends as it plans: every start goes to every end that is not within the network's radius of it (5 tiles; 6 for the gliders and rings), at the end row's duration plus the interface's slack. The rows around one tree (within 4 tiles with the same click) are one start. A start or end the player can't use (the quest, level or varbit the row asks for, or the fairy rings' own requirements, `Fairyring.can_use`) is left out, and so is one in the Wilderness. The player's own house is left out: the data puts it where the "Teleport to House" spell lands, a stand-in for an instance somewhere else.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.hub(choice)
```

## Transports.board

Definition:
```luau
function Transports.board(choice: Choice): boolean
```
Takes a boat, ferry or train cart (the data's `boats`, `ships` and the Keldagrim part of `minecarts`): whole trips from one tile to another, made by clicking an NPC or an object. It walks to the tile the trip is boarded from, finds the NPC with the id the data's menu column ends with (else the object), clicks it with the option the menu starts with (the data doesn't mark where the option ends and the name begins, so every beginning is tried, longest first), then follows the dialogue until it lands: the option that names the destination, else a yes, and "continue". When no option can be picked it gives up and logs the options it saw. False when it didn't work; that trip is then left alone for `RETRY_AFTER_MS`.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.board(choice)
```

## Transports.dialogue_pick

Definition:
```luau
function Transports.dialogue_pick(options: { { text: string } }, hints: { string }): string?
```
The text of the dialogue option to pick for a boat: the first that contains one of `hints` (pieces of the destination's name, lowercase, four letters or more), else the first that starts with a yes (`yes`, `ok`, `sure`, `pay`, `go`, `travel`, `take`, `accept`, `board`); nil when there is none.

Example:
```luau
local Transports = require("@lib/main/transports")

print(Transports.dialogue_pick({ { text = "Brimhaven" }, { text = "No thanks" } }, { "brimhaven" }))
```

## Transports.use_item

Definition:
```luau
function Transports.use_item(choice: Choice): (boolean, boolean?)
```
Uses a teleport item (`kind = "item"`: jewellery, capes, crystals, tablets; the data's `teleportation_items`) held in the inventory or worn. `choice.spell` is the item's name and `choice.option` the destination ("Burthorpe"; a destination behind several menus is written "Fishing Teleports: Fishing Guild"; nil for an item with one). How the destination is picked, in order:

1. The item's own menu names it (a crystal's "Lletya"): that option is clicked.
2. A submenu of the item's right-click menu lists it (the minimenu's "Rub" > "Burthorpe"): picked there. This is the quicker way, so it is taken with probability `ITEM_SUBMENU_BASE` (0.7) plus the rest weighted by the account's `Biometrics.CHOOSEOPTION`.
3. Otherwise, or when the biometrics say so, the submenu's option is clicked and the dialogue it opens is answered (by key, else by click if the key doesn't take). If the option opens no dialogue within `ITEM_DIALOGUE_MS` (the max cape's list), the submenu is used after all.
4. An item with no destination to name ("Teleport", "Break", "Weiss") has its option clicked.

Waits `ITEM_TIMEOUT_MS` to land. The second result is true when trying again is pointless (item not held, destination not offered). The planner (`choose`) prices an item by the data's `Duration`, `ITEM_SLACK_TICKS`, and for a consumable one `ITEM_CHARGE_TICKS` more, so a charge isn't spent on a short hop; items are off with `Transports.ITEMS = false` or `exclude = { items = true }` (or an item's name). The player's house teleports and the Wilderness are left out, and the capes' `Max ...` skill rows are not tested (holding the cape is the proof).

Example:
```luau
local Transports = require("@lib/main/transports")

local choice = Transports.choose(here, goal)
if choice and choice.kind == "item" then
	print(Transports.use(choice))
end
```

## Transports.use

Definition:
```luau
function Transports.use(choice: Choice): boolean
```
Uses the chosen transport, whatever its kind (a spell, an item, a charter ship, a gate, a lever or a mushtree ride): up to `ATTEMPTS` (3) tries with `RETRY_PAUSE_MS` between. If every one fails it is marked failed for `RETRY_AFTER_MS` (5 minutes) and the next plan leaves it out; this then returns false. True when one worked.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.use(choice)
```

## Transports.pass

Definition:
```luau
function Transports.pass(choice: Choice): boolean
```
Goes through the chosen gate or barrier: walks to the tile before it, clicks the object between the two tiles by name (the object changes with quest progress: `Pay-toll(2-Ecto)` before it, `Pass` after) and waits to be on the other side. False when it didn't work; that gate is then left alone for `RETRY_AFTER_MS`.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.pass(choice)
```

## Transports.pull

Definition:
```luau
function Transports.pull(choice: Choice): boolean
```
Pulls the chosen lever (`teleportation_levers.tsv`): walks to the tile the row gives (`LEVER_OBJECT_NEAR` tiles around it), clicks the option the row's menu column names on the object it names, and waits up to `LEVER_TIMEOUT_MS` to land within `LEVER_ARRIVED_NEAR` of the row's destination tile. The wilderness lever names its destination rather than offering `Pull`, so a row is one option: `Ardougne Lever 1815` is the option `Ardougne` on object 1815 and `Pull Lever 1814` is the option `Pull` on object 1814. Levers into the wilderness are left out of the routes (two of them are a way from Edgeville to Ardougne) unless `LEVERS_INTO_WILDERNESS = true`. False when it didn't work; that lever is then left alone for `RETRY_AFTER_MS`.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.pull(choice)
```

## Transports.failed_lately

Definition:
```luau
function Transports.failed_lately(choice: Choice): boolean
```
Whether a choice failed all its attempts in the last `RETRY_AFTER_MS` (5 minutes), so the planner leaves it out.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.failed_lately(choice)
```

## Transports.row_usable

Definition:
```luau
function Transports.row_usable(t: Transport): (boolean, string?)
```
TODO...

Example:
```luau

```

## Transports.disembark

Definition:
```luau
function Transports.disembark(to: Tile): boolean
```
TODO...

Example:
```luau

```
