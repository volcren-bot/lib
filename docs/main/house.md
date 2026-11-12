# Main.House

The player's house. Its layout is the player's choice, so nothing here assumes a room or tile: furniture is found by name in the current scene, on any floor.

```luau
local House = require("@lib/main/house")
```

The transport data treats the whole house as one tile, `House.TILE`: every way in arrives there and every way out leaves from there (see `Transports.house`). From anywhere you can read the house's town, the Portal Nexus teleports and its left-click, and the jewellery box size once fancy or ornate. Mounted pieces, the pool and the altar only show inside; `House.survey` remembers them for the run. Struck-through box places only show in the box. The spellbook altar is `OccultAltar`.

## Constants

Definition:
```luau
House.TILE = { x = 1858, y = 7051, plane = 0 }
House.EXIT_PORTAL = 4525
House.EXIT_OPTION = "Enter"
House.STAIRS = "Staircase"
House.CLIMB_UP = "Climb-up"
House.CLIMB_DOWN = "Climb-down"
House.PLANES = 4
House.SIZE = 104
House.POLL_MS = 100
House.STAIRS_TIMEOUT_MS = 10000
House.LEAVE_TIMEOUT_MS = 15000
House.TELEPORT_TIMEOUT_MS = 10000
House.RESTORE_TIMEOUT_MS = 8000
House.LOCATION_VARBIT = 2187
House.LOCATIONS = { [1] = "Rimmington", [2] = "Taverley", ... }
House.NEXUS_SLOT_VARBITS = { 6654, ..., 10091 }
House.NEXUS_LEFT_CLICK_VARBIT = 6653
House.NEXUS_ENUM = 1377
House.NEXUS_NAME_PARAM = 660
House.NEXUS_ALTERNATES = { [1] = { key = 151, unlocked_by = 4480 }, ... }
House.BOX_VARBIT = 2308
House.BOX_TIERS = { "basic", "fancy", "ornate" }
House.BOX_PLACES = { basic = { ... }, fancy = { ... }, ornate = { ... } }
House.MOUNTED_PLACES = { glory = { ... }, cape = { ... }, talisman = { ... }, digsite = { ... } }
House.POOL_OPTION = "Drink"
```
- `TILE`: the data's stand-in tile for the house. `EXIT_PORTAL`/`EXIT_OPTION`: the exit portal loc and its option.
- `STAIRS`, `CLIMB_UP`, `CLIMB_DOWN`: staircase name and options. `PLANES`, `SIZE`: floors and scene size searched.
- `*_TIMEOUT_MS`, `POLL_MS`: waits for stairs, leaving, `teleport` and `restore`.
- `LOCATION_VARBIT`, `LOCATIONS`: the town variable and its names.
- `NEXUS_SLOT_VARBITS`: the 30 Nexus slots in list order, each a teleport key or 0. `NEXUS_LEFT_CLICK_VARBIT`: its left-click.
- `NEXUS_ENUM`, `NEXUS_NAME_PARAM`: the cache enum of Nexus teleports (key to struct) and the struct's name param.
- `NEXUS_ALTERNATES`: second places (Grand Exchange, Seers' Village, Yanille) by slot, listed after their teleport once the diary varbit `unlocked_by` is set.
- `BOX_VARBIT`: box size (0 basic or none, 1 fancy, 2 ornate). `BOX_TIERS`, `BOX_PLACES`: sizes and the places each adds to the one below.
- `MOUNTED_PLACES`: places of each mounted piece. `POOL_OPTION`: the pool's option.

## House.Furniture

Definition:
```luau
export type Furniture = "nexus" | "box" | "glory" | "cape" | "talisman" | "digsite"
```
Furniture that teleports.

## House.BoxTier

Definition:
```luau
export type BoxTier = "basic" | "fancy" | "ornate"
```
Box sizes, smallest first; each includes the places of smaller ones.

## House.NexusTeleport

Definition:
```luau
export type NexusTeleport = {
	key: number,
	name: string,
	slot: number,
	alternate_of: string?,
}
```
Cache key, Nexus name ("Fenken' Castle"), slot 1-30, and for an alternate the teleport whose slot it shares ("Varrock" for "Grand Exchange").

## House.inside

Definition:
```luau
function House.inside(): boolean
```
Whether the player is in any house: the scene has the exit portal.

Example:
```luau
local House = require("@lib/main/house")

print(House.inside())
```

## House.is_tile

Definition:
```luau
function House.is_tile(tile: { x: number, y: number }): boolean
```
Whether a tile is `House.TILE` (x and y only).

Example:
```luau
local House = require("@lib/main/house")

print(House.is_tile(House.TILE))
```

## House.location

Definition:
```luau
function House.location(): number?
```
The house's town number (`LOCATION_VARBIT`; 1 is Rimmington). See `House.location_name`.

Example:
```luau
local House = require("@lib/main/house")

print(House.location())
```

## House.find

Definition:
```luau
function House.find(what: string | number | { string }): Host.Loc?
```
The nearest loc with this id, or whose name contains `what` (or any of a list) ignoring case. Prefers the player's floor, else any floor; nil when none.

Example:
```luau
local House = require("@lib/main/house")

local box = House.find("jewellery box")
print(box and box.plane)
```

## House.go_to_floor

Definition:
```luau
function House.go_to_floor(plane: number): boolean
```
Climbs to a floor by the nearest staircase, one flight at a time. True once on it.

Example:
```luau
local House = require("@lib/main/house")

print(House.go_to_floor(1))
```

## House.reach

Definition:
```luau
function House.reach(what: string | number | { string }): Host.Loc?
```
`House.find`, then goes to its floor. The loc, or nil when not built or unreachable.

Example:
```luau
local House = require("@lib/main/house")

print(House.reach("Portal Nexus") ~= nil)
```

## House.FURNITURE

Name parts per furniture kind: `nexus`, `box`, `glory`, `cape`, `talisman`, `digsite`, `fairy_ring`, `spirit_tree`, `pool`, `occult_altar`. A Spiritual Fairy Tree counts as both fairy ring and spirit tree.

## House.survey

Definition:
```luau
function House.survey()
```
Records which `FURNITURE` kinds are built in the current house, and their names, for `House.seen`/`House.furniture`. Kept for the run until the next survey, whoever's house it is. `Transports.choose` calls it inside a house.

Example:
```luau
local House = require("@lib/main/house")

if House.inside() then
	House.survey()
end
```

## House.seen

Definition:
```luau
function House.seen(kind: string): boolean?
```
Whether this `FURNITURE` kind was built at the last survey; nil before any survey this run.

Example:
```luau
local House = require("@lib/main/house")

print(House.seen("fairy_ring"))
```

## House.furniture

Definition:
```luau
function House.furniture(kind: string): string?
```
The name of this kind at the last survey ("Ornate Jewellery Box"); nil when not seen or no survey this run.

Example:
```luau
local House = require("@lib/main/house")

House.survey()
print(House.furniture("pool"))
```

## House.same_place

Definition:
```luau
function House.same_place(a: string, b: string): boolean
```
Word-by-word comparison ignoring case and punctuation. A word ending in an apostrophe matches any word it starts ("Fenken' Castle"), and one name may be a word prefix of the other ("Kourend" = "Kourend Castle"); "Trollheim" is not "Troll Stronghold".

Example:
```luau
local House = require("@lib/main/house")

print(House.same_place("Fenken' Castle", "Fenkenstrain's Castle")) -- true
```

## House.location_name

Definition:
```luau
function House.location_name(): string?
```
The house's town from `LOCATIONS`; nil when unreadable.

Example:
```luau
local House = require("@lib/main/house")

print(House.location_name()) -- Rimmington
```

## House.nexus_teleports

Definition:
```luau
function House.nexus_teleports(): { NexusTeleport }
```
The Nexus teleports in list order, read from anywhere without opening it; empty when there is no Nexus. Names load from the cache once per run (most of a second the first time). Unlocked alternates follow their teleport, as in the game.

Example:
```luau
local House = require("@lib/main/house")

for _, t in ipairs(House.nexus_teleports()) do
	print(t.slot, t.name, t.alternate_of)
end
```

## House.nexus_teleport

Definition:
```luau
function House.nexus_teleport(name: string): NexusTeleport?
```
The Nexus teleport matching `name` exactly, else by `House.same_place`; nil when absent.

Example:
```luau
local House = require("@lib/main/house")

print(House.nexus_teleport("Fenkenstrain's Castle") ~= nil)
```

## House.nexus_left_click

Definition:
```luau
function House.nexus_left_click(): string?
```
The Nexus's left-click teleport name; nil when none.

Example:
```luau
local House = require("@lib/main/house")

print(House.nexus_left_click())
```

## House.box_tier

Definition:
```luau
function House.box_tier(): BoxTier?
```
The box size from the last survey, else `BOX_VARBIT`. Nil when a survey saw no box, or unsurveyed and the varbit is 0 (basic reads as none).

Example:
```luau
local House = require("@lib/main/house")

print(House.box_tier()) -- ornate
```

## House.box_places

Definition:
```luau
function House.box_places(tier: BoxTier?): { string }
```
All places a box of `tier` (default `House.box_tier()`) offers, in menu order; empty when the size is unknown. Doesn't know which are struck through for the account.

Example:
```luau
local House = require("@lib/main/house")

print(#House.box_places("ornate")) -- 27
```

## House.offers

Definition:
```luau
function House.offers(place: string): { Furniture }
```
Furniture that goes to `place` (`House.same_place`): the Nexus and box from varbits unless a survey showed them missing, mounted pieces only once a survey saw them.

Example:
```luau
local House = require("@lib/main/house")

print(table.concat(House.offers("Grand Exchange"), ", ")) -- nexus, box
```

## House.start_teleport

Definition:
```luau
function House.start_teleport(by: Furniture, place: string): (boolean, string?, boolean?)
```
Starts a teleport by one piece (through `Nexus`, `Jewellerybox` or `Mounted`), reaching it first; doesn't wait for arrival. On failure returns false, why, and a third `true` when retrying is pointless (not built, or doesn't offer `place`).

Example:
```luau
local House = require("@lib/main/house")

print(House.start_teleport("nexus", "Varrock"))
```

## House.teleport

Definition:
```luau
function House.teleport(place: string): (boolean, string?)
```
Teleports by whatever `House.offers`, nearest piece first, trying the next if one fails to start, and waits up to `TELEPORT_TIMEOUT_MS` to leave the house. False and why otherwise.

Example:
```luau
local House = require("@lib/main/house")

print(House.teleport("Ferox Enclave"))
```

## House.restore

Definition:
```luau
function House.restore(): (boolean, string?)
```
Drinks from any pool and waits for the restore (`Player.restore_with`). False and why.

Example:
```luau
local House = require("@lib/main/house")

print(House.restore())
```

## House.leave

Definition:
```luau
function House.leave(): boolean
```
Leaves by the exit portal. True once outside.

Example:
```luau
local House = require("@lib/main/house")

print(House.leave())
```
