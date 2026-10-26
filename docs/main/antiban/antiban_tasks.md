# Main.Antiban.AntibanTasks

## Tasks.small_random_mouse

Definition:
```luau
function Tasks.small_random_mouse()
```
Moves the mouse a short way (50 to 350 px) in a random direction. It starts the move with `Mouse.move_async` and returns at once, so the script keeps running while the mouse moves. The next input the script sends, or a minimenu read, takes over from it, leaving the mouse where it had got to.

Example:
```luau
local Tasks = require("../main/antiban/antiban_tasks")

Tasks.small_random_mouse()
```

## Tasks.large_random_mouse

Definition:
```luau
function Tasks.large_random_mouse()
```
TODO...

Example:
```luau

```

## Tasks.random_right_click

Definition:
```luau
function Tasks.random_right_click()
```
TODO...

Example:
```luau

```

## Tasks.tiny_camera_rotation

Definition:
```luau
function Tasks.tiny_camera_rotation()
```
Rotates the camera 5 to 20 degrees, left or right. It queues the drag with `Camera.set_yaw_degrees_async` and returns at once, so the camera moves while the script carries on, and ends up close to the angle rather than exactly on it. The next input the script sends takes over.

Example:
```luau

```

## Tasks.tiny_zoom_change

Definition:
```luau
function Tasks.tiny_zoom_change()
```
Scrolls the zoom 1 or 2 notches in or out, staying inside the `set_zoom_range` (the other way if the change would leave it). It works out the target first and queues the scrolls with `Camera.set_zoom_async`, returning at once.

Example:
```luau

```

## Tasks.tiny_pitch_change

Definition:
```luau
function Tasks.tiny_pitch_change()
```
Changes the pitch by 3 to 15% of the pitch range, up or down, staying inside the `set_pitch_range` (the other way if the change would leave it). It works out the target first and queues the drag with `Camera.set_pitch_async`, returning at once.

Example:
```luau

```

## Tasks.small_camera_rotation

Definition:
```luau
function Tasks.small_camera_rotation(async: boolean?)
```
Rotates the camera by a small random angle. With `async` it queues the rotation and returns at once; the next input takes over.

Example:
```luau

```

## Tasks.large_camera_rotation

Definition:
```luau
function Tasks.large_camera_rotation()
```
TODO...

Example:
```luau

```

## Tasks.adjust_zoom

Definition:
```luau
function Tasks.adjust_zoom()
```
TODO...

Example:
```luau

```

## Tasks.adjust_pitch

Definition:
```luau
function Tasks.adjust_pitch()
```
Sets the pitch to a new random level inside the range of `Antiban.set_pitch_range`, at least a quarter of the range away from the current one. Does nothing if the range is too narrow.

Example:
```luau
Antiban.set_pitch_range(60, 100)
Tasks.adjust_pitch()
```

## Tasks.adjust_camera

Definition:
```luau
function Tasks.adjust_camera()
```
Runs `adjust_zoom` and `adjust_pitch`, in a random order picked with the biometrics. Loading this module also sets it as `Camera.face_task`, so it sometimes runs when the camera turns before an interaction (see [Camera.face](../camera.md)). Set `Camera.face_task = nil` to stop that.

Example:
```luau
Antiban.add_task(Tasks.adjust_camera, 3 * Antiban.MINUTE, 0.33)
```

## Tasks.adjust_minimap_zoom

Definition:
```luau
function Tasks.adjust_minimap_zoom(async: boolean?)
```
Zooms the minimap to a different random level between `Minimap.ZOOM_MIN` and `Minimap.ZOOM_MAX`, scrolling over it with the mouse. With `async` it queues the scrolls (`Minimap.set_zoom_async`) and returns at once. Does nothing if the minimap zoom can't be read.

Example:
```luau
Antiban.add_task(Tasks.adjust_minimap_zoom, 10 * Antiban.MINUTE, 0.2)
```

## Tasks.apply_zoom_range

Definition:
```luau
function Tasks.apply_zoom_range(): boolean
```
If the camera is zoomed outside the range, zooms to a random level inside it. Call it at the start of a script.

Example:
```luau
Antiban.set_zoom_range(0, 30)
Tasks.apply_zoom_range()
```

## Tasks.apply_pitch_range

Definition:
```luau
function Tasks.apply_pitch_range(): boolean
```
If the camera pitch is outside the range, sets it to a random level inside it. Call it at the start of a script.

Example:
```luau
Antiban.set_pitch_range(90, 100)
Tasks.apply_pitch_range()
```

## Tasks.skills

