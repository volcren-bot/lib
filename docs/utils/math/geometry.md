# Utils.Math.Geometry

Screen shapes and natural-looking random points inside them. Results are rounded to whole pixels.

```luau
local Geometry = require("@lib/utils/math/geometry")
local Point, Box, Circle, Quad, Polygon, Triangle =
	Geometry.Point, Geometry.Box, Geometry.Circle, Geometry.Quad, Geometry.Polygon, Geometry.Triangle
```

| Shape | Form |
| --- | --- |
| Point | `{ x, y }` |
| Box | `{ x1, y1, x2, y2 }`, top-left and bottom-right, inclusive |
| Circle | `{ x, y, radius }` |
| Quad | `{ top, right, bottom, left }`, four points, may be tilted (a tile on screen) |
| Polygon | `{ Point }` |
| Triangle | a three-point `Polygon` |

Random point families: `random_point` (uniform), `random_point_center` (near the middle), `random_skewed_point(shape, from, force?)` (towards the side `from` is on, `force` default 0.35), `random_weighted_point(shape, from, weight?, bias?)` (towards `from`; `weight` default 10 is the pull, `bias` default 1 jitters `from` first).

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
local p = Point.new(10, 20)
```

## Point.distance

Definition:
```luau
function Point.distance(a: Point, b: Point): number
```
Euclidean distance.

Example:
```luau
print(Point.distance(Point.new(0, 0), Point.new(3, 4))) -- 5
```

## Point.angle_between

Definition:
```luau
function Point.angle_between(a: Point, b: Point): number
```
Direction from `a` to `b` in degrees `[0, 360)`: 0 is down the screen (+y), 90 left, 180 up, 270 right.

Example:
```luau
print(Point.angle_between(Point.new(0, 0), Point.new(10, 0))) -- 270
```

## Point.rotate

Definition:
```luau
function Point.rotate(p: Point, radians: number, center: Point): Point
```
Rotates `p` around `center` (clockwise on screen for positive angles).

Example:
```luau
local r = Point.rotate(Point.new(10, 0), math.pi / 2, Point.new(0, 0))
print(r.x, r.y) -- 0 10
```

## Point.random

Definition:
```luau
function Point.random(p: Point, range: number): Point
```
Uniform point in the square of half-size `range` around `p`.

Example:
```luau
local q = Point.random(Point.new(100, 100), 5)
```

---

# Polygon

## Polygon.area

Definition:
```luau
function Polygon.area(poly: Polygon): number
```
Area in square pixels.

Example:
```luau
print(Polygon.area({ { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 }, { x = 0, y = 10 } })) -- 100
```

## Polygon.contains

Definition:
```luau
function Polygon.contains(poly: Polygon, p: Point): boolean
```
Whether `p` is inside.

Example:
```luau
print(Polygon.contains(square, { x = 5, y = 5 }))
```

## Polygon.convex_hull

Definition:
```luau
function Polygon.convex_hull(points: { Point }): Polygon
```
Convex hull of the points.

Example:
```luau
print(#Polygon.convex_hull({ { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 5, y = 5 }, { x = 10, y = 10 }, { x = 0, y = 10 } })) -- 4
```

## Polygon.nearest_edge

Definition:
```luau
function Polygon.nearest_edge(poly: Polygon, p: Point): Point
```
Closest point on the outline to `p`.

Example:
```luau
local e = Polygon.nearest_edge(square, { x = 20, y = 5 })
print(e.x, e.y) -- 10 5
```

## Polygon.random_weighted_point

Definition:
```luau
function Polygon.random_weighted_point(poly: Polygon, from: Point, weight: number?, bias: number?): Point
```
Random point inside, pulled towards `from`.

Example:
```luau
local p = Polygon.random_weighted_point(square, { x = 10, y = 10 })
```

---

# Triangle

## Triangle.area

Definition:
```luau
function Triangle.area(tri: Polygon): number
```
Area, rounded up.

Example:
```luau
print(Triangle.area({ { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 0, y = 10 } })) -- 50
```

## Triangle.contains

Definition:
```luau
function Triangle.contains(tri: Polygon, p: Point): boolean
```
Whether `p` is inside.

Example:
```luau
print(Triangle.contains(tri, { x = 2, y = 2 }))
```

## Triangle.centroid

Definition:
```luau
function Triangle.centroid(tri: Polygon): Point
```
Centroid.

Example:
```luau
local c = Triangle.centroid({ { x = 0, y = 0 }, { x = 9, y = 0 }, { x = 0, y = 9 } })
print(c.x, c.y) -- 3 3
```

## Triangle.random_weighted_point

Definition:
```luau
function Triangle.random_weighted_point(tri: Polygon, from: Point, weight: number?, bias: number?): Point
```
Random point inside, pulled towards `from`.

Example:
```luau
local p = Triangle.random_weighted_point(tri, { x = 10, y = 10 })
```

## Triangle.random_point_near_center

Definition:
```luau
function Triangle.random_point_near_center(tri: Polygon, spread: number?): Point
```
Random point near the centroid, clear of the edges; larger `spread` (default `CENTER_SPREAD`) reaches further. Falls back to the centroid after `CENTER_TRIES` misses.

Example:
```luau
local p = Triangle.random_point_near_center(tri)
```

## Triangle settings

Definition:
```luau
Triangle.CENTER_SPREAD = 0.12
Triangle.CENTER_TRIES = 20
```
Default spread and tries of `random_point_near_center`.

---

# Box

## Box.new

Definition:
```luau
function Box.new(x1: number, y1: number, x2: number, y2: number): Box
```
Makes a box.

Example:
```luau
local box = Box.new(10, 10, 110, 60)
```

## Box.from_area

Definition:
```luau
function Box.from_area(a: Area): Box
```
Box from `{ x, y, width, height }` (inclusive, so `x2 = x + width - 1`).

Example:
```luau
print(Box.from_area({ x = 10, y = 10, width = 100, height = 50 }).x2) -- 109
```

## Box.contains

Definition:
```luau
function Box.contains(b: Box, p: Point): boolean
```
Whether `p` is inside (edges included).

Example:
```luau
print(Box.contains(Box.new(0, 0, 10, 10), { x = 5, y = 5 }))
```

## Box.center

Definition:
```luau
function Box.center(b: Box): Point
```
Centre point.

Example:
```luau
local c = Box.center(Box.new(0, 0, 10, 20))
print(c.x, c.y) -- 5 10
```

## Box.corners

Definition:
```luau
function Box.corners(b: Box): Polygon
```
The four corners.

Example:
```luau
print(#Box.corners(Box.new(0, 0, 10, 10))) -- 4
```

## Box.random_point

Definition:
```luau
function Box.random_point(b: Box): Point
```
Uniform point.

Example:
```luau
local p = Box.random_point(Box.new(0, 0, 100, 100))
```

## Box.random_point_center

Definition:
```luau
function Box.random_point_center(b: Box): Point
```
Point biased to the centre.

Example:
```luau
local p = Box.random_point_center(Box.new(0, 0, 100, 100))
```

## Box.random_skewed_point

Definition:
```luau
function Box.random_skewed_point(b: Box, from: Point, force: number?): Point
```
Point skewed towards the side `from` approaches from.

Example:
```luau
local p = Box.random_skewed_point(Box.new(100, 100, 200, 200), { x = 0, y = 0 })
```

## Box.random_weighted_point

Definition:
```luau
function Box.random_weighted_point(b: Box, from: Point, weight: number?, bias: number?): Point
```
Point pulled towards `from`.

Example:
```luau
local p = Box.random_weighted_point(Box.new(100, 100, 200, 200), { x = 0, y = 0 })
```

---

# Circle

## Circle.new

Definition:
```luau
function Circle.new(x: number, y: number, radius: number): Circle
```
Makes a circle.

Example:
```luau
local c = Circle.new(100, 100, 20)
```

## Circle.contains

Definition:
```luau
function Circle.contains(c: Circle, p: Point): boolean
```
Whether `p` is inside.

Example:
```luau
print(Circle.contains(Circle.new(0, 0, 10), { x = 3, y = 4 })) -- true
```

## Circle.point_at_degrees

Definition:
```luau
function Circle.point_at_degrees(c: Circle, degrees: number): Point
```
Point on the edge; 0 is up, 90 right.

Example:
```luau
local p = Circle.point_at_degrees(Circle.new(100, 100, 10), 90)
print(p.x, p.y) -- 110 100
```

## Circle.random_point

Definition:
```luau
function Circle.random_point(c: Circle): Point
```
Uniform point.

Example:
```luau
local p = Circle.random_point(Circle.new(100, 100, 20))
```

## Circle.random_point_center

Definition:
```luau
function Circle.random_point_center(c: Circle): Point
```
Point biased to the centre.

Example:
```luau
local p = Circle.random_point_center(Circle.new(100, 100, 20))
```

## Circle.random_skewed_point

Definition:
```luau
function Circle.random_skewed_point(c: Circle, from: Point, force: number?): Point
```
Point skewed towards the side `from` is on.

Example:
```luau
local p = Circle.random_skewed_point(Circle.new(100, 100, 20), { x = 0, y = 0 })
```

## Circle.random_weighted_point

Definition:
```luau
function Circle.random_weighted_point(c: Circle, from: Point, weight: number?, bias: number?): Point
```
Point pulled towards `from`.

Example:
```luau
local p = Circle.random_weighted_point(Circle.new(100, 100, 20), { x = 0, y = 0 })
```

---

# Quad

## Quad.new

Definition:
```luau
function Quad.new(top: Point, right: Point, bottom: Point, left: Point): Quad
```
Makes a quad.

Example:
```luau
local quad = Quad.new(Point.new(50, 0), Point.new(100, 25), Point.new(50, 50), Point.new(0, 25))
```

## Quad.corners

Definition:
```luau
function Quad.corners(q: Quad): Polygon
```
Corners as `{ top, right, bottom, left }`.

Example:
```luau
print(#Quad.corners(quad)) -- 4
```

## Quad.mean

Definition:
```luau
function Quad.mean(q: Quad): Point
```
Average of the corners.

Example:
```luau
local m = Quad.mean(quad)
print(m.x, m.y) -- 50 25
```

## Quad.contains

Definition:
```luau
function Quad.contains(q: Quad, p: Point): boolean
```
Whether `p` is inside.

Example:
```luau
print(Quad.contains(quad, Point.new(50, 25))) -- true
```

## Quad.nearest_edge

Definition:
```luau
function Quad.nearest_edge(q: Quad, p: Point): Point
```
Closest point on the outline to `p`.

Example:
```luau
local e = Quad.nearest_edge(quad, Point.new(50, 100))
print(e.x, e.y)
```

## Quad.random_point

Definition:
```luau
function Quad.random_point(q: Quad): Point
```
Uniform point.

Example:
```luau
local p = Quad.random_point(quad)
```

## Quad.random_point_center

Definition:
```luau
function Quad.random_point_center(q: Quad): Point
```
Point biased to the centre.

Example:
```luau
local p = Quad.random_point_center(quad)
```

## Quad.random_skewed_point

Definition:
```luau
function Quad.random_skewed_point(q: Quad, from: Point, force: number?): Point
```
Point skewed towards the side `from` is on.

Example:
```luau
local p = Quad.random_skewed_point(quad, Point.new(0, 0))
```

## Quad.random_weighted_point

Definition:
```luau
function Quad.random_weighted_point(q: Quad, from: Point, weight: number?, bias: number?): Point
```
Point pulled towards `from`.

Example:
```luau
local p = Quad.random_weighted_point(quad, Point.new(0, 0))
```
