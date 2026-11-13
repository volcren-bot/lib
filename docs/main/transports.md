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
function Transports.quests_done(t: Transport, known: { [string]: boolean }?): boolean
```
Whether every quest a transport needs is complete, read through `Journal`. `known` remembers the answers, so one plan asks about each quest once.

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
The first transport to use on the best way from `from` to `goal`, or nil to walk. The way is a shortest path over the start, the goal and the ends of every usable transport: walking joins two points only when they are on the same landmass (`Host.landmasses`, with the links and shortcuts the player can use joining theirs), so a goal across the water is reached through a ship; a spell or item leaves from anywhere; the rest leave from their tile.

Nil when walking is possible and no transport saves `MIN_SAVING_TICKS`, when none is usable, or when the goal can't be reached at all. A goal that looks cut off but is within `CONFIRM_WALK_TILES` is asked of the planner first (`Host.nav_plan`): landmasses don't see every way through, and a goal the planner reaches is walked.

Usable means the row's varbit tests hold, its skills, quests and items are met (items count in the inventory or worn), and for a spell the game says it can be cast (`Magic.can_cast`, whose icons are only as fresh as the last time the spellbook was shown). A transport that failed in the last `RETRY_AFTER_MS` is out.

**The Wilderness.** A trip never goes from safety into the Wilderness unless a script asks, with `options.wilderness = true` for one plan or `Transports.WILDERNESS = true` for all of them. From outside, nothing that starts or ends in it is chosen, except a trip that lands in the Ferox Enclave when the goal is inside it too (`Ferox.contains`): that's how Clan Wars and Last Man Standing are reached. The Enclave is safe, and with the goal inside, no walk through the Wilderness follows. Its bounds are approximate. Once you are in it, a trip that leaves it or stays inside it is fine, but walking out to a start in safety that leads back in isn't. A goal in the Wilderness doesn't count as asking: the walk there is on foot. The player's own house is left out: the data puts it where "Teleport to House" lands, a stand-in for an instance somewhere else. Fares are not weighed against time.

`options.exclude` names what never to use: a spell's or item's name, a charter's or ride's label, a minigame's activity (`Castle Wars`), or a group: `spells`, `minigames`, `items`, `charter`, `ride`, `canoes`, `portals`, `house`, `gates`, `levers`, `passages`, or a network's kind (`fairy_rings`).

**Passages.** `transports.tsv` has about 600 rows too far for the planner: a tunnel, a cart, or a ladder to another part of the map. That means more than 15 tiles on one plane, or more than 350 when the plane changes. The chooser takes them as whole trips through `Transports.ride`, under the group `passages`, with their requirements and the Wilderness rule like any row. They aren't on the loader's Settings page, because turning them off would cut places off. `Join Castle Wars` is left out, along with these entrances: Wintertodt's Door of Dinh, Zalcano's platform, the Giant Mole's mole hills, the Corporeal Beast's cave, Puro-Puro's crop circle, the Mage of Zamorak, the Ancient Cavern's whirlpool and the Trollweiss sled. Their ways back out stay in. This only covers rows too far for the planner, so a boss entrance among the nearer climbs is still usable.

**Doors that ask for something.** A row of one tile with "Open" and a requirement (a guild's door, a locked gate) goes one way, and a guild's often only asks on the way in. When the player doesn't meet it, the planner won't step through that way, though it can still walk out the other way. On the world map these doors split the landmasses, so a goal behind one has no way on foot until the row is allowed. The other one-tile rows (`Pick-lock`, `Slash Web`, `Jump-over`) are links, as stiles are.

**Types the user turned off.** Anything of a type turned off on the loader's Settings page is never chosen, whatever the script asks. See `Transports.is_enabled`.

**Requirements in a comment.** A comment above a block of rows can state a requirement, like `varbit:4566=0?COINS=200`: the items are owed while the variable is at most the value, and free once it's past it. Varbit 4566 is the Karamja elite diary, so its carts stop charging when that's done, even with no coins held. Rows that name the items themselves are the ones it applies to, and the free rows beside them (Karamja's log crossing) aren't bound. When no row in the block names them (Port Phasmatys's barriers, the Waterfall rows), the comment binds every row. A form that can't be read leaves its rows out, logged once.

**Unlocks.** `Transports.UNLOCKS` says how each `UNLOCK_*` item is met:

| Item | How |
| --- | --- |
| `UNLOCK_KARAMJA_ELITE` | Varbit 4566 is at least 1: the elite diary. |
| `UNLOCK_MOR_UL_REK` | Varbit 5646 is at least 1: a guard was shown a fire cape (1), or one was sacrificed (2). Its cache name is `inferno_sacrificed_firecape`. |
| `UNLOCK_DRAGONTOOTH` | Taken as met until refused: paying the ghost captain 500 tokens sets nothing visible under any variable name found. |
| `UNLOCK_XERICS_HONOUR` | The same, for an ancient tablet used on a talisman. The talisman itself is still needed. |

A trip taken on that assumption and refused is left out for `RETRY_AFTER_MS`, and a walk with no other way then raises its error. `UNLOCK_CANOE_AXE` has its own rule (`Transports.canoe`), and `UNLOCK_BALLOON_LOG_BASKET` stays unmet: balloons use logs held, or `BALLOON_STORAGE`.

Example:
```luau
local Transports = require("@lib/main/transports")

