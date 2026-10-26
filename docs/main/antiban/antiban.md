# Main.Antiban.Antiban

The scheduler for antiban: timed tasks, breaks, sleeps and walking tasks. Schedule them once when the script starts, then call `do_antiban` (or `do_walking_antiban` while walking) in your loop; the ones that are due get taken then. Breaks and sleeps log out or lose focus now and then, like a person would, and log back in afterwards.

Times are in milliseconds, and the scheduling uses a running clock that freezes while antiban works, so the time spent on breaks and tasks doesn't count towards the next one.

```luau
local Antiban = require("../main/antiban/antiban")
```

## Constants

Definition:

```luau
Antiban.SECOND = 1000
Antiban.MINUTE = 60000
Antiban.HOUR = 3600000
Antiban.DAY = 86400000
```

Times in milliseconds, for writing intervals as `15 * Antiban.MINUTE`.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.add_task(function() end, 15 * Antiban.MINUTE)
```

## Antiban.set_zoom_range

Definition:

```luau
function Antiban.set_zoom_range(min_percent: number, max_percent: number)
```

Limits the zoom the antiban tasks pick from, in percent of the camera's whole range (0 is as far as it goes, 100 as close). The result is in `Antiban.zoom` (`min`, `max`, raw values).

Example:

```luau
Antiban.set_zoom_range(0, 30)
```

## Antiban.set_pitch_range

Definition:

```luau
function Antiban.set_pitch_range(min_percent: number, max_percent: number)
```

Limits the camera pitch, in percent of its whole range (0 is the lowest pitch, 100 the highest). The result is in `Antiban.pitch` (`min`, `max`, raw values).

Example:

```luau
Antiban.set_pitch_range(90, 100)
```

## Antiban.add_task

Definition:

```luau
function Antiban.add_task(method: (async: boolean?) -> (), interval: number, randomness: number?, async: boolean?)
```

Schedules `method` every `interval` ms, give or take `randomness` (a fraction of the interval, 0.2 by default). `method` should be a short action that won't break your script. It only runs from `do_antiban`, which calls it with `async` (`false` by default). Tasks that take `async` queue their input and return at once when it is `true`; a later blocking input cuts what is still queued short.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.add_task(function()
	-- hover a skill, move the mouse around, ...
end, 15 * Antiban.MINUTE)
```

## Antiban.add_walk_task

Definition:

```luau
function Antiban.add_walk_task(method: (async: boolean?) -> (), interval: number, randomness: number?, async: boolean?)
```

Like `add_task`, for tasks that are fine to do while walking. They only run from `do_walking_antiban`.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.add_walk_task(function()
	-- look at the camera, ...
end, 5 * Antiban.MINUTE)
```

## Antiban.delay_tasks

Definition:

```luau
function Antiban.delay_tasks(ms: number)
```

Pushes the due time of every task and walking task back by `ms`, as if their timers had stopped for that long. Breaks and sleeps are untouched. Useful after a stretch where no antiban could run, so the tasks don't all come due at once.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

local started = Host.time()
-- ... a minigame ...
Antiban.delay_tasks(Host.time() - started)
```

## Antiban.add_break

Definition:

```luau
function Antiban.add_break(interval: number, length: number, randomness: number?, logout_chance: number?)
```

Schedules a break of about `length` ms every `interval` ms (`randomness` 0.2 by default). During it the script waits, with a `logout_chance` of logging out for it (0.33 by default). Breaks should be shorter than sleeps. They only happen from `do_antiban`.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.add_break(30 * Antiban.MINUTE, 5 * Antiban.MINUTE)
```

## Antiban.add_sleep

Definition:

```luau
function Antiban.add_sleep(time: string, length: number, randomness: number?, logout_chance: number?)
```

Schedules a sleep, a long break, of about `length` ms at the time of day `time` ("HH:MM" or "HH:MM:SS", 24 hour, on this computer's clock). It's never taken before `time`; `randomness` (0.1 by default) pushes it later by a fraction of a day. `logout_chance` (0.5 by default) is the chance of logging out for it. Sleeps only happen from `do_antiban`.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.add_sleep("01:30:45", 8 * Antiban.HOUR, 0.1, 0.8)
```

## Antiban.break_due

```luau
function Antiban.break_due(): boolean
```

Whether a break or a sleep is due, so the next `do_antiban` would take it. Lets a script avoid starting something long right before one.

## Antiban.do_antiban

Definition:

```luau
function Antiban.do_antiban(check_tasks: boolean?, check_breaks: boolean?, check_sleeps: boolean?): boolean
```

Runs whatever is due: tasks, breaks and sleeps (pass `false` to leave one kind out). Logs back in if the client was logged out. Only call it where a break won't break your script. Returns true if anything was done.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

while true do
	Antiban.do_antiban()
	-- the rest of the script
end
```

## Antiban.do_walking_antiban

Definition:

```luau
function Antiban.do_walking_antiban(): boolean
```

Runs the walking tasks that are due. Call it while walking. Returns true if one ran.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.do_walking_antiban()
```

## Antiban.do_task

Definition:

```luau
function Antiban.do_task(): boolean
```

