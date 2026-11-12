# Main.Antiban.Antiban

Schedules antiban tasks, walking tasks, async tasks, breaks and sleeps. Register tasks at startup, call `sync_config` to plan breaks and sleeps from the loader's Breaks tab, then call `do_antiban` (or `do_walking_antiban` while walking) in your loop. Times are in milliseconds on a running clock that freezes while antiban works, so time spent on tasks and breaks doesn't count towards the next one.

```luau
local Antiban = require("@lib/main/antiban/antiban")
```

## Constants

Definition:

```luau
Antiban.SECOND = 1000
Antiban.MINUTE = 60000
Antiban.HOUR = 3600000
Antiban.DAY = 86400000
```

Durations in milliseconds.

Example:

```luau
Antiban.add_task(function() end, 15 * Antiban.MINUTE)
```

## Antiban.set_zoom_range

Definition:

```luau
function Antiban.set_zoom_range(min_percent: number, max_percent: number)
```

Limits the zoom antiban tasks pick from, as a percent (clamped 0-100) of the camera's range. Stores raw values in `Antiban.zoom` (`min`, `max`).

Example:

```luau
Antiban.set_zoom_range(0, 30)
```

## Antiban.set_pitch_range

Definition:

```luau
function Antiban.set_pitch_range(min_percent: number, max_percent: number)
```

Limits the pitch antiban tasks pick from, as a percent (0 lowest, 100 highest). Stores raw values in `Antiban.pitch`.

Example:

```luau
Antiban.set_pitch_range(90, 100)
```

## Antiban.add_task

Definition:

```luau
function Antiban.add_task(method: (async: boolean?) -> (), interval: number, randomness: number?, async: boolean?)
```

Schedules `method` about every `interval` ms (gaussian, `randomness` is the std as a fraction of the interval, default 0.2). The first run is uniformly within the first interval. Runs only from `do_antiban`/`do_task`, which pass `async` to `method`. Keep `method` short and safe to run at any point of your script.

Example:

```luau
Antiban.add_task(AntibanTasks.hover_skills, 15 * Antiban.MINUTE)
```

## Antiban.add_walk_task

Definition:

```luau
function Antiban.add_walk_task(method: (async: boolean?) -> (), interval: number, randomness: number?, async: boolean?)
```

Like `add_task`, for tasks safe while walking. Runs only from `do_walking_antiban`/`do_walk_task`.

Example:

```luau
Antiban.add_walk_task(AntibanTasks.random_rotate, 5 * Antiban.MINUTE)
```

## Antiban.add_async_task

Definition:

```luau
function Antiban.add_async_task(method: (async: boolean?) -> (), interval: number, randomness: number?, scope: Scope?)
```

Registers a task that queues its input and returns at once, due about every `interval` ms (`randomness` default 0.2). `scope` is `"game"`, `"outside"` or `"any"` (default). Unlike `add_task`, it doesn't pause the clock or fire the start/finish callbacks.

Example:

```luau
Antiban.add_async_task(AntibanTasks.tiny_camera_rotation, 25 * Antiban.SECOND, 0.4, "game")
```

## Antiban.delay_tasks

Definition:

```luau
function Antiban.delay_tasks(ms: number)
```

Pushes every task, walking task and async task back by `ms`. Breaks and sleeps are untouched. Use after a stretch where antiban couldn't run so tasks don't all come due at once.

Example:

```luau
local started = Host.time()
Antiban.delay_tasks(Host.time() - started)
```

## Antiban.apply_skips

Definition:

```luau
function Antiban.apply_skips(): boolean
```

Applies "Skip next" requests from the loader's Breaks tab (`Host.antiban_skips()`): the break or sleep's next occurrence is dropped and the one after keeps its cadence. Returns true if anything was skipped. `sync_config` calls it.

Example:

```luau
Antiban.apply_skips()
```

## Antiban.sync_config

Definition:

```luau
function Antiban.sync_config(): boolean
```

Plans breaks and sleeps from the loader's Breaks tab config. Call once in setup after `Biometrics.setup_player()`; `do_antiban`, `do_break`, `do_sleep` and `break_due` call it too, so config changes are picked up live. Returns true if the plan changed or a skip was applied.

An unchanged break or sleep keeps its due time across config edits. Values left on Auto come from biometrics: sleep time, length and logout chance, and break logout chance by length (1% up to 2 min, 2% up to 5, 5% up to 10, about 50% above). With breaks off, `breaks` and `sleeps` are empty.

Example:

```luau
Biometrics.setup_player()
Antiban.sync_config()
```

## Antiban.break_due

Definition:

```luau
function Antiban.break_due(): boolean
```

Whether a break or sleep is due, so the next `do_antiban` would take it. Use it to avoid starting something long right before one.

Example:

```luau
if not Antiban.break_due() then
	start_trip()
end
```

## Antiban.do_antiban

Definition:

```luau
function Antiban.do_antiban(check_tasks: boolean?, check_breaks: boolean?, check_sleeps: boolean?): boolean
```

