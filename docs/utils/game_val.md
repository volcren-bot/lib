# Utils.GameVal

Looking up readable names for the game's internal numbers: objects, NPCs, interfaces, animations and more.

```luau
local GameVal = require("../utils/game_val")
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
The kinds of things you can look up. Pass one of these as `kind`.

## GameVal.name

Definition:
```luau
function GameVal.name(kind: number, id: number): string?
```
The readable name of one thing.

Example:
```luau
local GameVal = require("../utils/game_val")

print(GameVal.name(GameVal.OBJ, 995))
```

## GameVal.names

Definition:
```luau
function GameVal.names(kind: number, ids: { number }): { string? }?
```
The readable names of many things of the same kind at once.

Example:
```luau
local GameVal = require("../utils/game_val")

for _, name in ipairs(GameVal.names(GameVal.NPC, { 1, 2, 3 }) or {}) do
	print(name)
end
```

## GameVal.interface

Definition:
```luau
function GameVal.interface(group: number): string?
```
The readable name of an interface from its group number.

Example:
```luau
local GameVal = require("../utils/game_val")

print(GameVal.interface(149))
```