local choice = Transports.choose({ x = 3162, y = 3488, plane = 0 }, { x = 3213, y = 3424, plane = 0 })
print(choice and choice.transport.name)
```

## Transports.settle

Definition:
```luau
function Transports.settle()
```
Waits for the new scene to load after a trip: the client is back in its logged-in state, for at most `SETTLE_TIMEOUT_MS`.

Example:
```luau
local Transports = require("@lib/main/transports")

Transports.settle()
```

## Transports.cast

Definition:
```luau
function Transports.cast(choice: Choice): (boolean, boolean?)
```
Casts the chosen teleport and waits to land. A trip has landed on a jump between two looks that walking can't make (`LAND_DISTANCE`), a change of plane, or standing at the destination, so a player still running when the spell is cast isn't taken for one that landed. False when it didn't work; `Transports.use` then decides what to do.

A spell usually gets `LAND_TIMEOUT_MS` to land. One the data says takes longer, like the home teleports at 19 to 25 ticks, gets its duration plus `SLOW_CAST_SLACK_MS`, and must start animating within `SLOW_CAST_START_MS`; if it doesn't, the game refused it (in combat, say), and the second result is true because trying again is pointless.

The home teleports come from the data's `teleportation_spells_home`, one per spellbook: Lumbridge, Edgeville, Lunar and Arceuus. A row's `892@30` is the 30 minute cooldown: varp 892 keeps the minute since the Unix epoch of the last cast that finished, and `Host.unix_time` tells how long ago that was. A cast that is interrupted doesn't start the cooldown. Its `Duration` depends on the animation chosen for the spell (varp 4560), and the rows carry each one.

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

## Transports.levels

Definition:
```luau
function Transports.levels(real_only: boolean?): { [string]: number }?
```
The player's levels by lowercase skill name (`magic`, `agility`, ...), plus `total` (the total level) and `combat` (the combat level), as the data's `Skills` column names them. Skill levels are the current ones, boosts included, the way the game checks them, or the real ones with `real_only`; total and combat always use the real levels. Nil when the skills can't be read.

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
Whether the items a transport needs are held, in the inventory or worn. The `items` column is any-of groups (`|`) of all-of items (`&`), `&` binding tighter; each item is `NAME=amount` or `id=amount`, a name being a group from the data's item-variations (`COINS`, `AXE`, ...) of which any id counts. `counts` is the amounts by item id, read now unless given. A token that can't be counted (an unlock such as `UNLOCK_XERICS_HONOUR`, an equipment slot such as `HEADSLOT`) makes its group not met, and is logged once. Spells don't use this: the game's own check covers their runes.

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
Takes the chosen charter ship: walks to its dock, talks to the trader (found from the id the data names, by the client's name for it), picks the destination in the list, waits for the boat and crosses the gangplank onto the dock the data names. The fare is taken when the destination is chosen. False when it didn't work; `Transports.use` then decides what to do.

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
The stairs, ladders, ropes and cave mouths (`climb_gated`), the links across obstacles such as stiles, logs and objects that are doors (`link_gated`) and the agility shortcuts (`shortcut_gated`) that ask for something and that the player has what they ask for, as `"x,y,plane>x,y,plane"`. The planner has every row that asks for nothing already; `Walker.walk` passes these as `allow_climbs` to `Host.nav_plan`. Kept for `VALID_FOR_MS`.

A shortcut is judged on the real (unboosted) levels, because a boost can run out on the way, and is left out when it starts or ends in the Wilderness. `shortcuts = false` (default `Transports.SHORTCUTS`) leaves all of them out. The shortcuts are the data's `agility_shortcuts`, the hops of at most 70 tiles, with the underground laid over the surface.

Example:
```luau
local Transports = require("@lib/main/transports")

