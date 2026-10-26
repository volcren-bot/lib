# Main.Interfaces.Mainscreen.Toplevel

The main game screen: which windows are open on top of it (bank, shop, dialogue...), where the 3D view is, and which parts of it are covered by panels. Use it to make sure a click lands on the game and not on something in the way.

```luau
local Toplevel = require("../main/interfaces/mainscreen/toplevel")
```

An open window is a table with `group` (its interface number) and `slot` (`"modal"`, `"crm"` or `"floater"`: the layer it's in).

## Constants

Definition:
```luau
Toplevel.SLOTS
Toplevel.LAYOUT
```
Tables describing, for each game window layout, where windows are placed and where the 3D view and the panels covering it are.

## Toplevel.interfaces

Definition:
```luau
function Toplevel.interfaces(): { Open }?
```
Every window open on the main screen, the most important first.

Example:
```luau
local Toplevel = require("../main/interfaces/mainscreen/toplevel")

for _, open in ipairs(Toplevel.interfaces() or {}) do
	print(open.group, open.slot)
end
```

## Toplevel.interface

Definition:
```luau
function Toplevel.interface(): number?
```
The interface number of the most important open window, or `nil` if none.

Example:
```luau
local Toplevel = require("../main/interfaces/mainscreen/toplevel")

print(Toplevel.interface())
```

## Toplevel.interface_name

Definition:
```luau
function Toplevel.interface_name(): string?
```
The readable name of that window.

Example:
```luau
local Toplevel = require("../main/interfaces/mainscreen/toplevel")

print(Toplevel.interface_name())
```

## Toplevel.close

Definition:
```luau
function Toplevel.close(group: number | string, button: () -> Widget?, key_probability: number?, timeout_ms: number?): boolean
```
Closes an interface of the main screen and waits for it to close (`timeout_ms` for each try, 3 ticks by default). It presses Escape with the chance `key_probability` (by default the `Biometrics.ESCAPE` probability), unless the client's "Esc to close" setting is off. If that doesn't close it, or Escape isn't used, it clicks the widget `button()` returns, up to 3 times; `button` returns `nil` when the close button can't be found, and then `close` fails. Returns `true` at once when it isn't open.

Example:
```luau
local Toplevel = require("../main/interfaces/mainscreen/toplevel")
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

Toplevel.close(Bankmain.GROUP, Bankmain.close_button)
```

## Toplevel.has_interface

Definition:
```luau
function Toplevel.has_interface(): boolean
```
Whether any window is open on the main screen.

Example:
```luau
local Toplevel = require("../main/interfaces/mainscreen/toplevel")

print("something open:", Toplevel.has_interface())
```

## Toplevel.is_open

Definition:
```luau
function Toplevel.is_open(interface: number | string): boolean
```
Whether a particular window is open, given by its number or name.

Example:
```luau
local Toplevel = require("../main/interfaces/mainscreen/toplevel")

print("bank open:", Toplevel.is_open(12))
```

## Toplevel.viewport

Definition:
```luau
function Toplevel.viewport(): Box?
```
The rectangle the 3D game world is drawn in.

Example:
```luau
local Toplevel = require("../main/interfaces/mainscreen/toplevel")

local view = Toplevel.viewport()
print(view and view.x1, view and view.y1, view and view.x2, view and view.y2)
```

## Toplevel.blockers

Definition:
```luau
function Toplevel.blockers(): { Box }?
```
The rectangles drawn on top of the 3D view (side panels, chat, open windows), where a click would hit them instead of the world.

Example:
```luau
local Toplevel = require("../main/interfaces/mainscreen/toplevel")

print("covering panels:", #(Toplevel.blockers() or {}))
```

## Toplevel.is_visible

Definition:
```luau
function Toplevel.is_visible(p: Point, viewport: Box?, blockers: { Box }?): boolean
```
Whether a point is on the 3D view and not covered by anything. You can pass `viewport` and `blockers` you already have to save time when checking many points.

Example:
```luau
local Toplevel = require("../main/interfaces/mainscreen/toplevel")

print(Toplevel.is_visible({ x = 300, y = 200 }))
```

## Toplevel.visible_point

Definition:
```luau
function Toplevel.visible_point(area: Box): Point?
```
Finds a point inside a rectangle that is on the 3D view and uncovered, as close as possible to the rectangle's middle. Returns `nil` if the whole rectangle is covered.

Example:
```luau
local Geometry = require("../utils/math/geometry")
local Toplevel = require("../main/interfaces/mainscreen/toplevel")

print(Toplevel.visible_point(Geometry.Box.new(100, 100, 300, 300)))
```
