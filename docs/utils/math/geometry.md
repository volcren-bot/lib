# Utils.Math.Geometry

Shapes on the screen, and ways to pick natural-looking random points inside them. Everything is built from points (`{ x, y }`).

```luau
local Geometry = require("../utils/math/geometry")
```

The module holds six groups of functions: `Point`, `Box`, `Circle`, `Quad`, `Polygon` and `Triangle`.

| Shape | What it looks like |
| --- | --- |
| Point | `{ x = 10, y = 20 }` |
| Box | `{ x1, y1, x2, y2 }`: top-left and bottom-right corners (straight sides) |
| Circle | `{ x, y, radius }` |
| Quad | `{ top, right, bottom, left }`: four points, can be tilted |
| Polygon | a list of points |
| Triangle | a list of three points |

Many shapes offer the same family of "random point" functions:

- `random_point`: anywhere in the shape, evenly.
- `random_point_center`: more likely near the middle.
- `random_skewed_point(shape, from)`: leans towards the side `from` is on.
- `random_weighted_point(shape, from)`: leans towards `from`.

---

# Point

## Point.new

Definition:
```luau
Point.new: (x: number, y: number) -> Point
```
Makes a point.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local p = Geometry.Point.new(10, 20)
print(p.x, p.y)
```

## Point.distance

Definition:
```luau
function Point.distance(a: Point, b: Point): number
```
The straight-line distance between two points.

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Point = Geometry.Point

print(Point.distance(Point.new(0, 0), Point.new(3, 4))) -- 5
```

## Point.angle_between

Definition:
```luau
function Point.angle_between(a: Point, b: Point): number
```
The direction from `a` to `b` in degrees, from 0 to 360, where 0 means straight up on the screen.

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Point = Geometry.Point

print(Point.angle_between(Point.new(0, 0), Point.new(10, 0))) -- 0 is up, so this is 90
```

## Point.rotate

Definition:
```luau
function Point.rotate(p: Point, radians: number, center: Point): Point
```
Turns a point around a center by an angle in radians.

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Point = Geometry.Point

local turned = Point.rotate(Point.new(10, 0), math.pi / 2, Point.new(0, 0))
print(turned.x, turned.y) -- 0 10
```

## Point.random

Definition:
```luau
function Point.random(p: Point, range: number): Point
```
A random point within `range` pixels of a point, in a square around it.

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Point = Geometry.Point

local p = Point.random(Point.new(100, 100), 5)
print(p.x, p.y)
```

---

# Polygon

## Polygon.area

Definition:
```luau
function Polygon.area(poly: Polygon): number
```
The size of the area a polygon covers, in square pixels.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local square = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 }, { x = 0, y = 10 } }
print(Geometry.Polygon.area(square)) -- 100
```

## Polygon.contains

Definition:
```luau
function Polygon.contains(poly: Polygon, p: Point): boolean
```
Whether a point is inside a polygon.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local square = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 }, { x = 0, y = 10 } }
print(Geometry.Polygon.contains(square, { x = 5, y = 5 })) -- true
print(Geometry.Polygon.contains(square, { x = 50, y = 5 })) -- false
```

## Polygon.convex_hull

Definition:
```luau
function Polygon.convex_hull(points: { Point }): Polygon
```
The outline that wraps around a cloud of points, like a rubber band stretched around them.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local outline = Geometry.Polygon.convex_hull({
	{ x = 0, y = 0 }, { x = 10, y = 0 }, { x = 5, y = 5 }, { x = 10, y = 10 }, { x = 0, y = 10 },
})
print(#outline) -- 4: the middle point is inside
```

## Polygon.nearest_edge

