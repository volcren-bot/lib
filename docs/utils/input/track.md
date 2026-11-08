# Utils.Input.Track

Moving the mouse onto something that moves on screen: a swaying NPC, or anything while the scene slides because you walk. One triangle of the thing is followed the whole way.

```luau
local Track = require("@lib/utils/input/track")
```

You normally get this through [Clickbox.hover](../../main/clickbox.md) and [Walker.click_tile](../../main/walker.md). People don't steer the cursor continuously either: they make one movement and then a few small corrections. `Track.hover` does the same. It aims at a spot of one triangle, a spot that stays the same part of the triangle while it moves. It sends one normal mouse move, led by how fast that spot moves on screen. While the mouse goes it keeps reading the triangle, and it cancels and aims again only when the spot jumps far from where the move is going (a dive, a walk starting). When a move ends it checks whether the mouse is on the target and otherwise sends a short correction. The async mouse (`Mouse.move_async`) is used as it is; a new move doesn't replace a running one, so a jump is a `Mouse.cancel` and a new move. Nothing reads the menu while the mouse moves, since a menu read stops an async move; `confirm` is asked only once a move has ended.

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
Track.debug = false
```
- `TIMEOUT_MS` / `MOVES`: how long a hover may take and how many moves it makes at most (the first one and the corrections).
- `JUMP_PX` / `JUMP_SHARE`: how far the spot may get from where the move is going before the move is cancelled and aimed again: at least `JUMP_PX` pixels and `JUMP_SHARE` of the distance the mouse still has to go, since a far move's aim drifts and its end corrects it (cancelling on small drifts restarts the move again and again, and a move starts slowly).
- `STILL_PX_S` / `NEAR_PX`: with `anywhere`, the mouse counts anywhere on the target while the spot moves at most `STILL_PX_S` pixels a second, and on a faster one only within `NEAR_PX` of the spot: near an edge of a moving target the mouse is off it by the time the click goes in, and a small triangle moving fast can't be landed on exactly.
- `POLL_MS`: how often the triangle is read while the mouse moves.
- `MIN_AREA`: a triangle smaller than this (pixels) counts as gone.
- `SETTLE_MS`: how long a finished move gets for the client to report the mouse where it went.
- `CONFIRM_MS`: with `confirm`, how long the mouse stays put waiting for it once a move ends on the target.
- `SPEED_WINDOW_MS` / `MAX_LEAD_PX`: the spot's speed is measured over the reads of this window (frames come about every 20 ms, so close reads are noisy), and the lead it gives a move is capped at this many pixels.
- `debug`: logs every move (the spot, its speed, where the move goes, where the mouse was) and every jump.

## Types

Definition:
```luau
export type Spot = { u: number, v: number }
```
Where in a triangle the mouse goes, as barycentric weights (the third is `1 - u - v`), so it is the same part of the triangle in every frame.

## Track.spot

Definition:
```luau
function Track.spot(): Spot
```
A random spot near a triangle's centre (the spread of `Triangle.random_point_near_center`).

## Track.point

Definition:
```luau
function Track.point(tri: Polygon, spot: Spot): Point
```
The screen point of the spot in the triangle as it is drawn now.

## Track.inside

Definition:
```luau
function Track.inside(tri: Polygon, spot: Point, mouse: Point): boolean
```
Whether the mouse is on the triangle: inside it, or within a pixel of the spot (rounding can put the spot of a small triangle just outside it).

## Track.on_any

Definition:
```luau
function Track.on_any(list: { Polygon }, mouse: Point): boolean
```
Whether the mouse is inside any of the triangles.

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
Moves the mouse onto triangle `index` of what `triangles` reads. `triangles` gives the target's triangles on screen now, in the same order every time (a model's faces are), or nil when they can't be read. `visible` can turn down a spot, for one covered by the interface. With `anywhere`, the mouse also counts as there once it is on any of the triangles after at least one move, while the spot is about still (`STILL_PX_S`) or within `NEAR_PX` of it; where it happened to be before moving doesn't count. With `confirm` (the game showing the thing under the mouse, a menu read), it is asked while the mouse stays put once a move ends on the target, for up to `CONFIRM_MS`; when it doesn't agree, the corrections go on to the spot itself and `anywhere` no longer counts, and when the mouse is on the spot itself and the game still doesn't agree, the triangle is given up (`"unconfirmed"`: a face the game doesn't pick, such as a hidden one). Returns true once it is there (and confirmed), or false with why: `"changed"` when the number of triangles changed since the first read (the thing was given another model, as an NPC changing form does, so the index is another face now); `"gone"` when the triangle can't be read, is smaller than `MIN_AREA` or isn't visible; `"unconfirmed"` when `confirm` doesn't agree with the mouse on the spot; `"missed"` after `MOVES` moves; `"timeout"` after `TIMEOUT_MS`. It doesn't click.

Example:
```luau
local Npcs = require("@lib/main/entities/npcs")
local Track = require("@lib/utils/input/track")

local npc = assert(Npcs.find("Banker"))[1]
local function faces()
	local box = Npcs.clickbox(npc)
	return box and box.triangles
end
print(Track.hover(faces, 1, nil, true))
```
