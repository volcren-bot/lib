# Main.Position

A small helper for a position in the world and the 64x64 map chunk it belongs to.

```luau
local Position = require("../main/position")
```

## Position.new

Definition:
```luau
function Position.new(local_x: number, local_y: number, x: number, y: number, plane: number?): Position
```
Creates a position from its tile inside the loaded area (`local_x`, `local_y`), its world tile (`x`, `y`) and its `plane` (0, the ground floor, when not given).

Example:
```luau
local Position = require("../main/position")

local pos = Position.new(52, 52, 3200, 3200)
print(pos.x, pos.y)
```

## Position.chunk

Definition:
```luau
function Position.chunk(self: Position): Chunk
```
Returns the 64x64 tile chunk that this position is in.

Example:
```luau
local Position = require("../main/position")

local chunk = Position.new(0, 0, 3200, 3200):chunk()
print(chunk.x, chunk.y)
```

## Position.in_instance

Definition:
```luau
function Position.in_instance(self: Position): boolean
```
Whether this position is inside an instance (a minigame, raid or other private copy of an area). The game places instances in the map east of x = 6400, which the overworld never reaches, so this is a coordinate check on this position. To ask about the instance you are in now, use `Player.in_instance`, which reads the game client's own flag. Instances move around: a Tempoross game gets new coordinates every time, so test with these and not with a fixed box.

Example:
```luau
local Position = require("../main/position")

print(Position.new(0, 0, 13265, 14527):in_instance()) -- true
print(Position.new(0, 0, 3140, 2839):in_instance()) -- false
```

## Position.Chunk

Definition:
```luau
Position.Chunk: { id: (self: Chunk) -> number }
```
The chunk type that `Position.chunk` returns. It has an `x`, a `y` and an `id` function.

## Chunk.new

Definition:
```luau
function Chunk.new(x: number, y: number): Chunk
```
Creates a 64x64 chunk from its coordinates (a tile's x and y divided by 64, rounded down).

Example:
```luau
local Position = require("../main/position")

local chunk = Position.Chunk.new(47, 44)
print(chunk:id()) -- 12076
```

## Chunk.id

Definition:
```luau
function Chunk.id(self: Chunk): number
```
A single number that identifies the chunk (its `x` and `y` combined).

Example:
```luau
local Position = require("../main/position")

local chunk = Position.new(0, 0, 3200, 3200):chunk()
print("chunk id:", chunk:id())
```