Definition:
```luau
function Polygon.nearest_edge(poly: Polygon, p: Point): Point
```
The point on the polygon's outline that is closest to `p`.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local square = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 }, { x = 0, y = 10 } }
local edge = Geometry.Polygon.nearest_edge(square, { x = 20, y = 5 })
print(edge.x, edge.y) -- 10 5
```

## Polygon.random_weighted_point

Definition:
```luau
function Polygon.random_weighted_point(poly: Polygon, from: Point, weight: number?, bias: number?): Point
```
A random point inside the polygon that leans towards `from`. `weight` (default 10) is how strong the pull is, `bias` (default 1) how much `from` is randomly shifted first.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local square = { { x = 0, y = 0 }, { x = 100, y = 0 }, { x = 100, y = 100 }, { x = 0, y = 100 } }
local p = Geometry.Polygon.random_weighted_point(square, { x = 10, y = 10 })
print(p.x, p.y)
```

---

# Triangle

A triangle is a list of three points.

## Triangle.area

Definition:
```luau
function Triangle.area(tri: Polygon): number
```
The size of a triangle, rounded up to a whole number of pixels.

Example:
```luau
local Geometry = require("../utils/math/geometry")

print(Geometry.Triangle.area({ { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 0, y = 10 } })) -- 50
```

## Triangle.contains

Definition:
```luau
function Triangle.contains(tri: Polygon, p: Point): boolean
```
Whether a point is inside the triangle.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local tri = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 0, y = 10 } }
print(Geometry.Triangle.contains(tri, { x = 2, y = 2 })) -- true
```

## Triangle.centroid

Definition:
```luau
function Triangle.centroid(tri: Polygon): Point
```
The middle of the triangle.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local c = Geometry.Triangle.centroid({ { x = 0, y = 0 }, { x = 9, y = 0 }, { x = 0, y = 9 } })
print(c.x, c.y) -- 3 3
```

## Triangle.random_weighted_point

Definition:
```luau
function Triangle.random_weighted_point(tri: Polygon, from: Point, weight: number?, bias: number?): Point
```
A random point inside the triangle that leans towards `from`.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local tri = { { x = 0, y = 0 }, { x = 100, y = 0 }, { x = 0, y = 100 } }
local p = Geometry.Triangle.random_weighted_point(tri, { x = 10, y = 10 })
print(p.x, p.y)
```

## Triangle.random_point_near_center

Definition:
```luau
function Triangle.random_point_near_center(tri: Polygon, spread: number?): Point
```
A random point close to the triangle's middle, staying clear of its edges. A larger `spread` (default 0.12) allows points farther from the middle.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local tri = { { x = 0, y = 0 }, { x = 100, y = 0 }, { x = 0, y = 100 } }
local p = Geometry.Triangle.random_point_near_center(tri)
print(p.x, p.y)
```

## Triangle settings

Definition:
```luau
Triangle.CENTER_SPREAD = 0.12
Triangle.CENTER_TRIES = 20
```
The default spread of `random_point_near_center`, and how many times it tries before giving up and returning the exact middle.

---

# Box

## Box.new

Definition:
```luau
function Box.new(x1: number, y1: number, x2: number, y2: number): Box
```
Makes a box from its top-left and bottom-right corners.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local box = Geometry.Box.new(10, 10, 110, 60)
print(box.x2 - box.x1)
```

## Box.from_area

Definition:
```luau
function Box.from_area(a: Area): Box
```
Makes a box from a position and size (`{ x, y, width, height }`).

Example:
```luau
local Geometry = require("../utils/math/geometry")

local box = Geometry.Box.from_area({ x = 10, y = 10, width = 100, height = 50 })
print(box.x2, box.y2) -- 109 59
```

## Box.contains

Definition:
```luau
function Box.contains(b: Box, p: Point): boolean
```
Whether a point is inside the box.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local box = Geometry.Box.new(0, 0, 10, 10)
print(Geometry.Box.contains(box, { x = 5, y = 5 })) -- true
```

## Box.center

Definition:
```luau
function Box.center(b: Box): Point
```
The middle of the box.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local c = Geometry.Box.center(Geometry.Box.new(0, 0, 10, 20))
print(c.x, c.y) -- 5 10
```

## Box.corners

Definition:
```luau
function Box.corners(b: Box): Polygon
```
The four corners of the box as a list of points.

Example:
```luau
local Geometry = require("../utils/math/geometry")

