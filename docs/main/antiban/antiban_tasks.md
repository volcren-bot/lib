# Main.Antiban.AntibanTasks

Ready-made antiban tasks to register with [Antiban](antiban.md). Tasks taking `async` queue their input and return at once when it is `true`; the next blocking input or minimenu read cancels what is still queued. Tasks that can't read what they need (camera, tab, interface) log and do nothing. Loading this module sets `Camera.face_task = Tasks.adjust_camera`.

```luau
local Tasks = require("@lib/main/antiban/antiban_tasks")
```

## Tasks.skills

Definition:

```luau
Tasks.skills: { string }
```

Skill names `hover_skills` picks from. Empty by default.

Example:

```luau
Tasks.skills = { "Fishing", "Cooking" }
```

## Tasks.TASKS

Definition:

```luau
Tasks.TASKS: { [string]: (async: boolean?) -> () }
```

Every task by name (`HoverSkills`, `TinyCameraRotation`, ...), for picking tasks from config.

Example:

```luau
Antiban.add_task(Tasks.TASKS.HoverSkills, 10 * Antiban.MINUTE)
```

## Tasks.WALKING_TASKS

Definition:

```luau
Tasks.WALKING_TASKS: { [string]: (async: boolean?) -> () }
```

The subset of `TASKS` safe while walking: no make, deposit, skill-hover or random-event tasks.

Example:

```luau
Antiban.add_walk_task(Tasks.WALKING_TASKS.Swivel, 5 * Antiban.MINUTE)
```

## Tasks.small_random_mouse

Definition:

```luau
function Tasks.small_random_mouse()
```

Moves the mouse 50 to 350 px in a random direction with `Mouse.move_async`, returning at once.

Example:

```luau
Tasks.small_random_mouse()
```

## Tasks.large_random_mouse

Definition:

```luau
function Tasks.large_random_mouse()
```

Moves the mouse, temporarily faster, to a few random points across and slightly beyond the canvas, with short pauses. Blocks.

Example:

```luau
Tasks.large_random_mouse()
```

## Tasks.random_right_click

Definition:

```luau
function Tasks.random_right_click()
```

Right-clicks a random canvas point, sometimes hovers a row, then either clicks Examine (60% when present) or waits 0.3 to 6 s and closes the menu.

Example:

```luau
Tasks.random_right_click()
```

## Tasks.tiny_camera_rotation

Definition:

```luau
function Tasks.tiny_camera_rotation()
```

Queues a 5 to 20 degree yaw change left or right with `Camera.set_yaw_degrees_async`, returning at once.

Example:

```luau
Antiban.add_async_task(Tasks.tiny_camera_rotation, 25 * Antiban.SECOND, 0.4, "game")
```

## Tasks.tiny_zoom_change

Definition:

```luau
function Tasks.tiny_zoom_change()
```

Queues 1 or 2 zoom notches in or out within the antiban zoom range (reversing if the change would leave it), returning at once.

Example:

```luau
Tasks.tiny_zoom_change()
```

## Tasks.tiny_pitch_change

Definition:

```luau
function Tasks.tiny_pitch_change()
```

Queues a pitch change of 3 to 15% of the range up or down within the antiban pitch range (reversing if needed), returning at once.

Example:

```luau
Tasks.tiny_pitch_change()
```

## Tasks.random_tiny

Definition:

```luau
function Tasks.random_tiny(min_cooldown: number, max_cooldown: number): boolean
```

Runs one random tiny task (rotation, zoom or pitch) that is off its own cooldown, then cools that one down for `min_cooldown` to `max_cooldown` ms. Returns false when all are cooling down.

Example:

```luau
Tasks.random_tiny(10000, 15000)
```

## Tasks.small_camera_rotation

Definition:

```luau
function Tasks.small_camera_rotation(async: boolean?)
```

Rotates the yaw by a gaussian angle (mean 15, std 45 degrees), left, right or not at all (a third each).

Example:

```luau
Tasks.small_camera_rotation()
```

## Tasks.large_camera_rotation

Definition:

```luau
function Tasks.large_camera_rotation()
```

Rotates the yaw by a gaussian angle (mean 30, std 360 degrees), left, right or not at all. Blocks.

Example:

