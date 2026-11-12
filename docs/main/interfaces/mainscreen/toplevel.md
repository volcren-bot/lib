# Main.Interfaces.Mainscreen.Toplevel

The main game screen: which windows are open on it, where the 3D view is and what covers it. An open window is an `Open` table: `group` (interface number) and `slot` (`"modal"`, `"crm"` or `"floater"`).

```luau
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
```

## Constants

Definition:
```luau
Toplevel.SLOTS
Toplevel.LAYOUT
Toplevel.ESCAPE_TRIES = 3
Toplevel.ESCAPE_PAUSE_MS = { 150, 400 }
```
- `SLOTS`: per root layout, the child of each window slot.
- `LAYOUT`: per root layout, the viewport child and the panel children covering it.
- `ESCAPE_TRIES`: Escape presses before Escape closing is switched off.
- `ESCAPE_PAUSE_MS`: random pause range between Escape tries.

## Toplevel.interfaces

Definition:
```luau
function Toplevel.interfaces(): { Open }?
```
Every open main screen window, ordered modal, floater, crm. `nil` when the layout is unknown or state is unavailable.

Example:
```luau
for _, open in ipairs(Toplevel.interfaces() or {}) do
	print(open.group, open.slot)
end
```

## Toplevel.interface

Definition:
```luau
function Toplevel.interface(): number?
```
The group of the first window from `interfaces`, or `nil` if none.

Example:
```luau
print(Toplevel.interface())
```

## Toplevel.interface_name

Definition:
```luau
function Toplevel.interface_name(): string?
```
The name of `Toplevel.interface()`.

Example:
```luau
print(Toplevel.interface_name())
```

## Toplevel.close

Definition:
```luau
function Toplevel.close(group: number | string, button: () -> Widget?, key_probability: number?, timeout_ms: number?): boolean
```
Closes an interface and waits for it (`timeout_ms` per try, 1800 by default). With chance `key_probability` (default `Biometrics.ESCAPE`) it tries Escape first, if the client's "Esc to close" setting is on and Escape is still enabled. Otherwise, or if Escape fails, it clicks `button()` up to 3 times; fails if `button` returns `nil`. `true` at once when not open.

Example:
```luau
local Bankmain = require("@lib/main/interfaces/mainscreen/bankmain")

Toplevel.close(Bankmain.GROUP, Bankmain.close_button)
```

## Toplevel.escape_enabled

Definition:
```luau
function Toplevel.escape_enabled(): boolean
```
Whether Escape closing is still on. It is shared by `close` and `escape_clear`; after `ESCAPE_TRIES` failed presses on one interface it turns off for the rest of the run (a warning naming the interface is logged) and only the mouse is used.

Example:
```luau
print(Toplevel.escape_enabled())
```

## Toplevel.escape_clear

Definition:
```luau
function Toplevel.escape_clear(timeout_ms: number?): boolean
```
Closes whatever is open with Escape (`timeout_ms` per try, 600 by default), using the same tries and switch as `close`. `true` at once when nothing is open; `false` if it stayed open or Escape is off.

Example:
```luau
Toplevel.escape_clear()
```

## Toplevel.has_interface

Definition:
```luau
function Toplevel.has_interface(): boolean
```
Whether any window is open on the main screen.

Example:
```luau
print(Toplevel.has_interface())
```

## Toplevel.is_open

Definition:
```luau
function Toplevel.is_open(interface: number | string): boolean
```
Whether a window is open, by group or case-insensitive name.

Example:
```luau
print(Toplevel.is_open(12))
```

## Toplevel.viewport

Definition:
```luau
function Toplevel.viewport(): Box?
```
The box the 3D world is drawn in; `nil` for an unknown layout.

Example:
```luau
local view = Toplevel.viewport()
```

## Toplevel.blockers

Definition:
```luau
function Toplevel.blockers(): { Box }?
```
`panel_blockers` plus the box of every open window: areas where a click would not reach the world.

Example:
```luau
print(#(Toplevel.blockers() or {}))
```

## Toplevel.is_visible

Definition:
```luau
function Toplevel.is_visible(p: Point, viewport: Box?, blockers: { Box }?): boolean
```
Whether `p` is inside the viewport and outside every blocker. Pass `viewport` and `blockers` to reuse them across many points.

Example:
```luau
print(Toplevel.is_visible({ x = 300, y = 200 }))
```

## Toplevel.visible_point

Definition:
```luau
function Toplevel.visible_point(area: Box): Point?
```
The visible point of a 7x7 grid over `area` closest to its centre, or `nil` if none is visible.

Example:
```luau
local Geometry = require("@lib/utils/math/geometry")

print(Toplevel.visible_point(Geometry.Box.new(100, 100, 300, 300)))
```

## Toplevel.reset_escape

Definition:
```luau
function Toplevel.reset_escape()
```
Turns Escape closing back on after it was switched off.

Example:
```luau
Toplevel.reset_escape()
```

## Toplevel.panel_blockers

Definition:
```luau
function Toplevel.panel_blockers(): { Box }?
```
The boxes of the layout's fixed panels over the 3D view (chat, side panels), without open windows. `nil` for an unknown layout.

Example:
```luau
print(#(Toplevel.panel_blockers() or {}))
```
