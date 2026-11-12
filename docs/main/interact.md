# Main.Interact

Interacting with something on screen: move the mouse, choose an option such as "Talk-to", verify the client did it, and wait to arrive.

```luau
local Interact = require("@lib/main/interact")
```

## Constants

Definition:
```luau
Interact.HOVER_TIMEOUT = 600
Interact.WALK_HOVER_TIMEOUT = 100
Interact.SPAM_MAX = 3
```
Milliseconds to wait for an option after hovering; the shorter wait for a scene spot while walking, since the scene slides under the mouse; most extra clicks `spam_click` makes.

## Interact.wait_option

Definition:
```luau
function Interact.wait_option(option: string, target: Minimenu.Target?, timeout_ms: number?): number?
```
Waits up to `timeout_ms` (default `HOVER_TIMEOUT`) for the menu to offer `option` and returns its index. Nil, logged, on timeout or when the menu can't be read.

Example:
```luau
Mouse.move({ x = 300, y = 200 })
print(Interact.wait_option("Walk here"))
```

## Interact.spam_click

Definition:
```luau
function Interact.spam_click(chance: number?, still: () -> boolean, button: Mouse.Button?)
```
Call right after a click. With probability `chance` (never when nil) clicks the same spot 1 to `SPAM_MAX` more times, usually once, stopping before a click if the player animates or `still` returns false. Off unless a script passes `spam`; scale it by `Biometrics.SPAM_CLICK` for a per-account habit. Avoid where a second click undoes the first.

Example:
```luau
Mouse.click()
Interact.spam_click(0.2 * Biometrics.get_probability(Biometrics.SPAM_CLICK), function(): boolean
	return Minimenu.find("Open") == 1
end)
```

## Interact.with

Definition:
```luau
function Interact.with(at: Target, option: string, target: Minimenu.Target?, walk_timeout_ms: (number | false)?, spam: number?, scene: boolean?, menu: boolean?): (boolean, MenuClick?)
```
Moves to `at` and left-clicks when `option` is the left-click option, otherwise picks it from the right-click menu, then waits for the walk (`walk_timeout_ms`, `false` skips it, e.g. "Follow"). On a misclick returns `false` and the entry the client actually did. `spam` applies only to left clicks (see `spam_click`). `scene` marks a world spot so a walking player gets `WALK_HOVER_TIMEOUT`; `menu` forces the right-click menu, safer on moving models.

Example:
```luau
local ok = Interact.with({ x1 = 300, y1 = 200, x2 = 340, y2 = 240 }, "Walk here")
```

## Interact.open_menu

Definition:
```luau
function Interact.open_menu(options: { string }, target: Minimenu.Target?, walk_timeout_ms: (number | false)?): (boolean, boolean?)
```
Handles a minimenu left open before an interaction. If it offers one of `options` for `target`, clicks it and returns `true` plus whether it went through (walk wait as in `with`); otherwise closes it and returns `false`. False at once when no menu is open. The entity `interact` functions call this first.

Example:
```luau
local handled, ok = Interact.open_menu({ "Talk-to" }, "Captain")
```
