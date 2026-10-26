# Main.Camera

Reading and changing the camera: which way it faces, how far it tilts and how zoomed in it is.

```luau
local Camera = require("../main/camera")
```

Angles are measured in "units" where a full turn is 16384. Most functions have a `_degrees` twin that uses degrees instead. `yaw` is the left/right direction, `pitch` is how much you look down from above.

Turning is done like a person would: dragging with the middle mouse button (`"mouse"`) or holding the arrow keys (`"keys"`). Functions that turn the camera take an optional `method` to pick one.

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

The size of a full turn, the lowest and highest tilt, the farthest and closest zoom, and about how much one mouse wheel notch zooms.

## Settings

Definition:

```luau
Camera.method = "mouse"
Camera.tolerance = 64
Camera.zoom_tolerance = 12
```

`method` is how the camera is turned unless you say otherwise. `tolerance` and `zoom_tolerance` are how close to the target counts as "there".

Definition:

```luau
Camera.FACE_LIMIT = 70
Camera.FACE_PITCH_SLACK = 200
Camera.FACE_CHANCES = { { 2, 0.1 }, { 12, 0.8 }, { 20, 1 } }
Camera.FACE_TASK_CHANCE = 0.05
Camera.face_task = nil
Camera.face_enabled = true
```

Settings for `Camera.face`:
- `FACE_LIMIT`: how many degrees off the camera's direction a thing can be and still count as in the upper half of the screen (90 would be the middle line).
- `FACE_PITCH_SLACK`: how far below `PITCH_MAX` the pitch can be and still count as the highest.
- `FACE_CHANCES`: how likely it turns at all, by how many tiles away the thing is: `{ tiles, chance }` points in order, with straight lines between them (see `Camera.face_chance`). The default is 10% at 2 tiles or closer, 80% at 12 and always at 20 or more, so close things rarely turn the camera. Chances below 1 are varied per account by the biometrics.
- `FACE_TASK_CHANCE` / `face_task`: the chance (also biometric) to run `face_task` after turning, instead of raising the pitch. Loading the [antiban tasks](antiban/antiban_tasks.md) sets it to `Tasks.adjust_camera`.
- `face_enabled`: set to `false` to never turn the camera this way.

## Camera.state

Definition:

```luau
function Camera.state(): CameraState?
```

Everything about the camera in one table: position, angles, focal point and zoom.

Example:

```luau
local Camera = require("../main/camera")

local cam = Camera.state()
print(if cam then `yaw {cam.yaw}, pitch {cam.pitch}` else "unavailable")
```

## Camera.yaw_to_degrees

Definition:

```luau
function Camera.yaw_to_degrees(yaw: number): number
```

Converts a yaw to a compass bearing in degrees (0 is north, 90 is east).

Example:

```luau
local Camera = require("../main/camera")

print(Camera.yaw_to_degrees(12288)) -- 90
```

## Camera.degrees_to_yaw

Definition:

```luau
function Camera.degrees_to_yaw(degrees: number): number
```

The opposite of `yaw_to_degrees`: a compass bearing to a yaw.

Example:

```luau
local Camera = require("../main/camera")

print(Camera.degrees_to_yaw(90)) -- 12288
```

## Camera.pitch_to_degrees

Definition:

```luau
function Camera.pitch_to_degrees(pitch: number): number
```

Converts a pitch to degrees above the horizon.

Example:

```luau
local Camera = require("../main/camera")

print(Camera.pitch_to_degrees(2048)) -- 45
```

## Camera.degrees_to_pitch

Definition:

```luau
function Camera.degrees_to_pitch(degrees: number): number
```

Converts degrees above the horizon to a pitch.

Example:

```luau
local Camera = require("../main/camera")

print(Camera.degrees_to_pitch(45)) -- 2048
```

## Camera.yaw

Definition:

```luau
function Camera.yaw(): number?
```

Which way the camera faces, in units (0 is north, turning towards the west as it grows).

Example:

```luau
local Camera = require("../main/camera")

print("yaw:", Camera.yaw())
```

## Camera.yaw_degrees

Definition:

```luau
function Camera.yaw_degrees(): number?
```

Which way the camera faces as a compass bearing in degrees.

Example:

```luau
local Camera = require("../main/camera")

print("facing", Camera.yaw_degrees(), "degrees")
```

## Camera.pitch

Definition:

```luau
function Camera.pitch(): number?
```

How far the camera is tilted, in units. Higher looks more from above.

Example:

```luau
local Camera = require("../main/camera")

print("pitch:", Camera.pitch())
```

## Camera.pitch_degrees

Definition:

```luau
function Camera.pitch_degrees(): number?
```

How far the camera is tilted, in degrees.

Example:

```luau
local Camera = require("../main/camera")

print("pitch:", Camera.pitch_degrees(), "degrees")
```

## Camera.zoom

Definition:

```luau
function Camera.zoom(): number?
```

How zoomed in the camera is, from `ZOOM_MIN` (farthest) to `ZOOM_MAX` (closest).

Example:

```luau
local Camera = require("../main/camera")

print("zoom:", Camera.zoom())
```

## Camera.set_yaw

Definition:

```luau
function Camera.set_yaw(yaw: number, method: Method?): boolean
```

Turns the camera to face a direction given in units.

Example:

```luau
local Camera = require("../main/camera")

print(Camera.set_yaw(4096))
```

## Camera.set_yaw_degrees

Definition:

```luau
function Camera.set_yaw_degrees(degrees: number, method: Method?): boolean
```

