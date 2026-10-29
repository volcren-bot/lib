# Main.Entities.SpotAnims

Finding the spot animations on tiles: the effects the server places at a spot, such as an impact, a splash or a falling rock.

```luau
local SpotAnims = require("../main/entities/spot_anims")
```

RuneLite calls these graphics objects. A spot animation is a `Host.SpotAnim`:

- `id` is its spot animation (graphic) id, the same id RuneLite's dev tools show.
- `x`, `y` and `plane` are the world tile it is on. `local_x` and `local_y` are the same place in fine units (128 to a tile).
- `z` is the client's own height: the ground's height at the tile minus the height the server asked for, so negative is up.
- `start_cycle` and `cycle` are client cycles (50 a second): when it starts playing, and now. It is listed from the moment the server sends it, which can be before it starts.

Effects on a character, like a teleport flash on you or a freeze on an NPC, are not listed here. They are the `graphic` of that `Npc` or `PlayerInfo`.

## Constants

Definition:
```luau
SpotAnims.CYCLE_MS = 20
```
How long a client cycle lasts. The game ticks every 600 ms, which is 30 cycles.

## SpotAnims.find

Definition:
```luau
function SpotAnims.find(what: (number | { number })?): { SpotAnim }?
```
Lists the spot animations on tiles. Give a graphic id or a list of ids to only get matching ones. Returns `nil` when they can't be read.

Example:
```luau
local SpotAnims = require("../main/entities/spot_anims")

for _, spot in ipairs(SpotAnims.find() or {}) do
	print(spot.id, spot.x, spot.y, spot.plane)
end
```

## SpotAnims.at

Definition:
```luau
function SpotAnims.at(tile: Tile, what: (number | { number })?): { SpotAnim }?
```
The spot animations on a world tile, optionally only those with the given graphic ids.

Example:
```luau
local SpotAnims = require("../main/entities/spot_anims")
local Walker = require("../main/walker")

local here = assert(Walker.position())
if #(SpotAnims.at(here) or {}) > 0 then
	print("something is landing on us")
end
```

## SpotAnims.tile

Definition:
```luau
function SpotAnims.tile(spot: SpotAnim): Tile
```
The world tile a spot animation is on.

Example:
```luau
local SpotAnims = require("../main/entities/spot_anims")

for _, spot in ipairs(SpotAnims.find() or {}) do
	local tile = SpotAnims.tile(spot)
	print(tile.x, tile.y)
end
```

## SpotAnims.starts_in_ms

Definition:
```luau
function SpotAnims.starts_in_ms(spot: SpotAnim): number
```
How long until a spot animation starts playing, 0 once it has.

Example:
```luau
local SpotAnims = require("../main/entities/spot_anims")

for _, spot in ipairs(SpotAnims.find() or {}) do
	print(spot.id, SpotAnims.starts_in_ms(spot))
end
```

## SpotAnims.age_ms

Definition:
```luau
function SpotAnims.age_ms(spot: SpotAnim): number
```
How long a spot animation has been playing, 0 while it waits to start.

Example:
```luau
local SpotAnims = require("../main/entities/spot_anims")

for _, spot in ipairs(SpotAnims.find() or {}) do
	print(spot.id, SpotAnims.age_ms(spot))
end
```