The names of the skills `hover_skills` picks from, like `{ "Fishing", "Cooking" }`.

## Tasks.hover_skills

Definition:
```luau
function Tasks.hover_skills(async: boolean?)
```
Hovers a random skill of `Tasks.skills` in the stats tab for 1 to 8 seconds, then goes back to the tab we were on half the time. Does nothing without skills. With `async` it queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued.

Example:
```luau
Tasks.skills = { "Fishing", "Cooking" }
Tasks.hover_skills()
```

## Tasks.swivel_near_box

Definition:
```luau
function Tasks.swivel_near_box(area: Box, radius: number, iterations: number?)
```
TODO...

Example:
```luau

```

## Tasks.swivel

Definition:
```luau
function Tasks.swivel()
```
TODO...

Example:
```luau

```

## Tasks.random_tab

Definition:
```luau
function Tasks.random_tab(async: boolean?)
```
Opens a random side tab, sometimes two with a pause between. With `async` it queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued.

Example:
```luau
local Tasks = require("../main/antiban/antiban_tasks")

Tasks.random_tab()
```

## Tasks.toggle_tab

Definition:
```luau
function Tasks.toggle_tab(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued.

Example:
```luau

```

## Tasks.random_chat_tab

Definition:
```luau
function Tasks.random_chat_tab(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued.

Example:
```luau

```

## Tasks.toggle_chat_tab

Definition:
```luau
function Tasks.toggle_chat_tab(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued.

Example:
```luau

```

## Tasks.random_chat_tab_state

Definition:
```luau
function Tasks.random_chat_tab_state()
```
TODO...

Example:
```luau

```

## Tasks.hover_make_item

Definition:
```luau
function Tasks.hover_make_item(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued.

Example:
```luau

```

## Tasks.hover_make_quantity

Definition:
```luau
function Tasks.hover_make_quantity(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued.

Example:
```luau

```

## Tasks.toggle_make_quantity

Definition:
```luau
function Tasks.toggle_make_quantity(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued. In async mode it never picks `X`.

Example:
```luau

```

## Tasks.hover_deposit_item

Definition:
```luau
function Tasks.hover_deposit_item(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued.

Example:
```luau

```

## Tasks.toggle_deposit_quantity

Definition:
```luau
function Tasks.toggle_deposit_quantity(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued.

Example:
```luau

```

## Tasks.hover_random_npc

Definition:
```luau
function Tasks.hover_random_npc(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued. In async mode it doesn't turn the camera or check the hover.

Example:
```luau

```

## Tasks.hover_random_player

Definition:
```luau
function Tasks.hover_random_player(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued. In async mode it doesn't turn the camera or check the hover.

Example:
```luau

```

## Tasks.hover_random_ground_item

Definition:
```luau
function Tasks.hover_random_ground_item(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued. In async mode it doesn't turn the camera or check the hover.

Example:
```luau

```

## Tasks.lose_focus

Definition:
```luau
function Tasks.lose_focus()
```
TODO...

Example:
```luau

```

## Tasks.random_camera_task

Definition:
```luau
function Tasks.random_camera_task()
```
TODO...

Example:
```luau

```

## Tasks.random_mouse_task

Definition:
```luau
function Tasks.random_mouse_task()
```
TODO...

Example:
```luau

```

## Tasks.random_game_tab_task

Definition:
```luau
function Tasks.random_game_tab_task(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued.

Example:
```luau

```

## Tasks.random_make_task

Definition:
```luau
function Tasks.random_make_task(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued.

Example:
```luau

```

## Tasks.random_chat_task

Definition:
```luau
function Tasks.random_chat_task(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued.

Example:
```luau

```

## Tasks.random_deposit_task

Definition:
```luau
function Tasks.random_deposit_task(async: boolean?)
```
Takes `async`: with it the task queues its input and waits as async input and returns at once; the next blocking input or minimenu read cancels what is still queued.

Example:
```luau

```

## Tasks.random_tiny

Definition:
```luau
function Tasks.random_tiny(min_cooldown: number, max_cooldown: number): boolean
```
Runs one random tiny task (`tiny_camera_rotation`, `tiny_zoom_change` or `tiny_pitch_change`) that is off its own cooldown, then puts that task on a random cooldown of `min_cooldown` to `max_cooldown` ms. The other tiny tasks are unaffected. Returns false, running nothing, when every tiny task is still cooling down.

Example:
```luau
if Biometrics.random_boolean(0.4) then
	AntibanTasks.random_tiny(10000, 15000)
end
```
