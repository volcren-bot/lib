# Utils.Draw

Debug shapes on the game overlay. Drawings stay until `Draw.clear`; wrap redraws in `Draw.batch` to avoid flicker.

```luau
local Draw = require("@lib/utils/draw")
```

A `Color` is `{ r, g, b, a? }` (0 to 255). Every color argument defaults to red.

## Colors

Definition:
```luau
Draw.RED, Draw.GREEN, Draw.BLUE, Draw.YELLOW, Draw.CYAN, Draw.MAGENTA, Draw.WHITE, Draw.BLACK
```
Ready-made colors.

## Draw.color

Definition:
```luau
function Draw.color(r: number, g: number, b: number, a: number?): Color
```
Makes a color; `a` defaults to 255 (opaque).

Example:
```luau
local Draw = require("@lib/utils/draw")

local orange = Draw.color(255, 140, 0)
Draw.rect(20, 20, 120, 80, orange)
```

## Draw.rect

Definition:
```luau
function Draw.rect(x1: number, y1: number, x2: number, y2: number, color: Color?)
```
Rectangle from top-left to bottom-right.

Example:
```luau
local Draw = require("@lib/utils/draw")

Draw.rect(50, 50, 200, 120, Draw.GREEN)
```

## Draw.box

Definition:
```luau
function Draw.box(box: Area, color: Color?)
```
Rectangle from `{ x, y, width, height }`, such as a widget's bounds.

Example:
```luau
local Draw = require("@lib/utils/draw")
local Host = require("@lib/host")

local w = Host.widget(149, 0)
if w then
	Draw.box({ x = w.x, y = w.y, width = w.width, height = w.height }, Draw.YELLOW)
end
```

## Draw.button

Definition:
```luau
function Draw.button(button: Corners, color: Color?)
```
Rectangle from `{ x1, y1, x2, y2 }`.

Example:
```luau
local Draw = require("@lib/utils/draw")

Draw.button({ x1 = 10, y1 = 10, x2 = 90, y2 = 40 }, Draw.CYAN)
```

## Draw.line

Definition:
```luau
function Draw.line(a: Point, b: Point, color: Color?)
```
Line between two points.

Example:
```luau
local Draw = require("@lib/utils/draw")

Draw.line({ x = 0, y = 0 }, { x = 200, y = 100 }, Draw.MAGENTA)
```

## Draw.lines

Definition:
```luau
function Draw.lines(segments: { { Point } }, color: Color?)
```
Many point-pair segments in one call; much faster than looping `Draw.line`.

Example:
```luau
local Draw = require("@lib/utils/draw")

Draw.lines({
	{ { x = 0, y = 0 }, { x = 100, y = 0 } },
	{ { x = 100, y = 0 }, { x = 100, y = 100 } },
}, Draw.WHITE)
```

## Draw.polygon

Definition:
```luau
function Draw.polygon(points: { Point }, color: Color?)
```
Closed polygon outline.

Example:
```luau
local Draw = require("@lib/utils/draw")

Draw.polygon({ { x = 50, y = 50 }, { x = 150, y = 60 }, { x = 100, y = 140 } }, Draw.YELLOW)
```

## Draw.quad

Definition:
```luau
function Draw.quad(quad: Quad, color: Color?)
```
Quad outline, such as a projected tile.

Example:
```luau
local Draw = require("@lib/utils/draw")
local Projection = require("@lib/main/projection/projection")
local Walker = require("@lib/main/walker")

local quad = Projection.tile(assert(Walker.position()))
if quad then
	Draw.quad(quad, Draw.GREEN)
end
```

## Draw.cuboid

Definition:
```luau
function Draw.cuboid(cuboid: { bottom: Quad, top: Quad }, color: Color?)
```
3D box outline from its bottom and top quads.

Example:
```luau
local Draw = require("@lib/utils/draw")
local Host = require("@lib/host")
local Projection = require("@lib/main/projection/projection")

local me = (Host.game_state() or {}).position
local cuboid = me and Projection.cuboid(me.local_x, me.local_y)
if cuboid then
	Draw.cuboid(cuboid, Draw.BLUE)
end
```

## Draw.clear

Definition:
```luau
function Draw.clear()
```
Clears the overlay.

Example:
```luau
local Draw = require("@lib/utils/draw")

Draw.clear()
```

## Draw.batch

Definition:
```luau
function Draw.batch(paint: () -> ())
```
Runs `paint`, collecting its drawing calls (including `Draw.clear`) and sending them as one `Host.draw_batch` update, so the overlay is never shown half drawn. Nested batches join the outer one; if `paint` errors nothing is drawn.

Example:
```luau
local Draw = require("@lib/utils/draw")

Draw.batch(function()
	Draw.clear()
	Draw.rect(20, 20, 120, 80)
end)
```

## Draw.text

Definition:
```luau
function Draw.text(text: string, x: number, y: number, size: number?, color: Color?): number
```
Draws digits and `.`, `-`, `#`, `/` (no letters) as lines from top-left (`x`, `y`), `size` px tall (default 16). Returns the end x.

Example:
```luau
local Draw = require("@lib/utils/draw")

Draw.text("#1 0.82", 100, 100, 20, Draw.YELLOW)
```
