# Main.Interfaces.Widgets

Individual interface widgets (buttons, text, sprites, layers), addressed by group and child, written `149:0`.

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
Widget `kind` values, and the first sprite of the checkbox set.

## Widgets.get

Definition:
```luau
function Widgets.get(group: number, child: number): Widget?
```
The widget, nil when not open.

Example:
```luau
local w = Widgets.get(149, 0)
print(w and `{w.width}x{w.height} at {w.x}, {w.y}`)
```

## Widgets.is_open

Definition:
```luau
function Widgets.is_open(group: number, child: number): boolean
```
Whether the widget exists.

Example:
```luau
print(Widgets.is_open(149, 0))
```

## Widgets.center

Definition:
```luau
function Widgets.center(w: Area): (number, number)
```
Centre `x, y` of an area.

Example:
```luau
print(Widgets.center({ x = 100, y = 100, width = 40, height = 20 })) -- 120 110
```

## Widgets.contains

Definition:
```luau
function Widgets.contains(w: Area, x: number, y: number): boolean
```
Whether the point is inside the area.

Example:
```luau
print(Widgets.contains({ x = 100, y = 100, width = 40, height = 20 }, 110, 105)) -- true
```

## Widgets.click

Definition:
```luau
function Widgets.click(group: number, child: number, button: Button?): boolean
```
Clicks a random point inside the widget; `false` when not open.

Example:
```luau
print(Widgets.click(149, 0))
```

## Widgets.click_async

Definition:
```luau
function Widgets.click_async(group: number, child: number, button: Button?): boolean
```
`Widgets.click` queued as async input; returns at once.

Example:
```luau
print(Widgets.click_async(149, 0))
```

## Widgets.checkbox

Definition:
```luau
function Widgets.checkbox(w: Widget): string?
```
`"unticked"`, `"crossed"` or `"ticked"`; nil when the widget isn't a checkbox sprite.

Example:
```luau
local w = Widgets.get(149, 0)
print(w and Widgets.checkbox(w))
```

## Widgets.wait_until

Definition:
```luau
function Widgets.wait_until(check: () -> boolean, timeout_ms: number, interval_ms: number?): boolean
```
Polls `check` every `interval_ms` (default 50) until true. The timeout counts summed sleeps, not clock time, and `check` runs once more when it's reached.

Example:
```luau
print(Widgets.wait_until(function()
	return Widgets.is_open(149, 0)
end, 1200))
```

## Widgets.wait_for

Definition:
```luau
function Widgets.wait_for(check: () -> boolean, timeout_ms: number, poll_ms: number): boolean
```
Polls `check` every `poll_ms` until true or `timeout_ms` of clock time passes; always runs at least once, and once after the deadline's last sleep.

Example:
```luau
print(Widgets.wait_for(function()
	return Widgets.is_open(149, 0)
end, 1200, 50))
```

## Widgets.wait_within

Definition:
```luau
function Widgets.wait_within(check: () -> boolean, timeout_ms: number, poll_ms: number): boolean
```
Like `wait_for` but checks the clock before each call, so nothing runs after the deadline and a 0 timeout checks nothing.

Example:
```luau
print(Widgets.wait_within(function()
	return Widgets.is_open(149, 0)
end, 1200, 50))
```