Runs whatever tasks, breaks and sleeps are due (pass `false` to skip a kind), then logs back in if logged out. Does nothing when antiban is already running. Call only where a break is safe. Returns true if anything ran.

Example:

```luau
while true do
	Antiban.do_antiban()
end
```

## Antiban.do_walking_antiban

Definition:

```luau
function Antiban.do_walking_antiban(): boolean
```

Runs the due walking tasks. Call while walking. Returns true if one ran.

Example:

```luau
Antiban.do_walking_antiban()
```

## Antiban.do_task

Definition:

```luau
function Antiban.do_task(): boolean
```

Runs the due tasks without the `do_antiban` guard or login check. Returns true if one ran.

Example:

```luau
Antiban.do_task()
```

## Antiban.do_walk_task

Definition:

```luau
function Antiban.do_walk_task(): boolean
```

Runs the due walking tasks. Returns true if one ran.

Example:

```luau
Antiban.do_walk_task()
```

## Antiban.do_async_tasks

Definition:

```luau
function Antiban.do_async_tasks(scope: "game" | "outside"): boolean
```

Queues the first due async task whose scope is `scope` or `"any"`. Returns false without running anything while input is still queued (`Mouse.busy()`). A later blocking input cancels what it queued, so keep tab and chat tasks out of `"game"`: a cancelled restore leaves the wrong tab open.

Example:

```luau
Antiban.do_async_tasks("game")
```

## Antiban.do_break

Definition:

```luau
function Antiban.do_break(): boolean
```

Takes the due breaks. Returns true if one was taken.

Example:

```luau
Antiban.do_break()
```

## Antiban.do_sleep

Definition:

```luau
function Antiban.do_sleep(): boolean
```

Takes the due sleeps. Returns true if one was taken.

Example:

```luau
Antiban.do_sleep()
```

## Antiban.take_break

Definition:

```luau
function Antiban.take_break(task: Break)
```

Takes `task` now, due or not. Blocks for about `task.length` (gaussian), logs out with `task.logout_chance`, loses focus half the time, and calls `on_breaking` every 5 seconds.

Example:

```luau
Antiban.take_break(Antiban.breaks[1])
```

## Antiban.take_sleep

Definition:

```luau
function Antiban.take_sleep(task: Sleep)
```

Like `take_break` for a sleep: loses focus 70% of the time and calls `on_sleeping` every 5 minutes. Reschedules for the next day at `task.time`.

Example:

```luau
Antiban.take_sleep(Antiban.sleeps[1])
```

## Antiban.lose_focus

Definition:

```luau
function Antiban.lose_focus(): boolean
```

Moves the mouse just off either side of the game canvas. The client isn't actually told it lost focus. Breaks and sleeps call it at random.

Example:

```luau
Antiban.lose_focus()
```

## Antiban.time_running_at_clock

Definition:

```luau
function Antiban.time_running_at_clock(value: string, randomness: number?): number
```

The running-clock time when the time of day `value` ("HH:MM:SS") next comes, plus gaussian `randomness`. Same units as a sleep's `next`.

Example:

```luau
local due = Antiban.time_running_at_clock("01:30:45", 0.1)
```

## Antiban.time_until_break

Definition:

```luau
function Antiban.time_until_break(task: Break): string
```

Time until `task` is due, as "HH:MM:SS".

Example:

```luau
print(Antiban.time_until_break(Antiban.breaks[1]))
```

## Antiban.time_until_sleep

Definition:

```luau
function Antiban.time_until_sleep(task: Sleep): string
```

Time until `task` is due, as "HH:MM:SS".

Example:

```luau
print(Antiban.time_until_sleep(Antiban.sleeps[1]))
```

## Antiban.simulate_breaks

Definition:

```luau
function Antiban.simulate_breaks(botting_days: number?)
```

Simulates `botting_days` (default 1000) of the planned breaks and prints the average runtime per day.

Example:

```luau
Antiban.sync_config()
Antiban.simulate_breaks()
```

## Callbacks

Definition:

```luau
Antiban.on_start_task: ((task: Task) -> ())?
Antiban.on_finish_task: ((task: Task) -> ())?
Antiban.on_start_break: ((task: Break) -> ())?
Antiban.on_finish_break: ((task: Break) -> ())?
Antiban.on_start_sleep: ((task: Sleep) -> ())?
Antiban.on_finish_sleep: ((task: Sleep) -> ())?
Antiban.on_breaking: ((task: Break, countdown: Countdown) -> ())?
Antiban.on_sleeping: ((task: Sleep, countdown: Countdown) -> ())?
```

Optional hooks. `on_start_*`/`on_finish_*` run once per event; `on_breaking` runs every 5 seconds and `on_sleeping` every 5 minutes. Changing `countdown.finish` (`Host.time` ms) lengthens or shortens the event.

Example:

```luau
Antiban.on_start_break = function(task)
	walk_to_safe_spot()
end
```
