# Utils.Math.Random

Random numbers and waits that feel human. Unlike plain `math.random`, many of these favor one end of a range or the middle, the way people's timings naturally cluster.

```luau
local Random = require("../utils/math/random")
```

## Constants

Definition:
```luau
Random.CUTOFF = 5
```
How far into the "tail" of the bell curve the biased functions may reach. Higher means more spread. You rarely need to change it.

## Random.trunc

Definition:
```luau
function Random.trunc(v: number): number
```
Cuts off the decimals of a number, moving towards zero (`2.7` becomes `2`, `-2.7` becomes `-2`).

Example:
```luau
local Random = require("../utils/math/random")

print(Random.trunc(2.7), Random.trunc(-2.7)) -- 2 -2
```

## Random.float

Definition:
```luau
function Random.float(lo: number, hi: number): number
```
A random decimal number between `lo` and `hi`, all values equally likely.

Example:
```luau
local Random = require("../utils/math/random")

print(Random.float(1, 2))
```

## Random.int

Definition:
```luau
function Random.int(lo: number, hi: number): number
```
A random whole number from `lo` up to just under `hi`, all values equally likely.

Example:
```luau
local Random = require("../utils/math/random")

print(Random.int(10, 20))
```

## Random.range

Definition:
```luau
function Random.range(lo: number, hi: number): number
```
Like `int`, but it doesn't matter which of the two numbers is bigger.

Example:
```luau
local Random = require("../utils/math/random")

print(Random.range(20, 10))
```

## Random.left

Definition:
```luau
function Random.left(lo: number, hi: number, cutoff: number?): number
```
A random number between `lo` and `hi` that is most often close to `lo`. Good for reaction times, where fast is common and slow is rare.

Example:
```luau
local Random = require("../utils/math/random")

print(Random.left(100, 500))
```

## Random.right

Definition:
```luau
function Random.right(lo: number, hi: number, cutoff: number?): number
```
The opposite of `left`: most often close to `hi`.

Example:
```luau
local Random = require("../utils/math/random")

print(Random.right(100, 500))
```

## Random.mode

Definition:
```luau
function Random.mode(mode: number, lo: number, hi: number, cutoff: number?): number
```
A random number between `lo` and `hi` that is most often close to `mode`.

Example:
```luau
local Random = require("../utils/math/random")

print(Random.mode(300, 100, 500))
```

## Random.mean

Definition:
```luau
function Random.mean(lo: number, hi: number, cutoff: number?): number
```
A random number between `lo` and `hi` that is most often close to the middle.

Example:
```luau
local Random = require("../utils/math/random")

print(Random.mean(0, 100))
```

## Random.gauss

Definition:
```luau
function Random.gauss(mean: number, dev: number): number
```
A random number around `mean`. About two thirds of results land within `dev` of it. Unlike the others, the result is not limited to a range.

Example:
```luau
local Random = require("../utils/math/random")

print(Random.gauss(100, 10))
```

## Random.chance

Definition:
```luau
function Random.chance(probability: number?): boolean
```
Returns `true` with the given probability (from 0 to 1; 0.5 by default).

Example:
```luau
local Random = require("../utils/math/random")

if Random.chance(0.25) then
	print("one in four")
end
```

## Random.weighted_index

Definition:
```luau
function Random.weighted_index(weights: { number }): number?
```
Picks a position in a list of weights; bigger weights are picked more often, and weights of 0 or less never. Returns `nil` if nothing can be picked.

Example:
```luau
local Random = require("../utils/math/random")

print(Random.weighted_index({ 1, 1, 8 })) -- mostly 3
```

## Random.weighted

Definition:
```luau
function Random.weighted<T>(items: { T }, weight: (T) -> number): T?
```
Picks one item from a list, with each item's chance given by `weight(item)`.

Example:
```luau
local Random = require("../utils/math/random")

local fruit = { { name = "apple", w = 5 }, { name = "pear", w = 1 } }
local pick = Random.weighted(fruit, function(f)
	return f.w
end)
print(pick and pick.name)
```

## Random.nearest_weighted

Definition:
```luau
function Random.nearest_weighted<T>(items: { T }, distance: (T) -> number, falloff: number): T?
```
Picks one item, favoring those with a small `distance(item)`. Every extra `falloff` of distance makes an item about 2.7 times less likely than the closest one.

Example:
```luau
local Random = require("../utils/math/random")

local spots = { 1, 5, 20 }
local pick = Random.nearest_weighted(spots, function(n)
	return math.abs(n - 4)
end, 3)
print(pick)
```

## Random.sleep

Definition:
```luau
function Random.sleep(min: number, max: number, dir: Dir?)
```
Waits a random number of milliseconds between `min` and `max`. `dir` shapes it: `"left"` (default) usually waits near `min`, `"right"` near `max`, and `"mean"` picks evenly.

Example:
```luau
local Random = require("../utils/math/random")

Random.sleep(200, 800)
Random.sleep(200, 800, "mean")
```

## Random.sleep_async

Definition:
```luau
function Random.sleep_async(min: number, max: number, dir: Dir?)
```
Like `Random.sleep`, but queues the wait behind the async input instead of blocking. Later async input waits for it; blocking input cancels it.

Example:
```luau
local Random = require("../utils/math/random")

Mouse.click_async()
Random.sleep_async(200, 800)
Mouse.click_async()
```

## Random.tile_in_box

Definition:
```luau
function Random.tile_in_box(x1: number, y1: number, x2: number, y2: number): Tile
```
A random world tile (`{ x, y }`) in the box from `(x1, y1)` to `(x2, y2)`. Both corners are part of the box, and the corners can be given in either order. Every tile is equally likely. Handy for not always going to the same tile: a spot 2 or 3 tiles east of a ladder is `tile_in_box(ladder.x + 2, ladder.y - 2, ladder.x + 3, ladder.y + 2)`.

Example:
```luau
local Random = require("../utils/math/random")

local spot = Random.tile_in_box(3200, 3100, 3202, 3102)
print(spot.x, spot.y) -- one of the 9 tiles from 3200,3100 to 3202,3102
```
