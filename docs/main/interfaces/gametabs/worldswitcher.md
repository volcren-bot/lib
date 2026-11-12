# Main.Interfaces.Gametabs.Worldswitcher

In-game world hopping through the world switcher panel in the logout tab: read the list, scroll to a world and hop.

```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")
```

A `Row` has `world`, `players`, `activity`, `types` (type flags, see `LoginWorldSwitcher`), `members`, `available` (not greyed out and total level high enough; the current world always counts), `visible` (fully inside the scrolled list) and `box` (screen area).

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
WorldSwitcher.CONFIRM_GROUP = 193
WorldSwitcher.CONFIRM_TEXT = 2
WorldSwitcher.CONFIRM_BUTTONS = 0
```
Panel components, the sort-order varp, the free/members/unavailable text colours, and the confirm/warning box shown before some hops.

## Settings

Definition:
```luau
WorldSwitcher.UNSAFE_TYPES = LoginWorldSwitcher.DANGEROUS
WorldSwitcher.UNSAFE_ACTIVITIES = { "pvp", "wilderness", "clan wars", "last man standing", "lms" }
WorldSwitcher.cooldown_ms = 7000
```
- `UNSAFE_TYPES`: type flags that make a world dangerous.
- `UNSAFE_ACTIVITIES`: lowercase activity substrings for PvP worlds the server doesn't flag.
- `cooldown_ms`: wait after a hop that never started (such as in combat) before another is allowed.

## WorldSwitcher.is_open

Definition:
```luau
function WorldSwitcher.is_open(): boolean
```
Whether the switcher shows in the logout tab.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

print(WorldSwitcher.is_open())
```

## WorldSwitcher.current

Definition:
```luau
function WorldSwitcher.current(): number?
```
The current world, from the client or else the panel title.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

print(WorldSwitcher.current())
```

## WorldSwitcher.rows

Definition:
```luau
function WorldSwitcher.rows(safe: boolean?): { Row }?
```
Every listed world top to bottom, scrolled out of view or not; nil when the switcher isn't open. With `safe` (default) worlds matching `UNSAFE_TYPES` or `UNSAFE_ACTIVITIES` are dropped; `false` keeps them. Blocked worlds are always dropped.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

for _, row in ipairs(WorldSwitcher.rows() or {}) do
	print(row.world, row.players, row.activity)
end
```

## WorldSwitcher.worlds

Definition:
```luau
function WorldSwitcher.worlds(safe: boolean?): { Row }?
```
`rows` limited to visible rows.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

print(#(WorldSwitcher.worlds() or {}))
```

## WorldSwitcher.find

Definition:
```luau
function WorldSwitcher.find(world: number): Row?
```
One world's row with no filtering; nil when not listed or the switcher is closed.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

local row = WorldSwitcher.find(301)
print(row and row.players)
```

## WorldSwitcher.is_loading

Definition:
```luau
function WorldSwitcher.is_loading(): boolean
```
Whether the open switcher's list is still empty.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

print(WorldSwitcher.is_loading())
```

## WorldSwitcher.wait_loading

Definition:
```luau
function WorldSwitcher.wait_loading(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (2400) for the list to load.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

WorldSwitcher.wait_loading(5000)
```

## WorldSwitcher.open

Definition:
```luau
function WorldSwitcher.open(wait_load: boolean?): boolean
```
Opens the logout tab and the switcher (press on the button, release over the panel title), then waits for the list unless `wait_load` is false. False when it doesn't appear, such as when the survey dialogue is in the way.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

WorldSwitcher.open()
```

## WorldSwitcher.close

Definition:
```luau
function WorldSwitcher.close(): boolean
```
Closes the switcher with its close button; true at once when not open.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

WorldSwitcher.close()
```

## WorldSwitcher.logout

Definition:
```luau
function WorldSwitcher.logout(attempts: number?, time_ms: number?): boolean
```
`Logout.logout_from_world_switcher` (see [Logout](logout.md)).

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

WorldSwitcher.logout()
```

## WorldSwitcher.buttons

Definition:
```luau
export type Buttons = { configure: Widget, close: Widget, logout: Widget, sort_world: Widget }
function WorldSwitcher.buttons(): Buttons?
```
The panel's main buttons; nil when any is missing.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

local buttons = WorldSwitcher.buttons()
print(buttons and buttons.close.x)
```

## WorldSwitcher.is_sorted

Definition:
```luau
function WorldSwitcher.is_sorted(): boolean
```
Whether the list is sorted by world number ascending (`SORT_VARP` is 0).

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

print(WorldSwitcher.is_sorted())
```

## WorldSwitcher.sort

Definition:
```luau
function WorldSwitcher.sort(): boolean
```
Clicks the "World" heading (up to twice) until sorted ascending; false when the switcher is closed.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

WorldSwitcher.sort()
```

## WorldSwitcher.cooldown

Definition:
```luau
function WorldSwitcher.cooldown(): number
```
Milliseconds left before another hop is allowed; 0 when ready.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

print(WorldSwitcher.cooldown())
```

## WorldSwitcher.wait_switch

Definition:
```luau
function WorldSwitcher.wait_switch(world: number, fail_cooldown: boolean?): boolean
```
After a hop click, waits up to 1.8 s for it to start and 10 s to arrive on `world`. When it never starts, starts the cooldown unless `fail_cooldown` is false.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

WorldSwitcher.wait_switch(301)
```

## WorldSwitcher.switch

Definition:
```luau
function WorldSwitcher.switch(world: number): boolean
```
Hops to `world`: opens and sorts the switcher, scrolls to the row, clicks it, confirms the "switch to World N?" box when asked, and waits to arrive. True at once when already there. False during cooldown, for a blocked world, a skill total world above your total, or a greyed-out row.

A refusal (a "World N is a..." warning, dismissed by ESC or Cancel as Biometrics picks, or the chat's "Please choose a different world.") blocks the world for the rest of the script. A hop that fails before starting (row not found, no "Switch" hover, never starts) is retried up to 3 times with a random pause, then the world is blocked too. A hop that started but didn't arrive in time is neither retried nor blocked.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

WorldSwitcher.switch(301)
```

## WorldSwitcher.is_blocked

Definition:
```luau
function WorldSwitcher.is_blocked(world: number): boolean
```
Whether `switch` blocked this world earlier in the script; the list is in memory only and can't be overridden.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

print(WorldSwitcher.is_blocked(569))
```

## WorldSwitcher.blocked_worlds

Definition:
```luau
function WorldSwitcher.blocked_worlds(): { number }
```
Every blocked world, sorted.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

print(table.concat(WorldSwitcher.blocked_worlds(), ", "))
```

## WorldSwitcher.next

Definition:
```luau
function WorldSwitcher.next(worlds: { number }, safe: boolean?): boolean
```
Hops to the world after the current one in `worlds` (wrapping, or the first when not on any). Blocked worlds and those above your total level are dropped first, and dangerous ones too unless `safe` is false. True when the only remaining world is the current one.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

WorldSwitcher.next({ 301, 302, 303 })
```

## WorldSwitcher.previous

Definition:
```luau
function WorldSwitcher.previous(worlds: { number }, safe: boolean?): boolean
```
`next`, going to the world before (wrapping, or the last).

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

WorldSwitcher.previous({ 301, 302, 303 })
```

## WorldSwitcher.random

Definition:
```luau
function WorldSwitcher.random(worlds: { number }, safe: boolean?): boolean
```
`next`, going to a random world other than the current one.

Example:
```luau
local WorldSwitcher = require("@lib/main/interfaces/gametabs/worldswitcher")

WorldSwitcher.random({ 301, 302, 303, 304 })
```
