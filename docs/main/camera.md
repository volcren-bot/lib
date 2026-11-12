# Main.Camera

Reads and turns the camera: yaw, pitch and zoom. Turning is human-like: a middle-mouse drag (`"mouse"`) or held arrow keys (`"keys"`), picked by the optional `method`. A drag or zoom starts where the mouse already is if that spot is over an uncovered game view with room for the drag; otherwise the mouse moves into the game view first.

```luau
local Camera = require("@lib/main/camera")
```

Angles are in units, 16384 per full turn; `_degrees` variants use degrees. Yaw is the compass direction, pitch how far it looks down from above.

## Constants

Definition:
```luau
Camera.TURN = 16384
Camera.PITCH_MIN = 1024
Camera.PITCH_MAX = 3064
Camera.ZOOM_MIN = 128
Camera.ZOOM_MAX = 896
Camera.ZOOM_STEP = 24
```
Full turn, pitch range, zoom range (farthest to closest) and the approximate zoom per wheel notch.

## Settings

Definition:
```luau
Camera.method = "mouse"
Camera.tolerance = 64
Camera.zoom_tolerance = 12
```
Default turning method, and how close an angle or zoom must be to count as reached.

Definition:
```luau
Camera.FACE_LIMIT = 70
Camera.LOOK_SPREAD = 12
Camera.FACE_PITCH_SLACK = 200
Camera.FACE_CHANCES = { { 2, 0.1 }, { 12, 0.8 }, { 20, 1 } }
Camera.FACE_TASK_CHANCE = 0.05
Camera.face_task = nil
Camera.face_enabled = true
```
Settings for `face` and `look_at`:
- `FACE_LIMIT`: degrees off the camera direction that still count as the upper half of the screen.
- `LOOK_SPREAD`: degrees of random spread either side in `look_at`.
- `FACE_PITCH_SLACK`: how far below `PITCH_MAX` still counts as the highest pitch.
- `FACE_CHANCES`: `{ tiles, chance }` points, linearly interpolated (`face_chance`); chances below 1 are varied per account by the biometrics.
- `FACE_TASK_CHANCE` / `face_task`: biometric chance to run `face_task` after turning instead of raising the pitch. Loading the [antiban tasks](antiban/antiban_tasks.md) sets it to `Tasks.adjust_camera`.
- `face_enabled`: `false` disables `face`.

## Camera.state

Definition:
```luau
function Camera.state(): CameraState?
```
The whole camera: position, angles, focal point and zoom; `nil` when unreadable.

Example:
```luau
local Camera = require("@lib/main/camera")

local cam = Camera.state()
print(if cam then cam.yaw else "unavailable")
```

## Camera.yaw_to_degrees

Definition:
```luau
function Camera.yaw_to_degrees(yaw: number): number
```
Yaw to compass bearing (0 north, 90 east).

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.yaw_to_degrees(12288)) -- 90
```

## Camera.degrees_to_yaw

Definition:
```luau
function Camera.degrees_to_yaw(degrees: number): number
```
Compass bearing to yaw.

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.degrees_to_yaw(90)) -- 12288
```

## Camera.pitch_to_degrees

Definition:
```luau
function Camera.pitch_to_degrees(pitch: number): number
```
Pitch to degrees above the horizon.

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.pitch_to_degrees(2048)) -- 45
```

## Camera.degrees_to_pitch

Definition:
```luau
function Camera.degrees_to_pitch(degrees: number): number
```
Degrees above the horizon to pitch.

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.degrees_to_pitch(45)) -- 2048
```

## Camera.yaw

Definition:
```luau
function Camera.yaw(): number?
```
Current yaw in units; 0 is north and it grows turning west.

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.yaw())
```

## Camera.yaw_degrees

Definition:
```luau
function Camera.yaw_degrees(): number?
```
Current yaw as a compass bearing.

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.yaw_degrees())
```

## Camera.pitch

Definition:
```luau
function Camera.pitch(): number?
```
Current pitch in units; higher looks more from above.

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.pitch())
```

## Camera.pitch_degrees

Definition:
```luau
function Camera.pitch_degrees(): number?
```
Current pitch in degrees.

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.pitch_degrees())
```

## Camera.zoom

Definition:
```luau
function Camera.zoom(): number?
```
Current zoom, `ZOOM_MIN` (farthest) to `ZOOM_MAX` (closest).

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.zoom())
```

## Camera.set_yaw

Definition:
```luau
function Camera.set_yaw(yaw: number, method: Method?): boolean
```
Turns to `yaw` (units) and blocks until within `tolerance`.

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.set_yaw(4096))
```

## Camera.set_yaw_degrees

