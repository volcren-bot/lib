# DebugDraw

Debug drawing that shows only while Script debugging is on in a client's development page in the loader (`Host.script_debugging`). Callers register named layers; every change repaints all layers in one batch, so the lib's drawings (such as `Walker.show_route`) and a script's own stay on screen together. Layers project tiles when painted, so re-setting a layer each step keeps it on the moving camera. Painting clears the whole overlay first, so don't mix it with a script's own `Draw` calls.

## DebugDraw.on

Definition:
```luau
function DebugDraw.on(): boolean
```
Whether Script debugging is on now.

Example:
```luau
local DebugDraw = require("@lib/main/debug_draw")

print(DebugDraw.on())
```

## DebugDraw.set

Definition:
```luau
function DebugDraw.set(name: string, paint: (() -> ())?, layer: Draw.Layer?)
```
Adds or replaces the layer `name` (drawn in the order layers were first added) and repaints; `nil` removes it. `paint` runs inside a `Draw.batch` with `layer` (default `"world"`), so it calls `Draw` functions directly: world drawings hide under game interfaces; pass `"ui"` for a layer that marks interfaces. With debugging off nothing is drawn, and what was shown is cleared.

Example:
```luau
local DebugDraw = require("@lib/main/debug_draw")
local Draw = require("@lib/utils/draw")

DebugDraw.set("target", function()
	Draw.rect(100, 100, 140, 140, Draw.GREEN)
end)
DebugDraw.set("target", nil)
```

## DebugDraw.render

Definition:
```luau
function DebugDraw.render()
```
Repaints every layer, for example after the camera moved; clears the overlay when debugging is off or no layer is left.

Example:
```luau
local DebugDraw = require("@lib/main/debug_draw")

DebugDraw.render()
```

## DebugDraw.outline

Definition:
```luau
function DebugDraw.outline(tiles: { Tile }, color: Draw.Color, width: number?)
```
Outlines the border of an area of tiles: only the edges between a tile in `tiles` and one outside it, `width` pixels thick. Use it inside a layer's `paint`.

Example:
```luau
local DebugDraw = require("@lib/main/debug_draw")
local Draw = require("@lib/utils/draw")

DebugDraw.set("danger", function()
	DebugDraw.outline({ { x = 3200, y = 3200 }, { x = 3201, y = 3200 } }, Draw.RED, 3)
end)
```