print(#Geometry.Box.corners(Geometry.Box.new(0, 0, 10, 10))) -- 4
```

## Box.random_point

Definition:
```luau
function Box.random_point(b: Box): Point
```
A random point in the box, evenly spread.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local p = Geometry.Box.random_point(Geometry.Box.new(0, 0, 100, 100))
print(p.x, p.y)
```

## Box.random_point_center

Definition:
```luau
function Box.random_point_center(b: Box): Point
```
A random point in the box, most likely near the middle.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local p = Geometry.Box.random_point_center(Geometry.Box.new(0, 0, 100, 100))
print(p.x, p.y)
```

## Box.random_skewed_point

Definition:
```luau
function Box.random_skewed_point(b: Box, from: Point, force: number?): Point
```
A random point in the box, leaning towards the side `from` is on, as if reaching the box from there. `force` (default 0.35) is how strong the lean is.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local p = Geometry.Box.random_skewed_point(Geometry.Box.new(100, 100, 200, 200), { x = 0, y = 0 })
print(p.x, p.y)
```

## Box.random_weighted_point

Definition:
```luau
function Box.random_weighted_point(b: Box, from: Point, weight: number?, bias: number?): Point
```
A random point in the box, leaning towards `from`.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local p = Geometry.Box.random_weighted_point(Geometry.Box.new(100, 100, 200, 200), { x = 0, y = 0 })
print(p.x, p.y)
```

---

# Circle

## Circle.new

Definition:
```luau
function Circle.new(x: number, y: number, radius: number): Circle
```
Makes a circle from its center and radius.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local circle = Geometry.Circle.new(100, 100, 20)
print(circle.radius)
```

## Circle.contains

Definition:
```luau
function Circle.contains(c: Circle, p: Point): boolean
```
Whether a point is inside the circle.

Example:
```luau
local Geometry = require("../utils/math/geometry")

print(Geometry.Circle.contains(Geometry.Circle.new(0, 0, 10), { x = 3, y = 4 })) -- true
```

## Circle.point_at_degrees

Definition:
```luau
function Circle.point_at_degrees(c: Circle, degrees: number): Point
```
The point on the edge of the circle in a direction, where 0 is straight up and 90 is to the right.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local p = Geometry.Circle.point_at_degrees(Geometry.Circle.new(100, 100, 10), 90)
print(p.x, p.y) -- 110 100
```

## Circle.random_point

Definition:
```luau
function Circle.random_point(c: Circle): Point
```
A random point in the circle, evenly spread.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local p = Geometry.Circle.random_point(Geometry.Circle.new(100, 100, 20))
print(p.x, p.y)
```

## Circle.random_point_center

Definition:
```luau
function Circle.random_point_center(c: Circle): Point
```
A random point in the circle, most likely near the middle.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local p = Geometry.Circle.random_point_center(Geometry.Circle.new(100, 100, 20))
print(p.x, p.y)
```

## Circle.random_skewed_point

Definition:
```luau
function Circle.random_skewed_point(c: Circle, from: Point, force: number?): Point
```
A random point in the circle, leaning towards the side `from` is on.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local p = Geometry.Circle.random_skewed_point(Geometry.Circle.new(100, 100, 20), { x = 0, y = 0 })
print(p.x, p.y)
```

## Circle.random_weighted_point

Definition:
```luau
function Circle.random_weighted_point(c: Circle, from: Point, weight: number?, bias: number?): Point
```
A random point in the circle, leaning towards `from`.

Example:
```luau
local Geometry = require("../utils/math/geometry")

local p = Geometry.Circle.random_weighted_point(Geometry.Circle.new(100, 100, 20), { x = 0, y = 0 })
print(p.x, p.y)
```

---

# Quad

A quad is four corner points named `top`, `right`, `bottom` and `left`. Unlike a box it can be tilted, which is what a tile looks like on screen.

## Quad.new

Definition:
```luau
function Quad.new(top: Point, right: Point, bottom: Point, left: Point): Quad
```
Makes a quad from its four corners.

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Point = Geometry.Point

local quad = Geometry.Quad.new(Point.new(50, 0), Point.new(100, 25), Point.new(50, 50), Point.new(0, 25))
print(quad.top.x, quad.top.y)
```

## Quad.corners

Definition:
```luau
function Quad.corners(q: Quad): Polygon
```
The four corners as a list (top, right, bottom, left).

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Point = Geometry.Point

local quad = Geometry.Quad.new(Point.new(50, 0), Point.new(100, 25), Point.new(50, 50), Point.new(0, 25))
print(#Geometry.Quad.corners(quad)) -- 4
```

## Quad.mean

Definition:
```luau
function Quad.mean(q: Quad): Point
```
The middle of the quad (the average of its corners).

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Point = Geometry.Point

local quad = Geometry.Quad.new(Point.new(50, 0), Point.new(100, 25), Point.new(50, 50), Point.new(0, 25))
local c = Geometry.Quad.mean(quad)
print(c.x, c.y) -- 50 25
```

## Quad.contains

Definition:
```luau
function Quad.contains(q: Quad, p: Point): boolean
```
Whether a point is inside the quad.

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Point = Geometry.Point

local quad = Geometry.Quad.new(Point.new(50, 0), Point.new(100, 25), Point.new(50, 50), Point.new(0, 25))
print(Geometry.Quad.contains(quad, Point.new(50, 25))) -- true
```

## Quad.nearest_edge

Definition:
```luau
function Quad.nearest_edge(q: Quad, p: Point): Point
```
The point on the quad's outline that is closest to `p`.

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Point = Geometry.Point

local quad = Geometry.Quad.new(Point.new(50, 0), Point.new(100, 25), Point.new(50, 50), Point.new(0, 25))
local edge = Geometry.Quad.nearest_edge(quad, Point.new(50, 100))
print(edge.x, edge.y)
```

## Quad.random_point

Definition:
```luau
function Quad.random_point(q: Quad): Point
```
A random point in the quad, evenly spread.

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Point = Geometry.Point

local quad = Geometry.Quad.new(Point.new(50, 0), Point.new(100, 25), Point.new(50, 50), Point.new(0, 25))
local p = Geometry.Quad.random_point(quad)
print(p.x, p.y)
```

## Quad.random_point_center

Definition:
```luau
function Quad.random_point_center(q: Quad): Point
```
A random point in the quad, most likely near the middle.

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Point = Geometry.Point

local quad = Geometry.Quad.new(Point.new(50, 0), Point.new(100, 25), Point.new(50, 50), Point.new(0, 25))
local p = Geometry.Quad.random_point_center(quad)
print(p.x, p.y)
```

## Quad.random_skewed_point

Definition:
```luau
function Quad.random_skewed_point(q: Quad, from: Point, force: number?): Point
```
A random point in the quad, leaning towards the side `from` is on.

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Point = Geometry.Point

local quad = Geometry.Quad.new(Point.new(50, 0), Point.new(100, 25), Point.new(50, 50), Point.new(0, 25))
local p = Geometry.Quad.random_skewed_point(quad, Point.new(0, 0))
print(p.x, p.y)
```

## Quad.random_weighted_point

Definition:
```luau
function Quad.random_weighted_point(q: Quad, from: Point, weight: number?, bias: number?): Point
```
A random point in the quad, leaning towards `from`.

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Point = Geometry.Point

local quad = Geometry.Quad.new(Point.new(50, 0), Point.new(100, 25), Point.new(50, 50), Point.new(0, 25))
local p = Geometry.Quad.random_weighted_point(quad, Point.new(0, 0))
print(p.x, p.y)
```
