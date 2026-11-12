# Main.Entities.SpotAnims

Spot animations placed on tiles by the server: impacts, splashes, falling rocks. Effects on a character (a teleport flash, a freeze) aren't listed here; they are the `graphic` of that `Npc` or `PlayerInfo`.

```luau
local SpotAnims = require("@lib/main/entities/spot_anims")
```

A `Host.SpotAnim` has:

- `id`: graphic id.
- `x`, `y`, `plane`: world tile; `local_x`, `local_y`: fine units (128 per tile).
- `view_id`: 0 for the main world, otherwise a moving sub-scene (such as a boat) whose coordinates are its own, not world tiles.
- `z`: client height, negative is up.
- `start_cycle`, `cycle`: client cycles (50/s) when it starts and now. It is listed as soon as the server sends it.

## Constants

Definition:

```luau
SpotAnims.CYCLE_MS = 20
```

One client cycle in ms (a 600 ms game tick is 30 cycles).

Example:

```luau
print(SpotAnims.CYCLE_MS)
```

## SpotAnims.find

Definition:

```luau
function SpotAnims.find(what: (number | { number })?): { SpotAnim }?
```

All tile spot animations, optionally matching a graphic id or list of ids. Nil when unreadable.

Example:

```luau
for _, spot in SpotAnims.find() or {} do
	print(spot.id, spot.x, spot.y)
end
```

## SpotAnims.at

Definition:

```luau
function SpotAnims.at(tile: Tile, what: (number | { number })?): { SpotAnim }?
```

Main-world (`view_id == 0`) spot animations on `tile`'s x and y, optionally filtered by id. The plane isn't compared.

Example:

```luau
if #(SpotAnims.at(assert(Walker.position())) or {}) > 0 then
	print("something is landing on us")
end
```

## SpotAnims.tile

Definition:

```luau
function SpotAnims.tile(spot: SpotAnim): Tile
```

The world tile it is on.

Example:

```luau
local tile = SpotAnims.tile(spot)
```

## SpotAnims.starts_in_ms

Definition:

```luau
function SpotAnims.starts_in_ms(spot: SpotAnim): number
```

Ms until it starts playing, 0 once started.

Example:

```luau
print(SpotAnims.starts_in_ms(spot))
```

## SpotAnims.age_ms

Definition:

```luau
function SpotAnims.age_ms(spot: SpotAnim): number
```

Ms it has been playing, 0 while waiting to start.

Example:

```luau
print(SpotAnims.age_ms(spot))
```