Definition:
```luau
function Camera.set_yaw_degrees(degrees: number, method: Method?): boolean
```
Turns to a compass bearing.

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.set_yaw_degrees(0))
```

## Camera.set_pitch

Definition:
```luau
function Camera.set_pitch(pitch: number, method: Method?): boolean
```
Tilts to `pitch` (units), clamped to `PITCH_MIN`..`PITCH_MAX`.

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.set_pitch(Camera.PITCH_MAX))
```

## Camera.set_pitch_degrees

Definition:
```luau
function Camera.set_pitch_degrees(degrees: number, method: Method?): boolean
```
Tilts to degrees above the horizon.

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.set_pitch_degrees(50))
```

## Camera.set_angles

Definition:
```luau
function Camera.set_angles(yaw: number, pitch: number, method: Method?): boolean
```
Sets yaw and pitch together; one drag with the mouse method.

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.set_angles(0, 2048))
```

## Camera.set_zoom

Definition:
```luau
function Camera.set_zoom(zoom: number): boolean
```
Scrolls the wheel until the zoom is within `zoom_tolerance` of `zoom` (clamped to the zoom range). `false` when unreadable, out of room, or the zoom stops changing.

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.set_zoom(Camera.ZOOM_MAX))
```

## Async turning and zooming

The `_async` setters queue the drag or wheel notches and return at once (see [Mouse](../utils/input/mouse.md) for what stops queued input). They are open loop: computed from the current camera, never checked, so they land near the target. They always drag, ignoring `Camera.method`. They return `true` when queued or already there, `false` when the camera is unreadable or there is no room. Use the blocking setters when it must be exact.

## Camera.set_yaw_async

Definition:
```luau
function Camera.set_yaw_async(yaw: number): boolean
```
Queues a drag towards `yaw`.

Example:
```luau
local Camera = require("@lib/main/camera")

Camera.set_yaw_async(0)
```

## Camera.set_yaw_degrees_async

Definition:
```luau
function Camera.set_yaw_degrees_async(degrees: number): boolean
```
`set_yaw_async` in degrees.

Example:
```luau
local Camera = require("@lib/main/camera")

Camera.set_yaw_degrees_async((Camera.yaw_degrees() or 0) + 10)
```

## Camera.set_pitch_async

Definition:
```luau
function Camera.set_pitch_async(pitch: number): boolean
```
Queues a drag towards `pitch`, clamped to the pitch range.

Example:
```luau
local Camera = require("@lib/main/camera")

Camera.set_pitch_async(Camera.PITCH_MAX)
```

## Camera.set_angles_async

Definition:
```luau
function Camera.set_angles_async(yaw: number, pitch: number): boolean
```
Queues one drag towards both `yaw` and `pitch`.

Example:
```luau
local Camera = require("@lib/main/camera")

Camera.set_angles_async(0, 2800)
```

## Camera.set_zoom_async

Definition:
```luau
function Camera.set_zoom_async(zoom: number): boolean
```
Queues the wheel notches (`ZOOM_STEP` each) towards `zoom`, clamped to the zoom range, moving the mouse into the game view first if needed.

Example:
```luau
local Camera = require("@lib/main/camera")

Camera.set_zoom_async(Camera.ZOOM_MAX)
```

## Camera.face_chance

Definition:
```luau
function Camera.face_chance(tiles: number): number
```
The chance (0 to 1) that `face` turns for a tile `tiles` away, from `FACE_CHANCES`.

Example:
```luau
local Camera = require("@lib/main/camera")

print(Camera.face_chance(2), Camera.face_chance(7), Camera.face_chance(25)) -- 0.1 0.45 1
```

## Camera.look_at

Definition:
```luau
function Camera.look_at(tile: Tile, from: Tile?): boolean
```
Always turns so `tile` is straight ahead from `from` (default: your tile), within a random `LOOK_SPREAD`, keeping the pitch. Returns the `set_yaw` result; `false` when `from` is the tile or unreadable. `Clickbox.reveal` uses it when `face` and zooming out didn't help.

Example:
```luau
local Camera = require("@lib/main/camera")
local Walker = require("@lib/main/walker")

print(Camera.look_at(assert(Walker.relative(4, 6))))
```

## Camera.face

Definition:
```luau
function Camera.face(tile: Tile, force: boolean?, from: Tile?): boolean
```
Turns the short way just enough that `tile` sits in the upper half of the screen (a random amount inside `FACE_LIMIT`, not aimed straight at it), raising the pitch to `PITCH_MAX` in the same drag. With `FACE_TASK_CHANCE` it instead turns the yaw only and then runs `face_task`. Does nothing when disabled, the tile is already in the upper half, you stand on it, or the `face_chance` roll fails (`force` skips the roll). `from` measures from another tile, such as an obstacle's landing. Returns whether it turned. Entity `hover`/`click`/`interact`/`approach` and `Walker` tile clicks call it already.

Example:
```luau
local Camera = require("@lib/main/camera")
local Walker = require("@lib/main/walker")

print(Camera.face(assert(Walker.relative(0, -5))))
```
