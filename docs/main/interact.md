# Main.Interact

Doing something to a thing on screen: move the mouse there, choose an option such as "Talk-to" or "Take", and wait until you've arrived.

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
How long (in milliseconds) to wait for an option to show up in the menu after hovering. While the player is walking, a spot in the game world (`Interact.with`'s `scene`) gets `WALK_HOVER_TIMEOUT` instead: the scene slides under the mouse, so an option that isn't there soon won't come. `SPAM_MAX` is the most extra clicks `Interact.spam_click` makes.

## Interact.wait_option

Definition:
```luau
function Interact.wait_option(option: string, target: Minimenu.Target?, timeout_ms: number?): number?
```
Waits for the menu to offer an option (for example `"Talk-to"`) and returns its position in the menu. Gives up with an error after `timeout_ms` (`HOVER_TIMEOUT` by default).

Example:
```luau
local Interact = require("@lib/main/interact")
local Mouse = require("@lib/utils/input/mouse")

Mouse.move({ x = 300, y = 200 })
print(Interact.wait_option("Walk here"))
```

## Interact.spam_click

Definition:
```luau
function Interact.spam_click(chance: number?, still: () -> boolean, button: Mouse.Button?)
```
Call it right after a click. With probability `chance` (never when `nil`) it clicks 1 to `SPAM_MAX` more times on the same spot, usually once, like a person who clicks twice by habit. Before each click it stops if the player is animating or `still` returns false, so the extra clicks can't land on whatever slid under the mouse. Nothing in the lib turns this on: a script asks for it with the `spam` argument of the clickbox functions, and can scale the chance by the `Biometrics.SPAM_CLICK` trait so each account has its own habit.

Don't use it where a second click would undo the first, such as a door right next to the player.

Example:
```luau
local Biometrics = require("@lib/main/antiban/biometrics")
local Interact = require("@lib/main/interact")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Mouse = require("@lib/utils/input/mouse")

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
Moves to a spot, picks the option and checks that the game really did what you asked. If the option is the top one it simply clicks, otherwise it opens the right-click menu and picks it. If the game did something else, you get `false`, a message and the entry it clicked, so you can try again. After a successful click that makes you walk, it waits until you arrive (`walk_timeout_ms` changes how long; `false` skips the wait, useful for options like "Follow"). When the option was the top one, `spam` is the chance of a few more clicks, see `Interact.spam_click`. Pass `scene` for a spot in the game world: while you walk the scene slides under the mouse, so the option gets only `WALK_HOVER_TIMEOUT` to show up instead of `HOVER_TIMEOUT`; an interface spot (an inventory slot, a button) always gets the full wait. Pass `menu` to pick the option from the right-click menu even when it is the top one: a model that moves (an NPC mid-attack) can leave the mouse between the look and the press, and a left click there does the option under it instead ("Walk here"), while an open menu stays put.

Example:
```luau
local Interact = require("@lib/main/interact")

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
local Interact = require("@lib/main/interact")

local handled, ok = Interact.open_menu({ "Talk-to" }, "Captain")
print(handled, ok)
```
