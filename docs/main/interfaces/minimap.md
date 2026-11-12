# Main.Interfaces.Minimap

The round minimap: projecting tiles onto it, its zoom and the run orb.

```luau
local Minimap = require("@lib/main/interfaces/minimap")
```

## Constants

Definition:
```luau
Minimap.ZOOM_MIN = 2
Minimap.ZOOM_MAX = 8
Minimap.RUN_GROUP = 160
Minimap.RUN_CHILD = 28
Minimap.RUN_OPTION = "Toggle Run"
Minimap.RUN_TIMEOUT_MS = 1500
Minimap.COMPONENTS = { [161] = 30, [164] = 30, [548] = 22 }
```
- `ZOOM_MIN`/`ZOOM_MAX`: zoom range in pixels per tile.
- `RUN_*`: the run orb widget, its option and how long `set_run` waits.
- `COMPONENTS`: minimap child per top-level layout group.

## Minimap.state

Definition:
```luau
function Minimap.state(): MinimapState?
```
The minimap state (`zoom`); nil when not logged in.

Example:
```luau
local state = Minimap.state()
print(state and state.zoom)
```

## Minimap.zoom

Definition:
```luau
function Minimap.zoom(): number?
```
Current zoom, 2 to 8 (game default 4).

Example:
```luau
print(Minimap.zoom())
```

## Minimap.widget

Definition:
```luau
function Minimap.widget(state: ClientState?): Widget?
```
The widget the minimap is drawn on for the current layout.

Example:
```luau
local w = Minimap.widget()
print(w and w.x, w and w.y, w and w.width)
```

## Minimap.fine_to_point

Definition:
```luau
function Minimap.fine_to_point(fine_x: number, fine_y: number): Point?
```
Screen point of a local fine coordinate (128 per tile) on the minimap. Far points land outside the map.

Example:
```luau
local Host = require("@lib/host")

local me = Host.game_state().position
print(me and Minimap.fine_to_point(me.local_x, me.local_y))
```

## Minimap.tile_to_point

Definition:
```luau
function Minimap.tile_to_point(tile: Tile): Point?
```
Screen point of a world tile on the minimap, for minimap walking.

Example:
```luau
local Mouse = require("@lib/utils/input/mouse")
local Walker = require("@lib/main/walker")

local point = Minimap.tile_to_point(assert(Walker.relative(5, 5)))
if point then
	Mouse.click(point)
end
```

## Minimap.set_zoom

Definition:
```luau
function Minimap.set_zoom(zoom: number): boolean
```
Scrolls over the minimap until it reaches `zoom` (rounded, clamped to 2..8). Fails when the scroll zooms the camera instead (the game's minimap-zoom setting is off).

Example:
```luau
print(Minimap.set_zoom(6))
```

## Minimap.set_zoom_async

Definition:
```luau
function Minimap.set_zoom_async(zoom: number): boolean
```
Open-loop `set_zoom`: queues one wheel notch per level (each event moves one level regardless of amount), 60 to 140 ms apart, moving onto the minimap first if needed, and returns at once. `false` when the minimap can't be read.

Example:
```luau
local Mouse = require("@lib/utils/input/mouse")

Minimap.set_zoom_async(6)
Mouse.wait()
```

## Minimap.set_run

Definition:
```luau
function Minimap.set_run(enabled: boolean): boolean
```
Toggles run with the orb and waits up to `RUN_TIMEOUT_MS` for `Player.is_running()` to match. `true` when already as asked or it changed.

Example:
```luau
Minimap.set_run(false)
```