Turns the camera to face a compass bearing (0 north, 90 east, 180 south, 270 west).

Example:

```luau
local Camera = require("../main/camera")

print(Camera.set_yaw_degrees(0)) -- face north
```

## Camera.set_pitch

Definition:

```luau
function Camera.set_pitch(pitch: number, method: Method?): boolean
```

Tilts the camera to a pitch in units. Values outside the allowed range are limited to it.

Example:

```luau
local Camera = require("../main/camera")

print(Camera.set_pitch(Camera.PITCH_MAX))
```

## Camera.set_pitch_degrees

Definition:

```luau
function Camera.set_pitch_degrees(degrees: number, method: Method?): boolean
```

Tilts the camera to an angle in degrees above the horizon.

Example:

```luau
local Camera = require("../main/camera")

print(Camera.set_pitch_degrees(50))
```

## Camera.set_angles

Definition:

```luau
function Camera.set_angles(yaw: number, pitch: number, method: Method?): boolean
```

Sets the direction and tilt together. With the mouse method this is a single drag.

Example:

```luau
local Camera = require("../main/camera")

print(Camera.set_angles(0, 2048))
```

## Camera.set_zoom

Definition:

```luau
function Camera.set_zoom(zoom: number): boolean
```

Zooms in or out with the mouse wheel until the camera reaches the zoom level you asked for.

Example:

```luau
local Camera = require("../main/camera")

print(Camera.set_zoom(Camera.ZOOM_MAX)) -- as close as possible
```

## Async turning and zooming

`Camera.set_yaw_async`, `Camera.set_yaw_degrees_async`, `Camera.set_pitch_async`, `Camera.set_angles_async` and `Camera.set_zoom_async` queue the input that moves the camera and return at once, so the script keeps going while it moves (see [Mouse](../utils/input/mouse.md) for what stops queued input). They are open loop: from the camera as it is now they work out how far to drag the middle button, or how many wheel notches to scroll, and never check where the camera ends up. It lands close to the target, not exactly, and `Camera.method` is ignored (they always drag). They return `true` when the input was queued, or the camera is already there, and `false` when it couldn't be (the camera isn't readable, or there is no room to drag or scroll). Use the blocking `Camera.set_*` when it has to be exact.

## Camera.set_yaw_async

Definition:
```luau
function Camera.set_yaw_async(yaw: number): boolean
```
Queues a drag that turns the camera towards `yaw`. Open loop, see above.

Example:
```luau
local Camera = require("../main/camera")

Camera.set_yaw_async(0)
```

## Camera.set_yaw_degrees_async

Definition:
```luau
function Camera.set_yaw_degrees_async(degrees: number): boolean
```
Like `Camera.set_yaw_async`, with the angle in degrees.

Example:
```luau
local Camera = require("../main/camera")

Camera.set_yaw_degrees_async((Camera.yaw_degrees() or 0) + 10)
```

## Camera.set_pitch_async

Definition:
```luau
function Camera.set_pitch_async(pitch: number): boolean
```
Queues a drag that tilts the camera towards `pitch`, kept between `Camera.PITCH_MIN` and `Camera.PITCH_MAX`. Open loop.

Example:
```luau
local Camera = require("../main/camera")

Camera.set_pitch_async(Camera.PITCH_MAX)
```

## Camera.set_angles_async

Definition:
```luau
function Camera.set_angles_async(yaw: number, pitch: number): boolean
```
Queues one drag that turns towards both `yaw` and `pitch`. Open loop.

Example:
```luau
local Camera = require("../main/camera")

Camera.set_angles_async(0, 2800)
```

## Camera.set_zoom_async

Definition:
```luau
function Camera.set_zoom_async(zoom: number): boolean
```
Queues the wheel notches (about `Camera.ZOOM_STEP` of zoom each) that take the zoom to `zoom`, kept between `Camera.ZOOM_MIN` and `Camera.ZOOM_MAX`. If the mouse isn't over the game view it moves there first. Open loop.

Example:
```luau
local Camera = require("../main/camera")

Camera.set_zoom_async(Camera.ZOOM_MAX)
```

## Camera.face_chance

Definition:

```luau
function Camera.face_chance(tiles: number): number
```

The chance (0 to 1) that `Camera.face` turns for a thing `tiles` away, read off `FACE_CHANCES`.

Example:

```luau
local Camera = require("../main/camera")

print(Camera.face_chance(2), Camera.face_chance(7), Camera.face_chance(12), Camera.face_chance(25)) -- 0.1 0.45 0.8 1
```

## Camera.face

Definition:

```luau
function Camera.face(tile: Tile): boolean
```

Turns the camera so `tile` shows in the upper half of the game screen. The chatbox and game tabs cover less there, and you can see farther. It turns the short way, just enough that the tile ends up at most `FACE_LIMIT` degrees off the camera's direction, on the side it came from: usually close to that limit, sometimes closer to straight ahead. It doesn't aim the camera straight at the tile. In the same drag it raises the pitch to the highest. Sometimes it runs `face_task` instead (the antiban zoom and pitch task). Nothing happens when the tile is already in the upper half, when the player is standing on it, or when the `face_chance` roll for its distance fails. Returns whether the camera turned.

The entities (through `Clickbox.hover`, `click`, `interact` and `approach`) and the `Walker` tile clicks call it before acting, so scripts don't need to.

Example:

```luau
local Camera = require("../main/camera")
local Walker = require("../main/walker")

print(Camera.face(assert(Walker.relative(0, -5)))) -- the tile 5 south of the player
```