```luau
Tasks.large_camera_rotation()
```

## Tasks.adjust_zoom

Definition:

```luau
function Tasks.adjust_zoom()
```

Sets the zoom to a new random level in the antiban zoom range, more than 15 away from the current one. Does nothing if the range spans 15 or less.

Example:

```luau
Tasks.adjust_zoom()
```

## Tasks.adjust_pitch

Definition:

```luau
function Tasks.adjust_pitch()
```

Sets the pitch to a new random level in the antiban pitch range, at least a quarter of the range away. Does nothing if the range is too narrow.

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

Runs `adjust_zoom` and `adjust_pitch` in a random order. Also set as `Camera.face_task`, so it sometimes runs when the camera turns before an interaction (see [Camera.face](../camera.md)); set `Camera.face_task = nil` to stop that.

Example:

```luau
Antiban.add_task(Tasks.adjust_camera, 3 * Antiban.MINUTE, 0.33)
```

## Tasks.adjust_minimap_zoom

Definition:

```luau
function Tasks.adjust_minimap_zoom(async: boolean?)
```

Scrolls the minimap to a different random zoom between `Minimap.ZOOM_MIN` and `Minimap.ZOOM_MAX`.

Example:

```luau
Antiban.add_task(Tasks.adjust_minimap_zoom, 10 * Antiban.MINUTE, 0.2)
```

## Tasks.apply_zoom_range

Definition:

```luau
function Tasks.apply_zoom_range(): boolean
```

If the zoom is outside the antiban range, sets it to a random level inside. Returns false if the zoom is unreadable or setting failed. Call at script start.

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

Like `apply_zoom_range` for the pitch.

Example:

```luau
Antiban.set_pitch_range(90, 100)
Tasks.apply_pitch_range()
```

## Tasks.hover_skills

Definition:

```luau
function Tasks.hover_skills(async: boolean?)
```

Hovers a random skill from `Tasks.skills` in the stats tab for 1 to 8 s, then half the time reopens the previous tab. Does nothing without skills.

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

Traces `iterations` (default 1) curly mouse paths of `radius` px, each starting from a random point in `area`. Blocks.

Example:

```luau
Tasks.swivel_near_box(Box.new(100, 100, 300, 300), 30)
```

## Tasks.swivel

Definition:

```luau
function Tasks.swivel()
```

Traces a few curly mouse paths of 25 to 40 px around the current mouse position. Blocks.

Example:

```luau
Tasks.swivel()
```

## Tasks.random_tab

Definition:

```luau
function Tasks.random_tab(async: boolean?)
```

Opens a random side tab (80% from combat to magic, else the lower row), half the time two with a pause between.

Example:

```luau
Tasks.random_tab()
```

## Tasks.toggle_tab

Definition:

```luau
function Tasks.toggle_tab(async: boolean?)
```

Opens a random side tab, waits 0.5 to 6 s, then reopens the original tab.

Example:

```luau
Tasks.toggle_tab()
```

## Tasks.random_chat_tab

Definition:

```luau
function Tasks.random_chat_tab(async: boolean?)
```

Opens a random chat tab (game, public, private, channel, clan or trade).

Example:

```luau
Tasks.random_chat_tab()
```

## Tasks.toggle_chat_tab

Definition:

```luau
function Tasks.toggle_chat_tab(async: boolean?)
```

Opens a random chat tab, waits 3 to 5 s, then reopens the original one. Does nothing if the chat tabs aren't loaded.

Example:

```luau
Tasks.toggle_chat_tab()
```

## Tasks.random_chat_tab_state

Definition:

```luau
function Tasks.random_chat_tab_state()
```

Sets a random chat tab to a random filter state (game is always set to filtered). Blocks.

Example:

```luau
Tasks.random_chat_tab_state()
```

## Tasks.hover_make_item

Definition:

```luau
function Tasks.hover_make_item(async: boolean?)
```

Hovers a random option of the open make interface. Does nothing when it isn't open.

Example:

```luau
Tasks.hover_make_item()
```

## Tasks.hover_make_quantity

Definition:

```luau
function Tasks.hover_make_quantity(async: boolean?)
```

Hovers a random quantity button of the open make interface for 0.5 to 2 s.

