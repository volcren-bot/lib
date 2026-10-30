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
Walks to a tile, on any plane, through doors and up and down ladders and staircases. It plans with `Host.nav_plan` (every plane of the loaded scene at once, the game cache's collision beyond it) and plans again when it needs to: after a door opens or a climb, when the scene loads another area, when the player is more than `Walker.OFF_PATH` tiles off the plan, and every `Walker.REPLAN_MS` anyway (doors other players open and close).

- **Walking.** It clicks the farthest plan tile the screen shows (within `Walker.SCREEN_REACH`, 30; the game sets no destination for a click about 35 tiles away), or the minimap when the screen shows none (and now and then, `Walker.MINIMAP_CHANCE`). Only tiles of the scene the game has loaded count, `Walker.SCENE_MARGIN` clear of its edge (`Walker.SCENE_TILES` across): a tile past it shows on screen all the same, but a click on it walks nowhere. The next click goes in while the player still has `Walker.CLICK_AHEAD_MIN_MS` to `Walker.CLICK_AHEAD_MAX_MS` of walking left to the last one, timed from the tile the server has the player on (ahead of where it is drawn, and where the game takes the flag away), so it doesn't stop between clicks. While walking it aims where the tile will be once the mouse gets there (the camera follows the player), and it doesn't click tiles within `Walker.SETTLE_TILES` of a moving player. A tile something stands on (a door, a ladder) gives way to the tiles before it; only the last one tried uses "Walk here" from the menu. It plans from the server's tile too.
- **Camera.** The walk turns the camera to show as much of the way ahead as it can, so each click goes far: it projects the next `Walker.STEER_TILES` plan tiles as the camera would show them turned to each of `Walker.STEER_OFFSETS` (degrees off the bearing of their mean), from where the next click will go in, and turns to one that shows at least `Walker.STEER_GAIN` tiles more of the way than now (a random one of those within `Walker.STEER_SLACK` of the most, preferring one whose neighbours do as well). It looks before setting off, after each click, and every `Walker.STEER_CHECK_MS` while running to the flag (queued then, so a turn never holds up a click); a camera more than `Walker.LOW_PITCH` below `Camera.PITCH_MAX` is raised as it turns.
- **Tiny moves.** With `Walker.FIDGET_CHANCE` a wait for the flag has one tiny move, `Walker.FIDGET_DELAY_MIN_MS` to `Walker.FIDGET_DELAY_MAX_MS` after the click and only with `Walker.FIDGET_MIN_LEFT_MS` left before the next one: a small yaw turn or mouse move (the antiban's tiny tasks), a pitch within `Walker.FIDGET_PITCH` of `Camera.PITCH_MAX`, or a zoom within `Walker.FIDGET_ZOOM_NOTCHES` scroll notches of the zoom it found (kept from walk to walk, so the moves don't add up). They are queued, and the camera check above turns back to the way if one turned too far from it.
- **Doors and climbs.** The plan's next door or ladder is clicked as soon as it is within `Walker.ACTION_RANGE` and on screen (the game walks the rest), or once the walk gets next to it. A door is done when the plan no longer goes through it or the other half of it (a double door or a gate: the locs side by side along its wall), checked every `Walker.DOOR_CHECK_MS`, and the server isn't moving the player without a walk of theirs: a toll gate walks you through and shuts behind you. A door that just opened isn't clicked again for `Walker.DOOR_REOPEN_MS`, while a gate shows shut before it walks you through. When the chatbox says a door clicked "seems to be stuck" (`Walker.DOOR_STUCK`: doors opened and closed too often), the walk plans round it at once. A climb is done when the plane changes. After a plane change the camera is let settle and the walk pauses a random `Walker.CLIMB_PAUSE_MIN_MS` to `Walker.CLIMB_PAUSE_MAX_MS` (0 to 1.5 ticks) before its next click; the planning happens inside that pause. One that does nothing for `Walker.ACTION_IDLE_MS` (a locked door) is tried `Walker.ACTION_ATTEMPTS` times, then planned around.

`options`:
- `near`: done once the player is at most this many tiles away, on `plane` (default 2).
- `timeout_ms`: gives up after this long (default `Walker.TIMEOUT_MS`, 90000, or more for a long plan: `Walker.WALK_MS_PER_TILE` for every tile planned).
- `on_step`: called about every 50 ms with the player's tile; returning `false` stops the walk.
- `straight`: walk the straight line on your plane, without planning, letting the server find the way.
- `randomize`: take a different way each walk (default true): the plan's tile costs get noise from a seed picked per walk, so planning again keeps the same way. Sometimes (`Walker.SHORTER_CHANCE`, up to `Walker.SHORTER_MAX` tiles) it also clicks short of the farthest tile it could.
- `before_click`: called with the tile (or door or ladder) about to be clicked and your tile; returning `false` stops the walk.
- `accept`: a menu entry besides "Walk here" that may sit on a tile, which a click may take.
- `plane`: the plane `to` is on (default yours).
- `doors`: open the closed doors on the way (default true); `false` walks round them.
- `climbs`: use ladders and staircases (default true); `false` stays on your plane.
- `nav`: more for `Host.nav_plan`: `door_options`, `climb_options`, `avoid`, `door_cost`, `climb_cost`.

`Walker.DEBUG = true` logs what the walk does and how long each step takes. Returns `false` when it times out, is stopped, can't plan, or the player stops getting closer (the target can't be reached).

Example:
```luau
local Walker = require("../main/walker")
local Player = require("../main/player")

local ok = Walker.walk({ x = 3164, y = 3486 }, {
	near = 3,
	plane = 0,
	on_step = function(tile)
		-- stop walking when we get low on hitpoints
		return (Player.hitpoints() or 99) > 10
	end,
})
print(ok)
```

## Walker.here

Definition:
```luau
function Walker.here(): NavTile?
```
Your tile with its plane.

Example:
```luau
local Walker = require("../main/walker")

local me = Walker.here()
print(me and `{me.x}, {me.y} on plane {me.plane}`)
```

## Walker.plan

Definition:
```luau
function Walker.plan(to: Tile, plane: number?, options: Host.NavOptions?): NavPlan?
```
The plan `Walker.walk` starts from: `Host.nav_plan` from you to `to` on `plane` (yours by default).

Example:
```luau
local Walker = require("../main/walker")

local plan = Walker.plan({ x = 3208, y = 3220 }, 2)
for _, action in ipairs(plan and plan.actions or {}) do
	print(action.kind, action.loc.option, action.loc.x, action.loc.y)
end
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
