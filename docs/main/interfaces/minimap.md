# Main.Interfaces.Minimap

The small round map in the corner: finding where a world tile is on it, and changing its zoom.

```luau
local Minimap = require("../main/interfaces/minimap")
```

## Constants

Definition:
```luau
Minimap.ZOOM_MIN = 2
Minimap.ZOOM_MAX = 8
Minimap.COMPONENTS = { [161] = 30, [164] = 30, [548] = 22 }
```
The smallest and largest zoom (pixels per tile), and which interface piece holds the map for each type of game window layout.

## Minimap.state

Definition:
```luau
function Minimap.state(): MinimapState?
```
The minimap's current settings (just its `zoom`).

Example:
```luau
local Minimap = require("../main/interfaces/minimap")

local state = Minimap.state()
print(if state then state.zoom else "unavailable")
```

## Minimap.zoom

Definition:
```luau
function Minimap.zoom(): number?
```
How zoomed in the minimap is, from 2 to 8 (4 by default).

Example:
```luau
local Minimap = require("../main/interfaces/minimap")

print("minimap zoom:", Minimap.zoom())
```

## Minimap.widget

Definition:
```luau
function Minimap.widget(state: ClientState?): Widget?
```
The interface piece the minimap is drawn on, with its position and size.

Example:
```luau
local Minimap = require("../main/interfaces/minimap")

local w = Minimap.widget()
print(w and w.x, w and w.y, w and w.width)
```

## Minimap.fine_to_point

Definition:
```luau
function Minimap.fine_to_point(fine_x: number, fine_y: number): Point?
```
Where a point in the loaded area (128 per tile) shows on the minimap, in screen pixels. Points far from you land outside the minimap.

Example:
```luau
local Host = require("../host")
local Minimap = require("../main/interfaces/minimap")

local me = Host.game_state().position
if me then
	print(Minimap.fine_to_point(me.local_x, me.local_y))
end
```

## Minimap.tile_to_point

Definition:
```luau
function Minimap.tile_to_point(tile: Tile): Point?
```
Where a world tile shows on the minimap, in screen pixels. Useful for clicking the minimap to walk.

Example:
```luau
local Minimap = require("../main/interfaces/minimap")
local Mouse = require("../utils/input/mouse")
local Walker = require("../main/walker")

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
Zooms the minimap in or out with the mouse wheel until it reaches the zoom you asked for (kept between 2 and 8). It fails if scrolling over the minimap changes the main camera zoom instead, which happens when the game's minimap-zoom setting is off.

Example:
```luau
local Minimap = require("../main/interfaces/minimap")

print(Minimap.set_zoom(6))
```

## Minimap.set_zoom_async

Definition:
```luau
function Minimap.set_zoom_async(zoom: number): boolean
```
Like `set_zoom`, but queues the scrolls and returns at once; the next input takes over. It is open loop: single scroll notches, one per level between the current zoom and `zoom` (clamped to 2 to 8), 60 to 140 ms apart, moving over the minimap first if the mouse isn't there. One wheel event changes the zoom by one level whatever its amount, so a single multi-notch scroll doesn't work. Returns false when the minimap can't be read. Checked live: 9 jumps between 2 and 8 all landed exactly.

Example:
```luau
Minimap.set_zoom_async(6)
Mouse.wait()
```
