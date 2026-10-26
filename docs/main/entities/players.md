# Main.Entities.Players

Finding and interacting with other players: follow them, trade with them or just look at who is around.

```luau
local Players = require("../main/entities/players")
```

A player is a table with `index`, `name`, `x`, `y` (world tile) and `local_x`, `local_y`. Names are matched ignoring upper/lower case.

## Players.distance

Definition:
```luau
function Players.distance(a: Tile, b: Tile): number
```
How many tiles apart two tiles are (diagonal steps count as one).

Example:
```luau
local Players = require("../main/entities/players")

print(Players.distance({ x = 10, y = 10 }, { x = 14, y = 12 })) -- 4
```

## Players.find

Definition:
```luau
function Players.find(name: string?): { PlayerInfo }?
```
Lists the players around you, or only those with the given name.

Example:
```luau
local Players = require("../main/entities/players")

for _, p in ipairs(Players.find() or {}) do
	print(p.name, p.x, p.y)
end
```

## Players.me

Definition:
```luau
function Players.me(): PlayerInfo?
```
Your own character in the list of players.

Example:
```luau
local Players = require("../main/entities/players")

local me = Players.me()
print(me and me.name)
```

## Players.nearest

Definition:
```luau
function Players.nearest(from: Tile): PlayerInfo?
```
The closest other player to a tile (never yourself).

Example:
```luau
local Players = require("../main/entities/players")
local Walker = require("../main/walker")

local other = Players.nearest(assert(Walker.position()))
print(if other then other.name else "nobody else around")
```

## Players.refresh

Definition:
```luau
function Players.refresh(player: PlayerInfo): PlayerInfo?
```
Gets the up-to-date version of a player you found earlier. Returns `nil` if they left.

Example:
```luau
local Players = require("../main/entities/players")
local Walker = require("../main/walker")

local other = Players.nearest(assert(Walker.position()))
if other then
	print(Players.refresh(other))
end
```

## Players.model

Definition:
```luau
function Players.model(player: PlayerInfo): NpcModel?
```
The shape of the player as drawn on screen right now.

Example:
```luau
local Players = require("../main/entities/players")
local Walker = require("../main/walker")

local other = Players.nearest(assert(Walker.position()))
local model = other and Players.model(other)
print(model and #model.faces)
```

## Players.clickbox

Definition:
```luau
function Players.clickbox(player: PlayerInfo): Clickbox?
```
The area on screen where a click lands on the player. See [Clickbox](../clickbox.md).

Example:
```luau
local Clickbox = require("../main/clickbox")
local Players = require("../main/entities/players")
local Walker = require("../main/walker")

local other = Players.nearest(assert(Walker.position()))
local box = other and Players.clickbox(other)
if box then
	Clickbox.draw(box)
end
```

## Players.owns

Definition:
```luau
function Players.owns(player: PlayerInfo, entry: MenuEntry): boolean
```
Whether a right-click menu line belongs to this player (its text starts with their name).

Example:
```luau
local Host = require("../host")
local Players = require("../main/entities/players")
local Walker = require("../main/walker")

local other = Players.nearest(assert(Walker.position()))
if other then
	for _, entry in ipairs(Host.menu() or {}) do
		print(entry.option, Players.owns(other, entry))
	end
end
```

## Players.hovered

Definition:
```luau
function Players.hovered(player: PlayerInfo): boolean
```
Whether the game currently has the mouse on this player.

Example:
```luau
local Players = require("../main/entities/players")
local Walker = require("../main/walker")

local other = Players.nearest(assert(Walker.position()))
if other then
	print("mouse is on them:", Players.hovered(other))
end
```

## Players.hover

Definition:
```luau
function Players.hover(player: PlayerInfo): boolean
```
Moves the mouse onto the player, aiming again if they move, until the game confirms the mouse is on them.

Example:
```luau
local Players = require("../main/entities/players")
local Walker = require("../main/walker")

local other = Players.nearest(assert(Walker.position()))
if other then
	print(Players.hover(other))
end
```

## Players.hover_async

Definition:
```luau
function Players.hover_async(player: PlayerInfo): boolean
```
Like `Players.hover`, but queues the move as async input and returns at once, without turning the camera or checking that the game lists it under the mouse. Returns `false` if the player isn't on screen.

Example:
```luau
local Players = require("../main/entities/players")

local found = Players.find()
if found and #found > 0 then
	Players.hover_async(found[1])
end
```

## Players.click

Definition:
```luau
function Players.click(player: PlayerInfo, button: Mouse.Button?): boolean
```
Hovers the player and clicks them (left button by default).

Example:
```luau
local Players = require("../main/entities/players")
local Walker = require("../main/walker")

local other = Players.nearest(assert(Walker.position()))
if other then
	print(Players.click(other))
end
```

## Players.interact

Definition:
```luau
function Players.interact(player: PlayerInfo, option: string, walk_timeout_ms: (number | false)?): boolean
```
Picks an option (such as `"Trade with"` or `"Follow"`) on the player. Retries if the wrong thing got clicked. It doesn't wait for you to stop walking after `"Follow"`, since following never really stops; pass a timeout to change that, or `false` to never wait.

Example:
```luau
local Players = require("../main/entities/players")
local Walker = require("../main/walker")

local other = Players.nearest(assert(Walker.position()))
if other then
	print(Players.interact(other, "Follow"))
end
```
