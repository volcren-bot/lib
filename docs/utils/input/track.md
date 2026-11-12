# Utils.Input.Track

Hovers a moving on-screen target (a swaying NPC, a scene sliding while you walk). Used by [Clickbox.hover](../../main/clickbox.md) and [Walker.click_tile](../../main/walker.md).

```luau
local Track = require("@lib/utils/input/track")
```

Like a person, it makes one async mouse move led by the target's screen velocity, then a few small corrections. It re-reads the target while moving and cancels and re-aims only on a large jump (a dive, a walk starting). The menu is never read mid-move, since that would cancel the move.

## Settings

Definition:
```luau
Track.TIMEOUT_MS = 2500
Track.MOVES = 5
Track.JUMP_PX = 60
Track.JUMP_SHARE = 0.5
Track.STILL_PX_S = 40
Track.NEAR_PX = 20
Track.POLL_MS = 15
Track.MIN_AREA = 4
Track.SETTLE_MS = 60
Track.CONFIRM_MS = 80
Track.SPEED_WINDOW_MS = 120
Track.MAX_LEAD_PX = 60
Track.HEAT_CELL = 6
Track.HEAT_CAP = 60
Track.WARM = 8
Track.CENTER_SPREAD = 0.45
Track.MOUSE_PULL = 2
Track.debug = false
```
- `TIMEOUT_MS`, `MOVES`: max time and max moves (first plus corrections) per hover.
- `JUMP_PX`, `JUMP_SHARE`: re-aim when the target drifts at least `JUMP_PX` and `JUMP_SHARE` of the remaining distance from the move's end.
- `STILL_PX_S`, `NEAR_PX`: with `anywhere`, any triangle counts while the spot moves at most `STILL_PX_S` px/s, otherwise only within `NEAR_PX` of the spot.
- `POLL_MS`: read interval while moving.
- `MIN_AREA`: triangles smaller than this (px²) count as gone.
- `SETTLE_MS`: wait for the client to report the mouse after a move.
- `CONFIRM_MS`: how long to wait for `confirm` once a move ends on target.
- `SPEED_WINDOW_MS`, `MAX_LEAD_PX`: velocity window and lead cap.
- `HEAT_CELL`, `HEAT_CAP`, `WARM`: `hover_heat` cell size (px), reads to full heat, reads to count as warm.
- `CENTER_SPREAD`, `MOUSE_PULL`: `hover_heat` pull of the target cell towards the heat's centre and towards the mouse.
- `debug`: log every move and jump.

## Types

Definition:
```luau
export type Spot = { u: number, v: number }
export type Shape = { triangles: { Polygon }, anchor: Point? }
```
`Spot` is barycentric weights (third is `1 - u - v`), so it stays the same part of a moving triangle. `Shape` is what `hover_heat` reads; the heat map is kept relative to `anchor` (screen-fixed without one).

## Track.spot

Definition:
```luau
function Track.spot(): Spot
```
A random spot near a triangle's centre.

Example:
```luau
local spot = Track.spot()
```

## Track.point

Definition:
```luau
function Track.point(tri: Polygon, spot: Spot): Point
```
Screen point of `spot` in `tri`.

Example:
```luau
print(Track.point(tri, Track.spot()))
```

## Track.inside

Definition:
```luau
function Track.inside(tri: Polygon, spot: Point, mouse: Point): boolean
```
Whether `mouse` is inside `tri` or within a pixel of `spot` (covers rounding on small triangles).

Example:
```luau
print(Track.inside(tri, Track.point(tri, spot), mouse))
```

## Track.on_any

Definition:
```luau
function Track.on_any(list: { Polygon }, mouse: Point): boolean
```
Whether `mouse` is inside any triangle.

Example:
```luau
print(Track.on_any(triangles, mouse))
```

## Track.hover

Definition:
```luau
function Track.hover(
	triangles: () -> { Polygon }?,
	index: number,
	visible: ((Point) -> boolean)?,
	anywhere: boolean?,
	confirm: (() -> boolean)?,
	spot: Spot?
): (boolean, string?)
```
Moves onto triangle `index` of `triangles()` (stable order, nil when unreadable); does not click. `visible` rejects covered spots. `anywhere` accepts any triangle after at least one move (see `STILL_PX_S`). `confirm` (e.g. the game reporting the hovered thing) is checked mid-move while on the target and for `CONFIRM_MS` after; if it disagrees, corrections aim at the spot itself and `anywhere` stops counting. Returns true, or false with `"changed"` (triangle count changed, e.g. NPC changed form), `"gone"` (unreadable, below `MIN_AREA` or not visible), `"unconfirmed"` (on the spot but `confirm` disagrees), `"missed"` (`MOVES` used) or `"timeout"`.

Example:
```luau
local Npcs = require("@lib/main/entities/npcs")

local npc = assert(Npcs.find("Banker"))[1]
print(Track.hover(function()
	local box = Npcs.clickbox(npc)
	return box and box.triangles
end, 1, nil, true))
```

## Track.hover_heat

Definition:
```luau
function Track.hover_heat(
	read: () -> Shape?,
	visible: ((Point) -> boolean)?,
	confirm: (() -> boolean)?
): (boolean, string?)
```
Moves onto a model by heat instead of one face. Each read marks `HEAT_CELL` cells (relative to the anchor) whose centre a triangle covers and `visible` allows; heat is consecutive covered reads, so cells an animation keeps uncovering stay cold. The target cell is picked weighted by squared heat, towards the centre and the mouse, and re-picked when uncovered. With `confirm`, it is checked on any warm cell, mid-move too; without it, success is being within a cell of the target. Returns true, or false with `"gone"`, `"unconfirmed"`, `"missed"` or `"timeout"`.

Example:
```luau
local Npcs = require("@lib/main/entities/npcs")

local npc = assert(Npcs.find("Banker"))[1]
print(Track.hover_heat(function()
	local box = Npcs.clickbox(npc)
	return if box and box.triangles then { triangles = box.triangles } else nil
end, nil, function()
	return Npcs.hovered(npc)
end))
```
