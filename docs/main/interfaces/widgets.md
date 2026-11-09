# Main.Interfaces.Widgets

Working with individual pieces of the game's interface (buttons, text, icons, panels). Each piece is identified by a group number and a child number, written like `149:0`.

```luau
local Widgets = require("@lib/main/interfaces/widgets")
```

## Constants

Definition:
```luau
Widgets.LAYER = 0
Widgets.RECTANGLE = 3
Widgets.TEXT = 4
Widgets.SPRITE = 5
Widgets.MODEL = 6
Widgets.CHECKBOX_SPRITE = 1215
```
The kinds of interface pieces (the `kind` of a widget) and the picture number of an unticked checkbox.

## Widgets.get

Definition:
```luau
function Widgets.get(group: number, child: number): Widget?
```
Looks up an interface piece. Returns `nil` when it isn't open.

Example:
```luau
local Widgets = require("@lib/main/interfaces/widgets")

local w = Widgets.get(149, 0)
print(if w then `{w.width}x{w.height} at {w.x}, {w.y}` else "not open")
```

## Widgets.is_open

Definition:
```luau
function Widgets.is_open(group: number, child: number): boolean
```
Whether an interface piece currently exists on screen.

Example:
```luau
local Widgets = require("@lib/main/interfaces/widgets")

print("open:", Widgets.is_open(149, 0))
```

## Widgets.center

Definition:
```luau
function Widgets.center(w: Area): (number, number)
```
The middle point `x, y` of an interface piece.

Example:
```luau
local Widgets = require("@lib/main/interfaces/widgets")

local x, y = Widgets.center({ x = 100, y = 100, width = 40, height = 20 })
print(x, y) -- 120 110
```

## Widgets.contains

Definition:
```luau
function Widgets.contains(w: Area, x: number, y: number): boolean
```
Whether a point is inside an interface piece.

Example:
```luau
local Widgets = require("@lib/main/interfaces/widgets")

print(Widgets.contains({ x = 100, y = 100, width = 40, height = 20 }, 110, 105)) -- true
```

## Widgets.click

Definition:
```luau
function Widgets.click(group: number, child: number, button: Button?): boolean
```
Clicks an interface piece, somewhere inside it. Returns `false` if it isn't open.

Example:
```luau
local Widgets = require("@lib/main/interfaces/widgets")

print(Widgets.click(149, 0))
```

## Widgets.click_async

Definition:
```luau
function Widgets.click_async(group: number, child: number, button: Button?): boolean
```
Like `Widgets.click`, but queues the move and click as async input and returns at once. Returns `false` if the interface isn't open.

Example:
```luau
local Widgets = require("@lib/main/interfaces/widgets")

print(Widgets.click_async(149, 0))
```

## Widgets.checkbox

Definition:
```luau
function Widgets.checkbox(w: Widget): string?
```
Reads a checkbox and tells you if it is `"unticked"`, `"crossed"` or `"ticked"`. Returns `nil` if the piece isn't a checkbox.

Example:
```luau
local Widgets = require("@lib/main/interfaces/widgets")

local w = Widgets.get(149, 0)
if w then
	print(Widgets.checkbox(w))
end
```

## Widgets.wait_until

Definition:
```luau
function Widgets.wait_until(check: () -> boolean, timeout_ms: number, interval_ms: number?): boolean
```
Calls `check` until it returns `true` or `timeout_ms` has passed, sleeping `interval_ms` (50 by default) between calls. The time counts only the sleeps, so `check` runs once more when it is up. Returns whether `check` came true.

Example:
```luau
local Widgets = require("@lib/main/interfaces/widgets")

print(Widgets.wait_until(function()
	return Widgets.is_open(149, 0)
end, 1200))
```

## Widgets.wait_for

Definition:
```luau
function Widgets.wait_for(check: () -> boolean, timeout_ms: number, poll_ms: number): boolean
```
Calls `check` until it returns `true` or `timeout_ms` of clock time has passed, sleeping `poll_ms` between calls. The clock is read after each call, so `check` always runs at least once and once more after the last sleep. Returns whether `check` came true.

Example:
```luau
local Widgets = require("@lib/main/interfaces/widgets")

print(Widgets.wait_for(function()
	return Widgets.is_open(149, 0)
end, 1200, 50))
```

## Widgets.wait_within

Definition:
```luau
function Widgets.wait_within(check: () -> boolean, timeout_ms: number, poll_ms: number): boolean
```
Calls `check` while less than `timeout_ms` of clock time has passed, sleeping `poll_ms` between calls. Unlike `wait_for`, the clock is read before each call, so nothing is checked once time is up and a `timeout_ms` of 0 checks nothing. Returns whether `check` came true in time.

Example:
```luau
local Widgets = require("@lib/main/interfaces/widgets")

print(Widgets.wait_within(function()
	return Widgets.is_open(149, 0)
end, 1200, 50))
```