Runs the tasks that are due, and returns true if one ran. `do_antiban` calls it; use it on its own only where a short action won't break your script.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.do_task()
```

## Antiban.do_walk_task

Definition:

```luau
function Antiban.do_walk_task(): boolean
```

Runs the walking tasks that are due, and returns true if one ran.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.do_walk_task()
```

## Antiban.do_break

Definition:

```luau
function Antiban.do_break(): boolean
```

Takes the breaks that are due, and returns true if one was taken.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.do_break()
```

## Antiban.do_sleep

Definition:

```luau
function Antiban.do_sleep(): boolean
```

Takes the sleeps that are due, and returns true if one was taken.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.do_sleep()
```

## Antiban.take_break

Definition:

```luau
function Antiban.take_break(task: Break)
```

Takes the break `task` now, whether it's due or not. Waits out its length (about `task.length`, with its randomness), with the chance of logging out and losing focus. The `on_breaking` callback runs every 5 seconds meanwhile.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.add_break(30 * Antiban.MINUTE, 5 * Antiban.MINUTE)
Antiban.take_break(Antiban.breaks[1])
```

## Antiban.take_sleep

Definition:

```luau
function Antiban.take_sleep(task: Sleep)
```

Takes the sleep `task` now, whether it's due or not. Same as `take_break`, with the `on_sleeping` callback every 5 minutes.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.add_sleep("23:00:00", 6 * Antiban.HOUR)
Antiban.take_sleep(Antiban.sleeps[1])
```

## Antiban.lose_focus

Definition:

```luau
function Antiban.lose_focus(): boolean
```

Moves the mouse off the game canvas, to one side, the way a player does when they click away from the game. An approximation: the game isn't told it lost focus. Breaks and sleeps call it at random.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.lose_focus()
```

## Antiban.time_running_at_clock

Definition:

```luau
function Antiban.time_running_at_clock(value: string, randomness: number?): number
```

The running time at which the time of day `value` ("HH:MM:SS") next comes, with the gaussian `randomness` after it. Used for sleeps; returns a value in the same units as the sleeps' `next`.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

local due = Antiban.time_running_at_clock("01:30:45", 0.1)
```

## Antiban.time_until_break

Definition:

```luau
function Antiban.time_until_break(task: Break): string
```

How long until the break is due, as "HH:MM:SS". Useful for showing the user.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

print("next break in", Antiban.time_until_break(Antiban.breaks[1]))
```

## Antiban.time_until_sleep

Definition:

```luau
function Antiban.time_until_sleep(task: Sleep): string
```

How long until the sleep is due, as "HH:MM:SS".

Example:

```luau
local Antiban = require("../main/antiban/antiban")

print("next sleep in", Antiban.time_until_sleep(Antiban.sleeps[1]))
```

## Antiban.simulate_breaks

Definition:

```luau
function Antiban.simulate_breaks(botting_days: number?)
```

Simulates `botting_days` (1000 by default) days with the breaks set up and prints how long the script runs for per day on average.

Example:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.add_break(30 * Antiban.MINUTE, 5 * Antiban.MINUTE)
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

Set any of these to run your own code at those points. `on_start_*` and `on_finish_*` run once per event. `on_breaking` runs every 5 seconds during a break and `on_sleeping` every 5 minutes during a sleep. Their `countdown.finish` (in `Host.time` ms) can be changed to make the event longer or shorter.

Example, walking to a safe spot before a break:

```luau
local Antiban = require("../main/antiban/antiban")

Antiban.on_start_break = function(task)
	-- walk somewhere safe, ...
end
```

## Limitations

- No skill field, and no debugging switches. The skills live in `antiban_tasks` (`Tasks.skills`), and the rest belongs to the scripts that use them or isn't implemented yet (the bank task, and so on).
- No pausing of the client's timers. The running clock covers it.
- `lose_focus` only moves the mouse off the canvas (see above).

## Antiban.add_async_task

Definition:

```luau
function Antiban.add_async_task(method: (async: boolean?) -> (), interval: number, randomness: number?, scope: Scope?)
```

Registers a task that queues its input and returns at once, due about every `interval` ms (gaussian, `randomness` defaults to 0.2). `scope` is `"game"`, `"outside"` or `"any"` (default). `do_async_tasks` calls it with `async = true`. Unlike `add_task`, it doesn't pause the clock or fire the start/finish hooks.

Example:

```luau
Antiban.add_async_task(AntibanTasks.tiny_camera_rotation, 25 * Antiban.SECOND, 0.4, "game")
Antiban.add_async_task(AntibanTasks.random_tab, 40 * Antiban.SECOND, 0.4, "outside")
```

## Antiban.do_async_tasks

Definition:

```luau
function Antiban.do_async_tasks(scope: "game" | "outside"): boolean
```

Queues the first due async task whose scope is `scope` or `"any"`, and returns true if one ran. It returns false without running anything while input is still queued (`Mouse.busy()`). Call it from the script's loop; a later blocking input cancels what it queued. Keep tab and chat tasks out of the `"game"` scope, since a cancelled restore step leaves the wrong tab open.

Example:

```luau
if Biometrics.random_boolean(0.4) then
	Antiban.do_async_tasks("game")
end
```
