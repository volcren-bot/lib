# Main.Walker

Walking around: finding where you are, planning a route and clicking tiles on screen.

```luau
local Walker = require("@lib/main/walker")
```

## Walker.position

Definition:
```luau
function Walker.position(): Tile?
```
Your current tile, or `nil` when not logged in.

Example:
```luau
local Walker = require("@lib/main/walker")

local me = Walker.position()
print(if me then `at {me.x}, {me.y}` else "unavailable")
```

## Walker.relative

Definition:
```luau
function Walker.relative(dx: number, dy: number): Tile?
```
The tile `dx` east and `dy` north of you (negative for west and south).

Example:
```luau
local Walker = require("@lib/main/walker")

local target = Walker.relative(0, 5)
print(target and target.x, target and target.y)
```

## Walker.path

Definition:
```luau
function Walker.path(to: Tile, from: Tile?): { Tile }?
```
A walking path from you (or `from`) to `to` (`Host.find_path`), both ends included.

Example:
```luau
local Walker = require("@lib/main/walker")

local goal = assert(Walker.relative(8, 8))
local path = Walker.path(goal)
print(if path then `{#path} steps` else "unavailable")
```

## Walker.route

Definition:
```luau
function Walker.route(to: Tile, from: Tile?): Host.SceneRoute?
```
The route the game walks if you click `to`, from you (or `from`), every tile with you first. It uses the loaded scene, so it works in instances and knows opened doors. `reached` is `false` when `to` can't be reached; the route then ends where the game would stop.

Example:
```luau
local Walker = require("@lib/main/walker")

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
Clicks a tile so you walk there. It turns the camera to show the tile (`Camera.face`) and zooms out in up to two steps if it's still hidden, then tracks a spot inside one of the tile's triangles ([Track](../utils/input/track.md)) and clicks once "Walk here" is offered. A mouse already on the tile stays in its triangle, so a pre-hover is clicked where it is; when something covers that spot, it tries the other triangle before the right-click menu. If the walk's destination (checked for `Walker.CLICK_CHECK_MS`, 700) is another tile because something covers it, it clicks the other triangle, then the minimap. `false` when the tile can't be clicked on screen; `true` once a walk was clicked, even if it still goes elsewhere.

Example:
```luau
local Walker = require("@lib/main/walker")

local ok = Walker.click_tile(assert(Walker.relative(2, 0)))
print(ok)
```

## Walker.hover_tile_async

Definition:
```luau
function Walker.hover_tile_async(tile: Tile, at: Tile?): boolean
```
Starts moving the mouse over a tile and returns at once; no camera turn, no click. Pass `at`, the tile you'll stand on when clicking, to aim where the tile will show then. `false` when the tile is off screen or behind a panel. Any other input stops the move.

Example:
```luau
local Walker = require("@lib/main/walker")

Walker.click_tile(assert(Walker.relative(4, 0)))
local there = assert(Walker.relative(4, 0))
Walker.hover_tile_async(assert(Walker.relative(8, 0)), there)
```

## Walker.wait_arrival

Definition:
```luau
function Walker.wait_arrival(tile: Tile, timeout_ms: number?): boolean
```
Waits until you stand on the tile. `false` after `timeout_ms` (default 10000) or when logged out.

Example:
```luau
local Walker = require("@lib/main/walker")

local goal = assert(Walker.relative(2, 0))
Walker.click_tile(goal)
print("arrived:", Walker.wait_arrival(goal, 8000))
```

## Walker.walk_tile

Definition:
```luau
function Walker.walk_tile(tile: Tile, timeout_ms: number?): boolean
```
`click_tile` then `wait_arrival`.

Example:
```luau
local Walker = require("@lib/main/walker")

local ok = Walker.walk_tile(assert(Walker.relative(3, 0)))
print(if ok then "arrived" else `didn't arrive`)
```

## Walker.distance

Definition:
```luau
function Walker.distance(a: Tile, b: Tile): number
```
Chebyshev distance: the larger of the x and y gaps, which is the number of steps.

Example:
```luau
local Walker = require("@lib/main/walker")

print(Walker.distance({ x = 3200, y = 3200 }, { x = 3203, y = 3210 })) -- 10
```

## Walker.on_minimap

Definition:
```luau
function Walker.on_minimap(tile: Tile): boolean
```
Whether a tile is within `Walker.MINIMAP_REACH` (0.8) of the minimap's radius, clear of the orbs and compass.

Example:
```luau
local Walker = require("@lib/main/walker")

print(Walker.on_minimap(assert(Walker.relative(10, 0))))
```

## Walker.click_minimap

Definition:
```luau
function Walker.click_minimap(tile: Tile): boolean
```
Clicks a tile on the minimap and waits up to 1.2 s for a destination. The server paths, so it works in instances. A minimap zoom below `Walker.MINIMAP_ZOOM_MIN` (4) is first raised to it, or with `MINIMAP_ZOOM_HIGHER_CHANCE` to a random higher level. `false` when the zoom can't be set, the tile isn't on the minimap, or no destination appears.

Example:
```luau
local Walker = require("@lib/main/walker")

local ok = Walker.click_minimap(assert(Walker.relative(0, 12)))
print(ok)
```

## Walker.walk

Definition:
```luau
function Walker.walk(to: Tile, options: WalkOptions?): boolean
```
Walks to a tile on any plane, using transports, doors, ladders, stairs and agility shortcuts. Returns `false` when it times out, is stopped, can't plan, or stops getting closer. `Walker.DEBUG = true` logs each step.

**A goal with no way raises `no way from ... to ...`** (stopping the script unless caught with `pcall`): before moving, it takes usable transports (`Transports.travel`, up to `Walker.TRANSPORT_HOPS`), then asks `Transports.walkable`, and tries `climb_toward` once when the goal is on another plane. With `transports = false` or `straight` it skips all that and returns `false` instead.

How it walks (all tunable via the `Walker.*` constants in the source):
- **Planning.** `Host.nav_plan` over the loaded scene's planes and the cache beyond; replans after a door or climb, a scene load, more than `OFF_PATH` tiles off the plan, and every `REPLAN_MS`.
- **Clicking.** The farthest plan tile on screen (`SCREEN_PADDING` inside the view, within `SCREEN_REACH`, inside the loaded scene by `SCENE_MARGIN`), else the minimap (also at `MINIMAP_CHANCE`). The next click goes in with `CLICK_AHEAD_MIN_MS`..`CLICK_AHEAD_MAX_MS` of walking left, timed from the server tile, aiming where the tile will be when the mouse arrives.
- **Camera.** Turns to show the most of the next `STEER_TILES` plan tiles (`STEER_OFFSETS`, needing `STEER_GAIN` more tiles, random pick within `STEER_SLACK`), before setting off, after clicks and every `STEER_CHECK_MS`; raises a pitch lower than `LOW_PITCH` below max.
- **Fidgets.** While waiting for the flag, random small yaw, pitch, zoom or mouse moves (`FIDGET_*`), with a chance that drops each roll.
- **Doors and climbs.** Clicked once within `ACTION_RANGE` and on screen. A door is done when the plan no longer goes through it; a "seems to be stuck" door (`DOOR_STUCK`) is planned round. A climb is done when the plane changes (a shortcut: near its landing tile). Pauses `CLIMB_PAUSE_MIN_MS`..`CLIMB_PAUSE_MAX_MS` after a plane change, `SHORTCUT_PAUSE_MS` after a same-plane obstacle. One idle for `ACTION_IDLE_MS` is retried `ACTION_ATTEMPTS` times, then avoided.
- **Wrong plane.** If the walk ends off the goal's plane, `climb_toward` and walk again, up to `CLIMB_TRIES`.

`options`:
- `near`: done within this many tiles on `plane` (default 2).
- `timeout_ms`: default `Walker.TIMEOUT_MS` (90000), extended by `WALK_MS_PER_TILE` per planned tile.
- `on_step(tile)`: called about every 50 ms; `false` stops.
- `straight`: click the straight line on your plane and let the server path.
- `randomize`: per-walk noise on tile costs, sometimes clicking short (`SHORTER_CHANCE`, `SHORTER_MAX`) (default true).
- `before_click(target, here)`: `false` stops.
- `accept(entry)`: another menu entry a tile click may take besides "Walk here".
- `plane`: the goal's plane (default yours at the start).
- `doors`, `climbs`, `shortcuts`: allow each (default true). Shortcuts are those your Agility level allows outside the Wilderness that save `Transports.SHORTCUT_MIN_SAVING_TILES`; needed gear in the inventory is equipped and left on.
- `transports`: `false` to walk only, or `{ exclude, min_saving_ticks }` for `Transports.travel`.
- `nav`: extra `Host.NavOptions`.

Example:
```luau
local Walker = require("@lib/main/walker")
local Player = require("@lib/main/player")

local ok = Walker.walk({ x = 3164, y = 3486 }, {
	near = 3,
	plane = 0,
	on_step = function(tile)
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
local Walker = require("@lib/main/walker")

local me = Walker.here()
print(me and `{me.x}, {me.y} on plane {me.plane}`)
```

## Walker.plan

Definition:
```luau
function Walker.plan(to: Tile, plane: number?, options: Host.NavOptions?): NavPlan?
```
`Host.nav_plan` from you to `to` on `plane` (default yours); `nil` and a log line when there is none.

Example:
```luau
local Walker = require("@lib/main/walker")

local plan = Walker.plan({ x = 3208, y = 3220 }, 2)
for _, action in ipairs(plan and plan.actions or {}) do
	print(action.kind, action.loc.option, action.loc.x, action.loc.y)
end
```

## Walker.plain_walk

Definition:
```luau
function Walker.plain_walk(to: Tile, near: number?): boolean
```
Whether `walk`'s plan to within `near` of `to` needs no door, climb or shortcut, so one click on the target walks all the way. False mid-crossing on stepping stones, or when the shortest way uses a shortcut.

Example:
```luau
local Walker = require("@lib/main/walker")

print(Walker.plain_walk({ x = 1621, y = 4016 }, 3))
```

## Walker.last_click

Definition:
```luau
function Walker.last_click(): Tile?
```
Where you are walking: the last tile clicked, or the client's destination when that is more than 2 tiles from it (a walk not started here). `nil` when there's no destination.

Example:
```luau
local Walker = require("@lib/main/walker")

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

function Walker.ahead(ms: number): Host.FinePoint?
```
How far in fine units you'll have moved `ms` from now, along the game's route to the flag (or the server path's end once the flag clears), at run or walk speed. Zero when standing. Pass it to `Projection.shifted` to see where things will be on screen.

Example:
```luau
local Walker = require("@lib/main/walker")

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
Whether the tile is fully inside the game view, `Walker.SCREEN_PADDING` from its edges and clear of interface panels.

Example:
```luau
local Walker = require("@lib/main/walker")

print(Walker.on_screen(assert(Walker.relative(3, 0))))
```

## Walker.climb_toward

Definition:
```luau
Walker.CLIMB_REACH = 10
Walker.CLIMB_TRIES = 2
Walker.CLIMB_TIMEOUT_MS = 6000
function Walker.climb_toward(plane: number): boolean
```
One plane toward `plane` without a plan: uses the nearest object within `CLIMB_REACH` offering `Climb-down` (or `Climb-up`) and waits up to `CLIMB_TIMEOUT_MS` for the plane to change. `false` when already there, no such object, or no change.

Example:
```luau
local Walker = require("@lib/main/walker")

print(Walker.climb_toward(0))
```
