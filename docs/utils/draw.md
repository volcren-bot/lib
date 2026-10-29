# Utils.Draw

Drawing shapes on top of the game. Handy for seeing what a script is looking at or about to click. Drawings stay until you call `Draw.clear`. To redraw everything at once without flicker, wrap the drawing in `Draw.batch`.

```luau
local Draw = require("../utils/draw")
```

Colors are tables with `r`, `g`, `b` (0 to 255) and an optional `a` for transparency. Every drawing function takes an optional color and uses red when you leave it out.

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
Makes a color. `a` is how solid it is (255, the default, is fully solid).

Example:
```luau
local Draw = require("../utils/draw")

local orange = Draw.color(255, 140, 0)
Draw.rect(20, 20, 120, 80, orange)
```

## Draw.rect

Definition:
```luau
function Draw.rect(x1: number, y1: number, x2: number, y2: number, color: Color?)
```
Draws a rectangle from its top-left corner to its bottom-right corner.

Example:
```luau
local Draw = require("../utils/draw")

Draw.rect(50, 50, 200, 120, Draw.GREEN)
```

## Draw.box

Definition:
```luau
function Draw.box(box: Area, color: Color?)
```
Draws a rectangle given as `{ x, y, width, height }`, like the position and size of an interface element.

Example:
```luau
local Draw = require("../utils/draw")
local Host = require("../host")

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
Draws a rectangle given as `{ x1, y1, x2, y2 }`.

Example:
```luau
local Draw = require("../utils/draw")

Draw.button({ x1 = 10, y1 = 10, x2 = 90, y2 = 40 }, Draw.CYAN)
```

## Draw.line

Definition:
```luau
function Draw.line(a: Point, b: Point, color: Color?)
```
Draws a line between two points.

Example:
```luau
local Draw = require("../utils/draw")

Draw.line({ x = 0, y = 0 }, { x = 200, y = 100 }, Draw.MAGENTA)
```

## Draw.lines

Definition:
```luau
function Draw.lines(segments: { { Point } }, color: Color?)
```
Draws many lines in one go. Each segment is a pair of points. This is much faster than calling `Draw.line` in a loop.

Example:
```luau
local Draw = require("../utils/draw")

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
Draws the outline of a shape with any number of corners.

Example:
```luau
local Draw = require("../utils/draw")

Draw.polygon({ { x = 50, y = 50 }, { x = 150, y = 60 }, { x = 100, y = 140 } }, Draw.YELLOW)
```

## Draw.quad

Definition:
```luau
function Draw.quad(quad: Quad, color: Color?)
```
Draws the outline of a four-cornered shape, such as a tile on screen.

Example:
```luau
local Draw = require("../utils/draw")
local Projection = require("../main/projection/projection")
local Walker = require("../main/walker")

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
Draws a 3D box from its bottom and top quads.

Example:
```luau
local Draw = require("../utils/draw")
local Host = require("../host")
local Projection = require("../main/projection/projection")

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
Removes everything drawn so far.

Example:
```luau
local Draw = require("../utils/draw")
local Host = require("../host")

Draw.rect(20, 20, 120, 80)
Host.sleep(2000)
Draw.clear()
```

## Draw.batch

Definition:
```luau
function Draw.batch(paint: () -> ())
```
Runs `paint` and shows everything it draws at once, as one update. Inside it, the drawing functions and `Draw.clear` don't draw straight away; they're saved and sent together when `paint` returns. Use it when you redraw the overlay over and over: without it, every shape is a separate update, so the game can show the overlay empty or half drawn between them. A batch inside a batch joins the outer one, and if `paint` errors nothing is drawn.

Example:
```luau
local Draw = require("../utils/draw")
local Host = require("../host")

for i = 0, 100 do
	Draw.batch(function()
		Draw.clear()
		Draw.rect(20 + i, 20, 120 + i, 80)
		Draw.line({ x = 20 + i, y = 20 }, { x = 120 + i, y = 80 }, Draw.GREEN)
	end)
	Host.sleep(20)
end
```

## Draw.text

Definition:
```luau
function Draw.text(text: string, x: number, y: number, size: number?, color: Color?): number
```
Draws digits, `.`, `-`, `#` and `/` as lines, starting at the top left corner (`x`, `y`). `size` is the height of a digit in pixels (16 by default). There are no letters. Returns the x where the text ends, so you can go on from there.

Example:
```luau
local Draw = require("../utils/draw")

Draw.batch(function()
	Draw.clear()
	Draw.text("#1 0.82", 100, 100, 20, Draw.YELLOW)
end)
```
