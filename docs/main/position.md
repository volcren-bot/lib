# Main.Position

A world position and the 64x64 map chunk it is in.

```luau
local Position = require("@lib/main/position")
```

## Position.new

Definition:
```luau
function Position.new(local_x: number, local_y: number, x: number, y: number, plane: number?): Position
```
A position from its scene tile (`local_x`, `local_y`), world tile (`x`, `y`) and `plane` (default 0).

Example:
```luau
local pos = Position.new(52, 52, 3200, 3200)
print(pos.x, pos.y)
```

## Position.chunk

Definition:
```luau
function Position.chunk(self: Position): Chunk
```
The chunk containing the position (`x // 64`, `y // 64`).

Example:
```luau
local chunk = Position.new(0, 0, 3200, 3200):chunk()
print(chunk.x, chunk.y)
```

## Position.in_instance

Definition:
```luau
function Position.in_instance(self: Position): boolean
```
Whether `x >= 6400`, where the game places instances. For your current state use `Player.in_instance`, which reads the client's flag. Instance coordinates change every time, so don't test against fixed boxes.

Example:
```luau
print(Position.new(0, 0, 13265, 14527):in_instance()) -- true
print(Position.new(0, 0, 3140, 2839):in_instance()) -- false
```

## Position.Chunk

Definition:
```luau
Position.Chunk: { new: (x: number, y: number) -> Chunk, id: (self: Chunk) -> number }
```
The chunk class; a `Chunk` has `x` and `y`.

## Chunk.new

Definition:
```luau
function Chunk.new(x: number, y: number): Chunk
```
A chunk from chunk coordinates (tile coordinates `// 64`).

Example:
```luau
local chunk = Position.Chunk.new(47, 44)
print(chunk:id()) -- 12076
```

## Chunk.id

Definition:
```luau
function Chunk.id(self: Chunk): number
```
`x << 8 | y`, the game's region id.

Example:
```luau
print(Position.new(0, 0, 3200, 3200):chunk():id()) -- 12850
```
