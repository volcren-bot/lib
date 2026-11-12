# Utils.Math.Random

Random numbers and waits with human-like skew: the biased functions use a half-normal truncated at `CUTOFF` deviations, clustering towards one end, a mode or the middle.

```luau
local Random = require("@lib/utils/math/random")
```

## Constants

Definition:
```luau
Random.CUTOFF = 5
```
Default truncation, in deviations, for `left`, `right`, `mode` and `mean`; higher spreads less towards the far end.

## Random.trunc

Definition:
```luau
function Random.trunc(v: number): number
```
Rounds towards zero.

Example:
```luau
print(Random.trunc(2.7), Random.trunc(-2.7)) -- 2 -2
```

## Random.float

Definition:
```luau
function Random.float(lo: number, hi: number): number
```
Uniform in `[lo, hi)`.

Example:
```luau
print(Random.float(1, 2))
```

## Random.int

Definition:
```luau
function Random.int(lo: number, hi: number): number
```
Uniform integer in `[lo, hi)` (truncated `float`).

Example:
```luau
print(Random.int(10, 20))
```

## Random.range

Definition:
```luau
function Random.range(lo: number, hi: number): number
```
Uniform integer from the smaller bound up to just under the larger; bounds in either order.

Example:
```luau
print(Random.range(20, 10))
```

## Random.left

Definition:
```luau
function Random.left(lo: number, hi: number, cutoff: number?): number
```
In `[lo, hi)`, most often near `lo` (reaction times).

Example:
```luau
print(Random.left(100, 500))
```

## Random.right

Definition:
```luau
function Random.right(lo: number, hi: number, cutoff: number?): number
```
In `(lo, hi]`, most often near `hi`.

Example:
```luau
print(Random.right(100, 500))
```

## Random.mode

Definition:
```luau
function Random.mode(mode: number, lo: number, hi: number, cutoff: number?): number
```
In `[lo, hi]`, most often near `mode`.

Example:
```luau
print(Random.mode(300, 100, 500))
```

## Random.mean

Definition:
```luau
function Random.mean(lo: number, hi: number, cutoff: number?): number
```
`mode` at the midpoint.

Example:
```luau
print(Random.mean(0, 100))
```

## Random.gauss

Definition:
```luau
function Random.gauss(mean: number, dev: number): number
```
Unbounded normal sample.

Example:
```luau
print(Random.gauss(100, 10))
```

## Random.chance

Definition:
```luau
function Random.chance(probability: number?): boolean
```
True with `probability` (default 0.5).

Example:
```luau
print(Random.chance(0.25))
```

## Random.weighted_index

Definition:
```luau
function Random.weighted_index(weights: { number }): number?
```
Index picked proportionally to weight; weights ≤ 0 are never picked. Nil when none is positive.

Example:
```luau
print(Random.weighted_index({ 1, 1, 8 })) -- mostly 3
```

## Random.weighted

Definition:
```luau
function Random.weighted<T>(items: { T }, weight: (T) -> number): T?
```
Item picked proportionally to `weight(item)`.

Example:
```luau
local pick = Random.weighted({ { w = 5 }, { w = 1 } }, function(f)
	return f.w
end)
```

## Random.nearest_weighted

Definition:
```luau
function Random.nearest_weighted<T>(items: { T }, distance: (T) -> number, falloff: number): T?
```
Item picked with weight `exp(-(d - closest) / falloff)`: each `falloff` of extra distance is e times less likely.

Example:
```luau
print(Random.nearest_weighted({ 1, 5, 20 }, function(n)
	return math.abs(n - 4)
end, 3))
```

## Random.sleep

Definition:
```luau
function Random.sleep(min: number, max: number, dir: Dir?)
```
Sleeps a random ms in the range: `"left"` (default) near `min`, `"right"` near `max`, `"mean"` uniform.

Example:
```luau
Random.sleep(200, 800)
```

## Random.sleep_async

Definition:
```luau
function Random.sleep_async(min: number, max: number, dir: Dir?)
```
Queues the same wait on the async input queue; blocking input cancels it.

Example:
```luau
local Mouse = require("@lib/utils/input/mouse")

Mouse.click_async()
Random.sleep_async(200, 800)
Mouse.click_async()
```

## Random.tile_in_box

Definition:
```luau
function Random.tile_in_box(x1: number, y1: number, x2: number, y2: number): Tile
```
Uniform tile in the box, both corners included, corners in either order.

Example:
```luau
local spot = Random.tile_in_box(3200, 3100, 3202, 3102)
```
