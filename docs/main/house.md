# Main.House

The player's house: an instance whose layout each player chooses and can change, so nothing here knows a room or a tile. Furniture is found by name in the scene of this visit, on any floor.

```luau
local House = require("@lib/main/house")
```

The transport data calls the whole house one tile (`House.TILE`), and so does the chooser: every way in arrives there and every way out leaves from there. See `Transports.house`.

**What can be read from anywhere, without opening anything.** The house's town, the Portal Nexus's teleports by name (its slot variables, named through the cache's list of Nexus teleports), the left-click Nexus teleport, and the jewellery box's size once it is fancy or ornate. What else is built, the mounted pieces, the pool and the altar, only shows inside, in the scene: `House.survey` remembers it for the rest of the run. Which of the box's places are struck through for the account only shows in the box itself.

**Doing things.** `House.teleport` takes you somewhere by whatever in the house offers it, `House.start_teleport` by one piece without waiting, `House.restore` drinks from the pool and `House.leave` goes out by the portal. The spellbook altar is `OccultAltar`.

## Constants

Definition:
```luau
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
How long `teleport` waits to leave the house and `restore` waits for the pool. The town variable and its names. The Nexus's 30 slots in list order (`poh_nexus_tele_1` to `_30`), each holding a teleport's key or 0, and its left-click teleport. The cache's list of Nexus teleports (an enum of key to struct) and the struct param holding the name. The three teleports with a second place, listed right after them once a diary is done: Varrock's Grand Exchange (Varrock medium), Camelot's Seers' Village (Kandarin hard) and Watchtower's Yanille (Ardougne hard). The box's size variable (`poh_jewellerybox_multi`: 0 basic, 1 fancy, 2 ornate; 0 is also a house without a box), the sizes, the places each size adds to the one below, and the places of each mounted piece.

## House.Furniture

Definition:
```luau
export type Furniture = "nexus" | "box" | "glory" | "cape" | "talisman" | "digsite"
```
What can take you somewhere from inside the house.

## House.BoxTier

Definition:
```luau
export type BoxTier = "basic" | "fancy" | "ornate"
```
The jewellery box's sizes, smallest first; each offers the places of the ones below it too.

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
A Nexus teleport: its key in the cache's list, its name as the Nexus lists it ("Fenken' Castle"), its slot (1 to 30), and for a second place the teleport it belongs to ("Varrock" for "Grand Exchange"), which shares that slot.

## House.inside

Definition:
```luau
function House.inside(): boolean
```
Whether the player is in a house, theirs or another's: an instance with the exit portal in it.

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
Whether a tile is the data's stand-in for the house.

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
Where the house is, by the game's number (varbit 2187; 1 is Rimmington). Its name is `House.location_name`.

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
The nearest clickable loc whose name contains `what` (or any of a list), ignoring case, or with this id: on the player's floor if there is one, else on another.

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
Goes to a floor by the nearest staircase, one flight at a time. True once on it.

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
Finds something built and gets on its floor. The loc to click, or nil when it isn't built or can't be reached.

Example:
```luau
local House = require("@lib/main/house")

print(House.reach("Portal Nexus") ~= nil)
```

## House.FURNITURE

What each kind of furniture is called, as a list of name parts: `nexus`, `box`, `glory`, `cape`, `talisman`, `digsite`, `fairy_ring`, `spirit_tree`, `pool` and `occult_altar`. A Spiritual Fairy Tree is both a fairy ring and a spirit tree.

## House.survey

Definition:
```luau
function House.survey()
```
Looks around the house the player is in and remembers what is built and its name, for `House.seen` and `House.furniture`. `Transports.choose` does this whenever it runs inside a house. Someone else's house counts as much as your own, until the next look.

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
Whether this kind of furniture (a key of `House.FURNITURE`) was built at the last look around, or nil when no look has been taken this run. It isn't kept between runs.

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
The name of this kind of furniture at the last look around ("Ornate pool of Rejuvenation", "Ornate Jewellery Box"), nil when none was seen or no look has been taken this run.

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
Whether two names are the same place, compared word by word ignoring case and punctuation. A word cut short with an apostrophe stands for any word it starts ("Fenken' Castle" is "Fenkenstrain's Castle"), and one name may be the start of the other ("Kourend" is "Kourend Castle"). A word is never part of another, so "Trollheim" isn't "Troll Stronghold".

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
The house's town (`House.LOCATIONS`), nil when it can't be read.

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
The Portal Nexus's teleports in its list's order, from anywhere and without opening it: empty when it has none or there is no Nexus. The names come from the cache once per run, which takes most of a second the first time. A second place (`House.NEXUS_ALTERNATES`) follows its teleport once its diary is done, as in the game's list.

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
The Nexus teleport to `name`, the exact name first and then `House.same_place`; nil when the Nexus doesn't have it.

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
The name of the Nexus's left-click teleport, nil when it has none.

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
The jewellery box's size: what the last look around saw, else the variable. Nil when neither says: outside, before a visit, a basic box reads the same as none.

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
Every place a box of this size offers, by default the house's (`House.box_tier`), in its menu's order, as the box names them; empty when the size isn't known. Some may be struck through for the account, which only the box shows.

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
What in the house can take you to `place`, by `House.same_place`: the Nexus and the box from what the variables say (unless a visit this run showed them missing), and the mounted pieces once a visit has shown them.

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
Starts a teleport to `place` from inside the house by one piece of furniture, going to its floor and walking to it first: the Nexus (`Nexus`), the box (`Jewellerybox`) or a mounted piece (`Mounted`). The trip itself isn't waited for. False with why when it didn't start, and true third when trying again is pointless: the piece isn't built or doesn't offer the place.

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
Teleports to `place` from inside the house by whatever offers it (`House.offers`), the nearest piece first when several do, and waits to leave the house. False and why.

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
Drinks from the house's pool, of any kind, and waits for it to take (`Player.restore_with`). False and why.

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
Leaves by the portal, wherever it is. True once outside.

Example:
```luau
local House = require("@lib/main/house")

print(House.leave())
```
