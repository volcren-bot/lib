# Main.Entities.Npcs

Finding and interacting with NPCs (the non-player characters walking around): talk to them, attack them, trade with them.

```luau
local Npcs = require("../main/entities/npcs")
```

An NPC is a table with `index`, `id`, `name`, `x`, `y` (world tile) and `local_x`, `local_y`. Names are matched ignoring upper/lower case.

## Npcs.clean_name

Definition:
```luau
function Npcs.clean_name(name: string): string
```
An NPC's name without its colour tags. Some NPCs, minigame ones especially, come named like `<col=00ffff>Spirit pool</col>`. `Npcs.find` and `Npcs.nearest` already compare names this way.

Example:
```luau
local Npcs = require("../main/entities/npcs")

for _, npc in ipairs(Npcs.find() or {}) do
	print(Npcs.clean_name(npc.name))
end
```

## Npcs.distance

Definition:
```luau
function Npcs.distance(a: Tile, b: Tile): number
```
How many tiles apart two tiles are (diagonal steps count as one).

Example:
```luau
local Npcs = require("../main/entities/npcs")

print(Npcs.distance({ x = 3200, y = 3200 }, { x = 3203, y = 3201 })) -- 3
```

## Npcs.find

Definition:
```luau
function Npcs.find(what: (string | number)?): { Npc }?
```
Lists the NPCs around you. Give a name or an id to only get matching ones, or nothing to get all of them.

Example:
```luau
local Npcs = require("../main/entities/npcs")

for _, npc in ipairs(Npcs.find("Man") or {}) do
	print(npc.name, npc.x, npc.y)
end
```

## Npcs.nearest

Definition:
```luau
function Npcs.nearest(what: (string | number)?, from: Tile): Npc?
```
The closest matching NPC to a tile. Returns `nil` when there is none.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local npc = Npcs.nearest("Man", me)
print(if npc then `{npc.name} is {Npcs.distance(npc, me)} tiles away` else "no man around")
```

## Npcs.refresh

Definition:
```luau
function Npcs.refresh(npc: Npc): Npc?
```
Gets the up-to-date version of an NPC you found earlier (it may have walked somewhere else). Returns `nil` if it is gone.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local npc = Npcs.nearest("Man", assert(Walker.position()))
if npc then
	local now = Npcs.refresh(npc)
	print(if now then `now at {now.x}, {now.y}` else "gone")
end
```

## Npcs.model

Definition:
```luau
function Npcs.model(npc: Npc): NpcModel?
```
The shape of the NPC as drawn on screen right now.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local npc = Npcs.nearest("Man", assert(Walker.position()))
local model = npc and Npcs.model(npc)
print(model and #model.faces)
```

## Npcs.clickbox

Definition:
```luau
function Npcs.clickbox(npc: Npc): Clickbox?
```
The area on screen where a click lands on the NPC. See [Clickbox](../clickbox.md).

Example:
```luau
local Clickbox = require("../main/clickbox")
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local npc = Npcs.nearest("Man", assert(Walker.position()))
local box = npc and Npcs.clickbox(npc)
if box then
	Clickbox.draw(box)
end
```

## Npcs.target

Definition:
```luau
function Npcs.target(npc: Npc): Point?
```
A good point on screen to click on the NPC.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local npc = Npcs.nearest("Man", assert(Walker.position()))
local point = npc and Npcs.target(npc)
print(point and point.x, point and point.y)
```

## Npcs.owns

Definition:
```luau
function Npcs.owns(npc: Npc, entry: MenuEntry): boolean
```
Whether a right-click menu line belongs to this exact NPC (and not another NPC with the same name).

Example:
```luau
local Host = require("../host")
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local npc = Npcs.nearest("Man", assert(Walker.position()))
if npc then
	for _, entry in ipairs(Host.menu() or {}) do
		print(entry.option, Npcs.owns(npc, entry))
	end
end
```

## Npcs.hovered

Definition:
```luau
function Npcs.hovered(npc: Npc): boolean
```
Whether the game currently has the mouse on this NPC.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local npc = Npcs.nearest("Man", assert(Walker.position()))
if npc then
	print("mouse is on it:", Npcs.hovered(npc))
end
```

## Npcs.hover

Definition:
```luau
function Npcs.hover(npc: Npc): boolean
```
Moves the mouse onto the NPC, aiming again if it walks away, until the game confirms the mouse is on it. If the NPC is nearby but off screen, the camera is turned and zoomed out first.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local npc = Npcs.nearest("Man", assert(Walker.position()))
if npc then
	print(Npcs.hover(npc))
end
```

## Npcs.hover_async

Definition:
```luau
function Npcs.hover_async(npc: Npc): boolean
```
Like `Npcs.hover`, but queues the move as async input and returns at once, without turning the camera or checking that the game lists it under the mouse. Returns `false` if the npc isn't on screen.

Example:
```luau
local Npcs = require("../main/entities/npcs")

local found = Npcs.find()
if found and #found > 0 then
	Npcs.hover_async(found[1])
end
```

## Npcs.click

Definition:
```luau
function Npcs.click(npc: Npc, button: Mouse.Button?): boolean
```
Hovers the NPC and clicks it (left button by default).

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local npc = Npcs.nearest("Man", assert(Walker.position()))
if npc then
	print(Npcs.click(npc))
end
```

## Npcs.interact

Definition:
```luau
function Npcs.interact(npc: Npc, option: string, walk_timeout_ms: (number | false)?): boolean
```
Picks an option (such as `"Talk-to"` or `"Attack"`) on this NPC. Retries if the wrong thing got clicked, and waits for you to arrive if it made you walk. `walk_timeout_ms` changes how long it waits; `false` skips the wait.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local npc = Npcs.nearest("Man", assert(Walker.position()))
if npc then
	local ok = Npcs.interact(npc, "Talk-to")
	print(ok)
end
```

## Npcs.projected

Definition:
```luau
function Npcs.projected(npc: Npc, at: Tile): Clickbox?
```
The NPC's box as the camera will show it once the player stands on `at`: the cuboid around its tile (see `Projection.cuboid`), since that's all we know of it from there.

Example:
```luau
local Walker = require("../main/walker")
local Npcs = require("../main/entities/npcs")

local npc = assert(Npcs.nearest("Ferryman Nathwood", assert(Walker.position())))
local box = Npcs.projected(npc, { x = npc.x, y = npc.y })
```

## Npcs.approach

Definition:
```luau
function Npcs.approach(npc: Npc, options: string | { string }, opts: Clickbox.Approach?): boolean
```
Walks to the NPC and picks the first of `options` its menu has, walking early on the way when it's close (see `Clickbox.approach`).

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local npc = assert(Npcs.nearest("Ferryman Nathwood", assert(Walker.position())))
local ok = Npcs.approach(npc, { "Talk-to", "Examine" })
print(ok)
```