print(#Transports.allowed_climbs({ shortcuts = false }))
```

## Transports.walkable

Definition:
```luau
function Transports.walkable(from: Tile, goal: Tile, options: Options?): boolean
```
Whether `goal` can be walked to from `from` with no transport: across planes and the underground, using the map's climbs and links plus the gated ones this account can use (`Host.world_route`). A goal within `CONFIRM_WALK_TILES` that the map says no to is also asked of the planner, which sees every way through the collision. This is what `Walker.walk` asks before raising its error.

Example:
```luau
local Transports = require("@lib/main/transports")

print(Transports.walkable({ x = 3222, y = 3218, plane = 0 }, { x = 2965, y = 3380, plane = 0 }))
```

## Transports.house

Definition:
```luau
function Transports.house(choice: Choice): (boolean, boolean?)
```
Takes a trip from inside the player's house, by its Portal Nexus, its jewellery box or something mounted on its walls (`Mounted`; the data's `teleportation_portals_poh` and `teleportation_boxes`). A house's layout can change, so the data's single tile stands for the whole house (`House.TILE`): a tablet, a spell or the home portal arrives there, and the furniture is found by name in that visit's scene, on any floor.

**What is built.** A trip counts when `House.offers` names its furniture for its place. The variables say what the Nexus holds by name and how big the box is (fancy and ornate; a basic box reads like none until a visit), from anywhere. The rest can only be seen from inside, so `choose` looks around whenever the player is in a house (`House.survey`), and from then on in that run what it saw decides, even from outside: the mounted pieces, the fairy ring and the spirit tree count as not met until a visit shows them, and no teleport is spent to find out. The trip runs by `House.start_teleport`. A teleport that turns out not to be there is left out for the rest of the run, and the walk plans again from inside the house. The way out is `Transports.house_exit`, so a walk never gets stuck in there. The second result is true when trying again is pointless.

**The fairy rings and spirit trees** take the house as one more stop, once a visit has shown one (`furniture` on the network, run by `Transports.hub`): out of it, and in by code DIQ or "Your house". A Spiritual Fairy Tree counts as both.

**Not used yet:** a portal chamber's portals, its respawn portal and its obelisk. The box's Corporeal Beast is left out, like other boss rooms.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.house(choice)
```

## Transports.house_exit

Definition:
```luau
function Transports.house_exit(choice: Choice): boolean
```
Leaves the house by its portal, wherever that is.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.house_exit(choice)
```

## Transports.use_on

Definition:
```luau
function Transports.use_on(choice: Choice): boolean
```
Takes a row that uses an item on an object, like `Use Rope -> Boulder 5842`: walks there, selects the item, clicks the object and waits to stand where the row lands. These are trips for the chooser, because the planner can only click an object's own options. They need the item named in the menu, held in the inventory. A menu's item with no group in the data (a plank) leaves the row out.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.use_on(choice)
```

## Transports.wear_for_climb

Definition:
```luau
function Transports.wear_for_climb(from: Host.NavTile, to: Host.NavTile, option: string): boolean
```
Puts on what the climb between two tiles by this menu option has to be used with, from the inventory: a crossbow and mithril grapple, or climbing boots (`Transports.WORN_GROUPS`). `Walker.walk` calls it just before clicking a climb, and what it puts on stays on. True when nothing more has to go on.

Each grapple has a row with no item on the same tiles and a higher Agility level, like a wall's `Climb` at 52. When both can be used the planner only gets that one, so a high level never swaps gear for nothing. A grapple has a 1 in 25 chance of breaking when used, so the walk may lose one.

Example:
```luau
local Transports = require("@lib/main/transports")

print(Transports.wear_for_climb({ x = 2866, y = 3428, plane = 0 }, { x = 2869, y = 3428, plane = 0 }, "Grapple"))
```

## Transports.is_enabled

Definition:
```luau
function Transports.is_enabled(name: string): boolean
```
Whether the user has this type of transport on, on the loader's Settings page. All are on until turned off. The names are `spells`, `home_teleports`, `minigames`, `items`, `quetzal_whistle`, `scroll_book`, `quetzals`, `spirit_trees`, `gnome_gliders`, `hot_air_balloons`, `fairy_rings`, `magic_mushtrees`, `magic_carpets`, `canoes`, `portals`, `wilderness_obelisks`, `house`, `charter`, `ride`, `minecarts`, `gates`, `levers` and `shortcuts`.

Example:
```luau
local Transports = require("@lib/main/transports")

print(Transports.is_enabled("fairy_rings"))
```

## Transports.require_enabled

Definition:
```luau
function Transports.require_enabled(name: string)
```
Raises an error that stops the script when the user has this type of transport off, with a message naming it and the setting. For a script that can't work without one; call it when the script starts. A setting can change while a script runs, and only the chooser notices that.

Example:
```luau
local Transports = require("@lib/main/transports")

Transports.require_enabled("fairy_rings")
```

## Transports.canoe

Definition:
```luau
function Transports.canoe(choice: Choice): (boolean, boolean?)
```
Takes a canoe trip (the data's `canoes`): walks to the station, then `Canoe.travel` with the smallest canoe that reaches the row's end. The data's Woodcutting level for a row says how many stops it is.

**The axe.** A trip needs an axe, held or kept by a station's NPC. The game doesn't show whether one is kept: no varp changes, and the NPC's options stay the same. So with no axe held the chooser assumes one is kept, until a station says "You need an axe": then every canoe is left out and the walk plans again without them. A change in the axes held brings them back; the same axe doesn't, because the game also says this of an axe too high a level to use. The second result is true when trying again is pointless.

A canoe already floating at the station is used as it is, and if it's too small for the trip, that row is left out for `RETRY_AFTER_MS`.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.canoe(choice)
```

## Transports.hub

Definition:
```luau
function Transports.hub(choice: Choice): boolean
```
Takes a trip of one of the networks whose data lists the starts and the ends apart: the quetzals (`quetzals`), spirit trees (`spirit_trees`), the Lovakengj minecarts (`minecarts`), magic mushtrees (`magic_mushtrees`), gnome gliders (`gnome_gliders`), hot air balloons (`hot_air_balloons`) and fairy rings (`fairy_rings`). It walks to the start tile beside the tree, ring or pilot, has the interface module choose the destination by its name, and waits to land. A quetzal trip to the game's last site mostly uses "Last-destination" on Renu instead of the map (see `Transports.whistle` for how often). A spirit tree place that is drawn grey (not unlocked), or a mushtree that isn't in the list (not grown), fails the trip. False when it didn't work; `Transports.use` then decides what to do.

The chooser pairs the starts and the ends as it plans, at the end row's duration plus the interface's slack: every start goes to every end not within the network's radius of it (5 tiles; 6 for the gliders and rings, 7 for the balloons). The rows around one tree (within 4 tiles with the same click) are one start. A start or end the player can't use is left out, and the Wilderness follows the rule under `Transports.choose`. A balloon is only used with its log in the inventory (`Balloon.holds_log`), because logs in storage can't be read before a flight; `Transports.BALLOON_STORAGE = true` counts on those too (`Balloon.has_log`). A network can also have a gate of its own: `Fairyring.can_use` for the rings, and Bone Voyage for the mushtrees, whose rows name no quest; the answer is kept for `VALID_FOR_MS`.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.hub(choice)
```

## Transports.ride

Definition:
```luau
function Transports.ride(choice: Choice): (boolean, boolean?)
```
Takes a boat, ferry, train cart or magic carpet (the data's `boats`, `ships`, the Keldagrim part of `minecarts`, and `magic_carpets`): whole trips from one tile to another, made by clicking an NPC or an object. It walks to the tile the trip is boarded from, finds the NPC with the id the data's menu column ends with (else the object), clicks it with the option the menu starts with (the data doesn't mark where the option ends and the name begins, so every beginning is tried, longest first), then follows the dialogue until it lands: the option that names the destination, else a yes, and "continue". When no option can be picked it gives up and logs the options it saw. False when it didn't work; the second result is true when the conversation ended with no trip (a captain who refuses the account), so trying again is pointless.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.ride(choice)
```

A portal (`teleportation_portals`) is the same trip: clicking it, and for one that asks where to go, like Soul Wars's, the data's label picks the answer. The Clan Wars free-for-all portal is left out, as a PvP arena. The Castle Wars team portals need an empty head and cape slot, which the data's `HEADSLOT` and `CAPESLOT` say and can't be checked, so they are left out too.

A magic carpet is the same trip with a slower end. The rug merchants all answer "Travel" with a list of places, some have an empty name in the NPC list, and the number in the data's label ("3: Nardah") is ignored because it moves. The ride glides the whole way, then hovers, then walks the player off the carpet, and the game ignores clicks until that is over, so the trip isn't done until the player has left the pose `CARPET_POSE` and the server has stopped moving it. A merchant that says nothing after the click is given up on after `CARPET_SILENT_MS`. A way with a carpet doesn't need `MIN_SAVING_TICKS`, only to be no slower than walking (unless a plan sets `min_saving_ticks`), and each ride's cost has `CARPET_BONUS_TICKS` taken off, so a ride beats a walk of about the same length. The fare in the data need not be held once the Desert hard diary is done, which makes the rides free (`Diaries.tier`).

## Transports.dialogue_pick

Definition:
```luau
function Transports.dialogue_pick(options: { { text: string } }, hints: { string }): string?
```
The text of the dialogue option to pick for a ride: the first that contains one of `hints` (pieces of the destination's name, lowercase, four letters or more), else the first that starts with a yes (`yes`, `ok`, `sure`, `pay`, `go`, `travel`, `take`, `accept`, `board`); nil when there is none.

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

Waits `ITEM_TIMEOUT_MS` to land. The second result is true when trying again is pointless (item not held, destination not offered). The planner (`choose`) prices an item by the data's `Duration`, `ITEM_SLACK_TICKS`, and for a consumable one `ITEM_CHARGE_TICKS` more, so a charge isn't spent on a short hop; items are off with `Transports.ITEMS = false` or `exclude = { items = true }` (or an item's name). The player's house teleports are left out, the Wilderness follows the rule under `Transports.choose`, and the capes' `Max ...` skill rows are not tested (holding the cape is the proof).

Example:
```luau
local Transports = require("@lib/main/transports")

local choice = Transports.choose(here, goal)
if choice and choice.kind == "item" then
	print(Transports.use(choice))
end
```

## Transports.teleport_item

Definition:
```luau
function Transports.teleport_item(name: string): (boolean, boolean?)
```
Uses the teleport item of the data's row called `name` ("Ring of dueling: Ferox Enclave"), held or worn, without planning, and waits to land, as `Transports.use_item` does. For a script that wants one trip rather than the fastest one. False when the data has no such row or the trip didn't work; the second result is true when trying again is pointless (no such row, the item isn't held, the destination isn't offered).

Example:
```luau
local Transports = require("@lib/main/transports")

print(Transports.teleport_item("Ring of dueling: Ferox Enclave"))
```

## Transports.teleport_spell

Definition:
```luau
function Transports.teleport_spell(name: string): (boolean, boolean?)
```
Casts the teleport spell of the data's row called `name` ("Varrock Teleport", "Camelot Teleport: Seers'"), without planning, and waits to land, as `Transports.cast` does. The spell's own checks are the game's: `Magic.can_cast` decides, so hold the runes and be on its spellbook first. False when the data has no such row or the cast didn't work; the second result is true when trying again is pointless (no such row, a slow cast that never started).

Example:
```luau
local Transports = require("@lib/main/transports")

print(Transports.teleport_spell("Varrock Teleport"))
```

## Transports.whistle

Definition:
```luau
function Transports.whistle(choice: Choice): (boolean, boolean?)
```
Takes a trip with a quetzal whistle (`kind = "quetzal_whistle"`; the data's `quetzal_whistle`), then waits `ITEM_TIMEOUT_MS` to land. When `choice.option` is the game's last site (`Quetzal.is_last`) it mostly uses `Quetzal.signal_last`, with the same chance as an item's submenu (`ITEM_SUBMENU_BASE` plus the rest weighted by `Biometrics.CHOOSEOPTION`); otherwise `Quetzal.signal` opens the whistle's map and `Quetzal.select` picks the site. The second result is true when the whistle did nothing, which is what an empty one does, so trying again is pointless.

The whistle is priced like a consumable item, so Renu wins when one is close and the whistle wins from far away. It is one of the `items` for `exclude` and `Transports.ITEMS`, and "Quetzal whistle" is its name. Every site shares one failure, so an empty whistle is tried once per `RETRY_AFTER_MS`, not once per site. The charges can't be read from the game's variables, so the chooser doesn't know a whistle is empty until it refuses.

## Transports.minigame

Definition:
```luau
function Transports.minigame(choice: Choice): (boolean, boolean?)
```
Takes a minigame teleport (`kind = "minigame"`; the data's `teleportation_minigames`), by the spell's list or the Grouping view (`Minigames.teleport`), then waits to land like a slow cast: the row's duration plus `SLOW_CAST_SLACK_MS`, with `SLOW_CAST_START_MS` to start animating. `choice.spell` is the activity and `choice.option` the rat pit. The second result is true when the cast never started.

The rows' `888@20` is the 20 minute cooldown: varp 888 keeps the Unix minute of the last one that finished, seen equal to the clock after one was cast. Clan Wars and Last Man Standing land at Ferox Enclave, inside the Wilderness, so they follow the rule under `Transports.choose`. `exclude = { minigames = true }` turns them all off, and `exclude = { ["Castle Wars"] = true }` one of them.

## Transports.scroll_book

Definition:
```luau
function Transports.scroll_book(choice: Choice): (boolean, boolean?)
```
Takes a trip with a scroll from the master scroll book (`kind = "scroll_book"`; the book's rows of the data's `teleportation_items`): `Scrollbook.open` opens the book and `Scrollbook.select` activates `choice.option`, then it waits `ITEM_TIMEOUT_MS` to land. The second result is true when the book didn't open, so trying again is pointless.

The rows check how many are held from the game's varbits, so a scroll with none held is never chosen. The book counts as an item: `exclude = { items = true }` or `exclude = { ["Master scroll book"] = true }` turns it off, and each trip is priced like a consumable (`ITEM_CHARGE_TICKS`). What a scroll is worth in coins isn't weighed.

## Transports.use

Definition:
```luau
function Transports.use(choice: Choice): boolean
```
Uses the chosen transport, whatever its kind: up to `ATTEMPTS` (3) tries with `RETRY_PAUSE_MS` between. A trip that landed late counts as done rather than being tried again, so a retry never spends a second charge. If every try fails, or a runner says trying again is pointless, it is marked failed for `RETRY_AFTER_MS` (5 minutes) and the next plan leaves it out; this then returns false. True when one worked.

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
Goes through the chosen gate or barrier: walks to the tile before it, clicks the object between the two tiles by name (the object changes with quest progress: `Pay-toll(2-Ecto)` before it, `Pass` after) and waits to be on the other side. False when it didn't work; `Transports.use` then decides what to do.

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
Pulls the chosen lever (`teleportation_levers.tsv`): walks to the tile the row gives (`LEVER_OBJECT_NEAR` tiles around it), clicks the option the row's menu column names on the object it names, and waits up to `LEVER_TIMEOUT_MS` to land within `LEVER_ARRIVED_NEAR` of the row's destination tile. The wilderness lever names its destination rather than offering `Pull`, so a row is one option: `Ardougne Lever 1815` is the option `Ardougne` on object 1815 and `Pull Lever 1814` is the option `Pull` on object 1814. Levers follow the Wilderness rule under `Transports.choose`, without a level cap, because the wilderness levers have to be pullable from there. False when it didn't work; `Transports.use` then decides what to do.

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

## Transports.disembark

Definition:
```luau
function Transports.disembark(to: Tile): boolean
```
Gets off a boat: crosses the gangplank onto the dock at `to`, for at most `CROSS_TIMEOUT_MS`, and waits for the scene to settle. False when it didn't get there.

Example:
```luau
local Transports = require("@lib/main/transports")

-- Transports.disembark({ x = 2760, y = 3238, plane = 0 })
```
