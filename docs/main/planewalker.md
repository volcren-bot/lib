# Main.Planewalker

## PlaneWalker.use

Definition:
```luau
function PlaneWalker.use(transport: Transport): boolean
```
Uses a transport: finds its object next to its `from` tile (within `PlaneWalker.OBJECT_RADIUS`), clicks the transport's option and waits for the player to be on the plane it leads to. Returns whether it did.

Example:
```luau
local PlaneWalker = require("../main/planewalker")
local Transports = require("../main/transports")

local transport = Transports.all()[1]
print(PlaneWalker.use(transport))
```

## PlaneWalker.walk

Definition:
```luau
function PlaneWalker.walk(to: Tile, plane: number, options: Walker.WalkOptions?): boolean
```
Walks to a tile, on another plane or past doors. It looks up the ladders and staircases around (`Transports.discover_around`, unless `PlaneWalker.DISCOVER` is false), plans with `Transports.plan` from where the player is, walks to the first transport of the plan, uses it, and plans again from where it lands, so planes in between are crossed the same way. Fails with a log when there is no way or a transport can't be used `PlaneWalker.MAX_FAILURES` times in a row. `Walker.walk` calls it when given `options.plane`.

Example:
```luau
local PlaneWalker = require("../main/planewalker")

print(PlaneWalker.walk({ x = 3205, y = 3209 }, 2))
```

## PlaneWalker.cross

Definition:
```luau
function PlaneWalker.cross(transport: Transport): boolean
```
Gets through a door from the tile beside it. It reads the live door now that it is loaded: a closed one (a loc of the door's id on its tile) is opened and waited for, an open one is skipped. Then it walks to the tile on the other side. `PlaneWalker.walk` calls it for the door steps of a plan.

Example:
```luau
local PlaneWalker = require("../main/planewalker")
local Transports = require("../main/transports")

for _, transport in ipairs(Transports.all()) do
	if transport.door then
		print(PlaneWalker.cross(transport))
		break
	end
end
```
