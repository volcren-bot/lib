# Main.Interact

Doing something to a thing on screen: move the mouse there, choose an option such as "Talk-to" or "Take", and wait until you've arrived.

```luau
local Interact = require("../main/interact")
```

## Constants

Definition:
```luau
Interact.HOVER_TIMEOUT = 600
Interact.WALK_HOVER_TIMEOUT = 100
```
How long (in milliseconds) to wait for an option to show up in the menu after hovering. While the player is walking `WALK_HOVER_TIMEOUT` is used instead: the scene slides under the mouse, so an option that isn't there soon won't come.

## Interact.wait_option

Definition:
```luau
function Interact.wait_option(option: string, target: Minimenu.Target?, timeout_ms: number?): number?
```
Waits for the menu to offer an option (for example `"Talk-to"`) and returns its position in the menu. Gives up with an error after `timeout_ms` (`HOVER_TIMEOUT` by default).

Example:
```luau
local Interact = require("../main/interact")
local Mouse = require("../utils/input/mouse")

Mouse.move({ x = 300, y = 200 })
print(Interact.wait_option("Walk here"))
```

## Interact.with

Definition:
```luau
function Interact.with(at: Target, option: string, target: Minimenu.Target?, walk_timeout_ms: (number | false)?): (boolean?, string?, MenuClick?)
```
Moves to a spot, picks the option and checks that the game really did what you asked. If the option is the top one it simply clicks, otherwise it opens the right-click menu and picks it. If the game did something else, you get `false`, a message and the entry it clicked, so you can try again. After a successful click that makes you walk, it waits until you arrive (`walk_timeout_ms` changes how long; `false` skips the wait, useful for options like "Follow").

Example:
```luau
local Interact = require("../main/interact")

local ok = Interact.with({ x1 = 300, y1 = 200, x2 = 340, y2 = 240 }, "Walk here")
print(ok)
```

## Interact.open_menu

Definition:
```luau
function Interact.open_menu(options: { string }, target: Minimenu.Target?, walk_timeout_ms: (number | false)?): (boolean, boolean?)
```
Deals with a minimenu left open (after a misclick, say) before an interaction. If it has one of `options` for `target`, that row is clicked and you get `true` plus whether the interaction went through (the walk wait works as in `Interact.with`). Otherwise the menu is closed and you get `false`. The entity `interact` functions (`Npcs`, `Objects`, `Players`, `GroundItems`) call this first.

Example:
```luau
local Interact = require("../main/interact")

local handled, ok = Interact.open_menu({ "Talk-to" }, "Captain")
print(handled, ok)
```
