# Utils.GameVal

Readable names for the game's internal ids (objects, NPCs, interfaces, animations...).

```luau
local GameVal = require("@lib/utils/game_val")
```

## Constants

Definition:
```luau
GameVal.OBJ = 0
GameVal.NPC = 1
GameVal.INV = 2
GameVal.VARP = 3
GameVal.VARBIT = 4
GameVal.LOC = 6
GameVal.SEQ = 7
GameVal.SPOT = 8
GameVal.ROW = 9
GameVal.TABLE = 10
GameVal.JINGLE = 11
GameVal.SPRITE = 12
GameVal.INTERFACE = 14
GameVal.VARC = 15
```
The `kind` values.

## GameVal.name

Definition:
```luau
function GameVal.name(kind: number, id: number): string?
```
Name of one id of `kind`.

Example:
```luau
local GameVal = require("@lib/utils/game_val")

print(GameVal.name(GameVal.OBJ, 995))
```

## GameVal.names

Definition:
```luau
function GameVal.names(kind: number, ids: { number }): { string? }?
```
Names of many ids of one `kind`.

Example:
```luau
local GameVal = require("@lib/utils/game_val")

for _, name in ipairs(GameVal.names(GameVal.NPC, { 1, 2, 3 }) or {}) do
	print(name)
end
```

## GameVal.interface

Definition:
```luau
function GameVal.interface(group: number): string?
```
Name of an interface group.

Example:
```luau
local GameVal = require("@lib/utils/game_val")

print(GameVal.interface(149))
```
