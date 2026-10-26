# Main.Interfaces.Gametabs.Worldswitcher

Changing worlds in game with the world switcher panel: open it, read the list of worlds, scroll to one and hop to it.

```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")
```

A row of the list has `world`, `players`, `activity`, `members` (members-only world), `available` (your account can use it), `visible` (fully shown in the scrolled list) and `box` (where it is on screen).

## Constants

Definition:
```luau
WorldSwitcher.GROUP = 69
WorldSwitcher.TITLE = 3
WorldSwitcher.CONFIGURE = 4
WorldSwitcher.CLOSE = 5
WorldSwitcher.SORT_FAVOURITE = 12
WorldSwitcher.SORT_WORLD = 13
WorldSwitcher.SORT_PLAYERS = 14
WorldSwitcher.SORT_LOCATION = 15
WorldSwitcher.SORT_ACTIVITY = 16
WorldSwitcher.LIST = 17
WorldSwitcher.ROWS = 18
WorldSwitcher.CELLS = 19
WorldSwitcher.SCROLLBAR = 20
WorldSwitcher.LOGOUT = 25
WorldSwitcher.SORT_VARP = 477
WorldSwitcher.FREE = 0xe0e0e0
WorldSwitcher.MEMBERS = 0xf0f000
WorldSwitcher.UNAVAILABLE = 0x7f7f7f
```
The interface piece numbers of the panel, the setting that remembers the sort order, and the colors used to tell free, members and unavailable worlds apart.

## Settings

Definition:
```luau
WorldSwitcher.cooldown_ms = 7000
```
After a hop that didn't start (for example because you're in combat), how long to wait before trying another hop.

## WorldSwitcher.is_open

Definition:
```luau
function WorldSwitcher.is_open(): boolean
```
Whether the world switcher is showing.

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

print("open:", WorldSwitcher.is_open())
```

## WorldSwitcher.current

Definition:
```luau
function WorldSwitcher.current(): number?
```
The number of the world you're on.

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

print("world", WorldSwitcher.current())
```

## WorldSwitcher.rows

Definition:
```luau
function WorldSwitcher.rows(): { Row }?
```
Every world in the list, top to bottom, including ones scrolled out of view. The switcher has to be open.

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

WorldSwitcher.open()
for _, row in ipairs(WorldSwitcher.rows() or {}) do
	print(row.world, row.players, row.activity)
end
```

## WorldSwitcher.worlds

Definition:
```luau
function WorldSwitcher.worlds(): { Row }?
```
Only the worlds you can currently see in the list (not scrolled out of view).

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

WorldSwitcher.open()
print("shown:", #(WorldSwitcher.worlds() or {}))
```

## WorldSwitcher.find

Definition:
```luau
function WorldSwitcher.find(world: number): Row?
```
The row of one world, shown or not. Returns `nil` if the world isn't in the list.

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

WorldSwitcher.open()
local row = WorldSwitcher.find(301)
print(row and row.players)
```

## WorldSwitcher.is_loading

Definition:
```luau
function WorldSwitcher.is_loading(): boolean
```
Whether the list is still empty because the worlds haven't loaded yet.

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

print("loading:", WorldSwitcher.is_loading())
```

## WorldSwitcher.wait_loading

Definition:
```luau
function WorldSwitcher.wait_loading(timeout_ms: number?): boolean
```
Waits until the list has loaded (up to 2.4 seconds by default). Returns whether it did.

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

print(WorldSwitcher.wait_loading(5000))
```

## WorldSwitcher.open

Definition:
```luau
function WorldSwitcher.open(wait_load: boolean?): boolean
```
Opens the world switcher from the logout tab and waits for the list to load (pass `false` to skip that wait). It fails if a dialogue, such as the survey, is in the way.

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

print(WorldSwitcher.open())
```

## WorldSwitcher.close

Definition:
```luau
function WorldSwitcher.close(): boolean
```
Closes the world switcher.

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

print(WorldSwitcher.close())
```

## WorldSwitcher.logout

Definition:
```luau
function WorldSwitcher.logout(attempts: number?, time_ms: number?): boolean
```
Logs out using the button at the bottom of the world switcher. See [Logout](logout.md).

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

WorldSwitcher.open()
print(WorldSwitcher.logout())
```

## WorldSwitcher.buttons

Definition:
```luau
function WorldSwitcher.buttons(): Buttons?
```
The main buttons of the panel: `configure`, `close`, `logout` and `sort_world`.

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

WorldSwitcher.open()
local buttons = WorldSwitcher.buttons()
print(buttons and buttons.close.x)
```

## WorldSwitcher.is_sorted

Definition:
```luau
function WorldSwitcher.is_sorted(): boolean
```
Whether the list is sorted by world number, lowest first.

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

print("sorted:", WorldSwitcher.is_sorted())
```

## WorldSwitcher.sort

Definition:
```luau
function WorldSwitcher.sort(): boolean
```
Clicks the "World" column heading until the list is sorted by world number, lowest first.

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

WorldSwitcher.open()
print(WorldSwitcher.sort())
```

## WorldSwitcher.cooldown

Definition:
```luau
function WorldSwitcher.cooldown(): number
```
How many milliseconds are left before another hop is allowed. 0 when you can hop.

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

print("wait", WorldSwitcher.cooldown(), "ms")
```

## WorldSwitcher.wait_switch

Definition:
```luau
function WorldSwitcher.wait_switch(world: number, fail_cooldown: boolean?): boolean
```
After clicking a world, waits for the hop to start and finish and for you to arrive on that world. If it never starts, the cooldown begins (unless `fail_cooldown` is `false`).

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

print(WorldSwitcher.wait_switch(301))
```

## WorldSwitcher.switch

Definition:
```luau
function WorldSwitcher.switch(world: number): boolean
```
Hops to a world. Opens the switcher, scrolls to the world, clicks it, confirms the "Are you sure you wish to switch to World N?" box that some worlds (activity worlds such as Tempoross's 422) ask first, and waits until you've arrived. Returns `true` at once if you're already there, and `false` while the cooldown runs.

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

local ok = WorldSwitcher.switch(301)
print(if ok then "hopped" else "unavailable")
```

## WorldSwitcher.next

Definition:
```luau
function WorldSwitcher.next(worlds: { number }): boolean
```
Hops to the world after the current one in your list (or the first one if you're not on any of them).

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

print(WorldSwitcher.next({ 301, 302, 303 }))
```

## WorldSwitcher.previous

Definition:
```luau
function WorldSwitcher.previous(worlds: { number }): boolean
```
Hops to the world before the current one in your list (or the last one).

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

print(WorldSwitcher.previous({ 301, 302, 303 }))
```

## WorldSwitcher.random

Definition:
```luau
function WorldSwitcher.random(worlds: { number }): boolean
```
Hops to a random world from your list, other than the current one.

Example:
```luau
local WorldSwitcher = require("../main/interfaces/gametabs/worldswitcher")

print(WorldSwitcher.random({ 301, 302, 303, 304 }))
```