Example:

```luau
Tasks.hover_make_quantity()
```

## Tasks.toggle_make_quantity

Definition:

```luau
function Tasks.toggle_make_quantity(async: boolean?)
```

Selects a random make quantity, waits 1 to 3 s, then restores the original. `X` enters 1 to 26; async mode never picks `X`.

Example:

```luau
Tasks.toggle_make_quantity()
```

## Tasks.hover_deposit_item

Definition:

```luau
function Tasks.hover_deposit_item(async: boolean?)
```

Hovers a random item of the open deposit box for 0.5 to 2 s.

Example:

```luau
Tasks.hover_deposit_item()
```

## Tasks.toggle_deposit_quantity

Definition:

```luau
function Tasks.toggle_deposit_quantity(async: boolean?)
```

Selects another deposit box quantity, waits 1 to 3 s, then restores the original. Does nothing if none is selected.

Example:

```luau
Tasks.toggle_deposit_quantity()
```

## Tasks.hover_random_npc

Definition:

```luau
function Tasks.hover_random_npc(async: boolean?)
```

Hovers a random nearby NPC for 1.5 to 2.7 s. Async mode doesn't turn the camera or check the hover.

Example:

```luau
Tasks.hover_random_npc()
```

## Tasks.hover_random_player

Definition:

```luau
function Tasks.hover_random_player(async: boolean?)
```

Like `hover_random_npc` for players.

Example:

```luau
Tasks.hover_random_player()
```

## Tasks.hover_random_ground_item

Definition:

```luau
function Tasks.hover_random_ground_item(async: boolean?)
```

Like `hover_random_npc` for ground items.

Example:

```luau
Tasks.hover_random_ground_item()
```

## Tasks.lose_focus

Definition:

```luau
function Tasks.lose_focus()
```

Logs and calls [`Antiban.lose_focus`](antiban.md#antibanlose_focus).

Example:

```luau
Tasks.lose_focus()
```

## Tasks.random_camera_task

Definition:

```luau
function Tasks.random_camera_task()
```

Runs one of `adjust_zoom` (20%), `adjust_pitch` (20%), `adjust_camera` (10%), `small_camera_rotation` (30%) or `large_camera_rotation` (20%).

Example:

```luau
Antiban.add_task(Tasks.random_camera_task, 4 * Antiban.MINUTE)
```

## Tasks.random_mouse_task

Definition:

```luau
function Tasks.random_mouse_task()
```

Runs one of `random_right_click` (20%), `large_random_mouse` (30%) or `small_random_mouse` (50%).

Example:

```luau
Tasks.random_mouse_task()
```

## Tasks.random_game_tab_task

Definition:

```luau
function Tasks.random_game_tab_task(async: boolean?)
```

Runs `random_tab` (4/13), `toggle_tab` (6/13) or nothing.

Example:

```luau
Tasks.random_game_tab_task()
```

## Tasks.random_make_task

Definition:

```luau
function Tasks.random_make_task(async: boolean?)
```

Runs `hover_make_item` (4/11), `hover_make_quantity` (3/11), `toggle_make_quantity` (2/11) or nothing.

Example:

```luau
Tasks.random_make_task()
```

## Tasks.random_chat_task

Definition:

```luau
function Tasks.random_chat_task(async: boolean?)
```

Runs `random_chat_tab` (6/30), `toggle_chat_tab` (12/30), `random_chat_tab_state` (5/30, always blocking) or nothing.

Example:

```luau
Tasks.random_chat_task()
```

## Tasks.random_deposit_task

Definition:

```luau
function Tasks.random_deposit_task(async: boolean?)
```

Runs `hover_deposit_item` (4/11), `toggle_deposit_quantity` (2/11) or nothing.

Example:

```luau
Tasks.random_deposit_task()
```

## Tasks.handle_randoms

Definition:

```luau
function Tasks.handle_randoms()
```

Handles a random event targeting the player via [`Randoms.handle`](randoms.md). Costs one NPC read when there is none. Give it a short interval, since events don't wait; it interrupts the script, so it isn't in `WALKING_TASKS`.

Example:

```luau
Antiban.add_task(Tasks.handle_randoms, 30 * Antiban.SECOND, 0.33)
```
