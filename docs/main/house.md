# Main.House

The player's house: an instance whose layout each player chooses and can change, so nothing here knows a room or a tile. Furniture is found by name in the scene of this visit, on any floor.

```luau
local House = require("@lib/main/house")
```

The transport data calls the whole house one tile (`House.TILE`), and so does the chooser: every way in arrives there and every way out leaves from there. See `Transports.house`.

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
Where the house is, by the game's number (varbit 2187; 1 is Rimmington).

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

What each kind of furniture is called, as a list of name parts: `nexus`, `box`, `glory`, `cape`, `talisman`, `digsite`, `fairy_ring` and `spirit_tree`. A Spiritual Fairy Tree is both of the last two.

## House.survey

Definition:
```luau
function House.survey()
```
Looks around the house the player is in and remembers what is built, for `House.seen`. `Transports.choose` does this whenever it runs inside a house. Someone else's house counts as much as your own, until the next look.

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
