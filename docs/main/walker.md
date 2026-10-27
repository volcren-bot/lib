# Main.Walker

Walking around: finding where you are, planning a route and clicking tiles on screen.

```luau
local Walker = require("../main/walker")
```

## Walker.position

Definition:
```luau
function Walker.position(): Tile?
```
Your current tile. Returns `nil` and a message when you are not logged in.

Example:
```luau
local Walker = require("../main/walker")

local me = Walker.position()
print(if me then `at {me.x}, {me.y}` else "unavailable")
```

## Walker.relative

Definition:
```luau
function Walker.relative(dx: number, dy: number): Tile?
```
The tile that is `dx` tiles east and `dy` tiles north of you (use negative numbers for west and south).

Example:
```luau
local Walker = require("../main/walker")

local target = Walker.relative(0, 5)
print(target and target.x, target and target.y)
```

## Walker.path

Definition:
```luau
function Walker.path(to: Tile, from: Tile?): { Tile }?
```
Plans a walking route to a tile, starting from you (or from `from`). Both ends are included in the list.

Example:
```luau
local Walker = require("../main/walker")

local goal = assert(Walker.relative(8, 8))
local path = Walker.path(goal)
print(if path then `{#path} steps` else "unavailable")
```

## Walker.route

Definition:
```luau
function Walker.route(to: Tile, from: Tile?): Host.SceneRoute?
```
The way the game will walk if you click `to`, starting from you (or from `from`): every tile, you first. It uses the area the game client has loaded around you, so it works in minigames and other instances, and knows about opened doors. `reached` is `false` when `to` can't be reached; the route then ends at the tile the game walks you to instead. Handy to check what lies on the way before clicking.

Example:
```luau
local Walker = require("../main/walker")

local goal = assert(Walker.relative(6, -3))
local route = Walker.route(goal)
if route then
	print(`{#route.tiles - 1} steps`, if route.reached then "" else "(ends short of it)")
else
	print("no route")
end
```

## Walker.click_tile

Definition:
```luau
function Walker.click_tile(tile: Tile): boolean
```
Clicks a tile on the screen so your character walks there. It first turns the camera so the tile shows in the upper half of the screen (`Camera.face`). Returns `false` with a message if the tile can't be seen (off screen or behind a panel).

Example:
```luau
local Walker = require("../main/walker")

local ok = Walker.click_tile(assert(Walker.relative(2, 0)))
print(ok)
```

## Walker.wait_arrival

Definition:
```luau
function Walker.wait_arrival(tile: Tile, timeout_ms: number?): boolean
```
Waits until you are standing on the tile. Gives up after `timeout_ms` (default 10000) and returns `false`.

Example:
```luau
local Walker = require("../main/walker")

local goal = assert(Walker.relative(2, 0))
Walker.click_tile(goal)
print("arrived:", Walker.wait_arrival(goal, 8000))
```

## Walker.walk_tile

Definition:
```luau
function Walker.walk_tile(tile: Tile, timeout_ms: number?): boolean
```
Clicks a tile and waits until you get there. A shortcut for `click_tile` followed by `wait_arrival`.

Example:
```luau
local Walker = require("../main/walker")

local ok = Walker.walk_tile(assert(Walker.relative(3, 0)))
print(if ok then "arrived" else `didn't arrive`)
```

## Walker.distance

Definition:
```luau
function Walker.distance(a: Tile, b: Tile): number
```
Tiles between two tiles: the larger of the x and y distances, which is how many steps walking takes.

Example:
```luau
local Walker = require("../main/walker")

print(Walker.distance({ x = 3200, y = 3200 }, { x = 3203, y = 3210 })) -- 10
```

## Walker.on_minimap

Definition:
```luau
function Walker.on_minimap(tile: Tile): boolean
```
Whether a tile can be clicked on the minimap: it's within `Walker.MINIMAP_REACH` (0.8) of the minimap's radius from its centre, away from the orbs and the compass on the edge.

Example:
```luau
local Walker = require("../main/walker")

print(Walker.on_minimap(assert(Walker.relative(10, 0))))
```

## Walker.click_minimap

Definition:
```luau
function Walker.click_minimap(tile: Tile): boolean
```
Clicks a tile on the minimap and waits (up to 1.2 s) for the client to set a destination. The server finds the way to the tile, so this works where `find_path` can't, inside instances included. Before clicking, a minimap zoom below `Walker.MINIMAP_ZOOM_MIN` (4) is raised to it, or with `MINIMAP_ZOOM_HIGHER_CHANCE` to a random higher level; a zoom at or above it is left alone. Fails when the tile isn't on the minimap at that zoom (see `on_minimap`) or the zoom can't be set.

Example:
```luau
local Walker = require("../main/walker")

local ok = Walker.click_minimap(assert(Walker.relative(0, 12)))
print(ok)
```

## Walker.walk

Definition:
```luau
function Walker.walk(to: Tile, options: WalkOptions?): boolean
```
Walks to a tile of any distance with minimap clicks. It plans the way the game itself walks when the tile is nearby (`Walker.route`, which also works in instances), otherwise a path with `find_path` (or a straight line when there's none, or when `options.straight` is set), and clicks the farthest path tile the screen or the minimap shows, again each time the player gets within a few tiles of the last click. When the server's own route leaves the plan behind, it plans again from where the player is. A target outside the loaded scene is routed over the game cache's collision (see `Host.scene_route`), and a walk plans again each time the game loads another scene (it does when you get within about 16 tiles of an edge), so it takes the live collision once it has it. Targets too far or too winding for one route are walked in stops along the world path (`Walker.ROUTE_REACH` tiles ahead). Clicks on the game screen are limited to tiles within `Walker.SCREEN_REACH` of the player: the game sets no destination for a click about 35 tiles away. Before each click it turns the camera so the tile it is about to click shows in the upper half of the screen (`Camera.face`), and picks the tile again if the camera turned.

`options`:
- `near`: done once the player is at most this many tiles away (default 2).
- `timeout_ms`: gives up after this long (default 60000).
- `on_step`: called every 100 ms with the player's tile; returning `false` stops the walk (it then returns `false, "stopped"`). Use it to react to things while walking.
- `straight`: walk in a straight line, letting the server find the way.
- `randomize`: plan a different route each walk (default true, never for `straight`): `Host.scene_route` with a seed picked per walk, so planning again keeps the same route. Sometimes (`Walker.SHORTER_CHANCE`, up to `Walker.SHORTER_MAX` tiles) it also clicks short of the farthest tile it could.
- `before_click`: called with the tile about to be clicked and your tile before each minimap click; returning `false` stops the walk (it then returns `false, "stopped"`). Use it with `Walker.route` to look at the way ahead, for example for something to avoid.
- `plane`: the plane `to` is on. When it isn't the one the player is on, the walk goes through the ladders and staircases added to `Transports` (see `PlaneWalker.walk`); the other options apply to each walk on a plane.
- `doors`: when no way is found before the first step (to the tile or to any around it within `near`), or the walk finds the way blocked later, plan it again through the doors of the map (default true). The planner takes every door closed; the walk reads the real one once it is there, opens it if it is closed and goes through (`PlaneWalker.cross`). Pass `false` to leave doors to the caller.

Returns `false` with a reason when it times out, can't click the way on the minimap, or the player stops getting closer (the target can't be reached, for example a tile in the water).

Example:
```luau
local Walker = require("../main/walker")
local Player = require("../main/player")

local ok = Walker.walk({ x = 3164, y = 3486 }, {
	near = 3,
	on_step = function(tile)
		-- stop walking when we get low on hitpoints
		return (Player.hitpoints() or 99) > 10
	end,
})
print(ok)
```

## Walker.last_click

Definition:
```luau
function Walker.last_click(): Tile?
```
The tile the player is walking to, while they are: the last tile we clicked to walk to, which is where the walk ends. The client's destination takes over when that's somewhere else (a walk we didn't start, like a click on an NPC). Nil once they've arrived.

Example:
```luau
local Walker = require("../main/walker")

local target = Walker.last_click()
if target then
	print("walking to", target.x, target.y)
end
```

## Walker.ahead

Definition:
```luau
Walker.WALK_MS_PER_TILE = 600
Walker.RUN_MS_PER_TILE = 300

function Walker.ahead(ms: number): FinePoint?
```
How far (fine units, x and y) the player will have moved `ms` from now: it follows the game's route (`Walker.route`) from where the player is drawn to the client's destination flag, at running or walking speed. Zero when the player has no destination. The camera follows the player, so `Projection.shifted` with this offset shows where things will be on screen by then.

Example:
```luau
local Walker = require("../main/walker")

local shift = Walker.ahead(400)
if shift then
	print(`in 400 ms the player is {shift.x}, {shift.y} fine units from here`)
end
```

## Walker.on_screen

Definition:
```luau
function Walker.on_screen(tile: Tile): boolean
```
TODO...

Example:
```luau

```
