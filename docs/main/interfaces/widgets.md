# Main.Interfaces.Widgets

Working with individual pieces of the game's interface (buttons, text, icons, panels). Each piece is identified by a group number and a child number, written like `149:0`.

```luau
local Widgets = require("../main/interfaces/widgets")
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
local Widgets = require("../main/interfaces/widgets")

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
local Widgets = require("../main/interfaces/widgets")

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
local Widgets = require("../main/interfaces/widgets")

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
local Widgets = require("../main/interfaces/widgets")

print(Widgets.contains({ x = 100, y = 100, width = 40, height = 20 }, 110, 105)) -- true
```

## Widgets.click

Definition:
```luau
function Widgets.click(group: number, child: number, button: Button?): boolean
```
Clicks an interface piece, somewhere inside it. Returns `nil` and a message if it isn't open.

Example:
```luau
local Widgets = require("../main/interfaces/widgets")

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
local Widgets = require("../main/interfaces/widgets")

print(Widgets.click_async(149, 0))
```

## Widgets.checkbox

Definition:
```luau
function Widgets.checkbox(w: Widget): string?
```
Reads a checkbox and tells you if it is `"unticked"`, `"crossed"` or `"ticked"`. Returns an error if the piece isn't a checkbox.

Example:
```luau
local Widgets = require("../main/interfaces/widgets")

local w = Widgets.get(149, 0)
if w then
	print(Widgets.checkbox(w))
end
```
