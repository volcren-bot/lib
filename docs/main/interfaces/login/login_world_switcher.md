# Main.Interfaces.Login.LoginWorldSwitcher

The login screen's world list: reading worlds and switching the world you log in to. Everything returns `nil` or `false` off the login screen. Boxes are in client pixels, scaled with the login layout.

```luau
local LoginWorldSwitcher = require("@lib/main/interfaces/login/login_world_switcher")
```

## Constants

Definition:
```luau
LoginWorldSwitcher.MEMBERS = 0x1
LoginWorldSwitcher.PVP = 0x4
LoginWorldSwitcher.BOUNTY = 0x20
LoginWorldSwitcher.PVP_ARENA = 0x40
LoginWorldSwitcher.SKILL_TOTAL = 0x80
LoginWorldSwitcher.QUEST_SPEEDRUNNING = 0x100
LoginWorldSwitcher.HIGH_RISK = 0x400
LoginWorldSwitcher.LAST_MAN_STANDING = 0x4000
LoginWorldSwitcher.BETA_WORLD = 0x10000
LoginWorldSwitcher.LEGACY_ONLY = 0x400000
LoginWorldSwitcher.EOC_ONLY = 0x800000
LoginWorldSwitcher.NOSAVE_MODE = 0x2000000
LoginWorldSwitcher.TOURNAMENT_WORLD = 0x4000000
LoginWorldSwitcher.FRESH_START_WORLD = 0x8000000
LoginWorldSwitcher.DEADMAN = 0x20000000
LoginWorldSwitcher.SEASONAL = 0x40000000
LoginWorldSwitcher.DANGEROUS: number
LoginWorldSwitcher.OFFLINE = -1
LoginWorldSwitcher.FULL = 1980
```
World type flags for `world.types`, tested with `has_type`. `DANGEROUS` combines every flag except `MEMBERS`, `SKILL_TOTAL`, `LEGACY_ONLY` and `EOC_ONLY`. `OFFLINE` is an offline world's player count and `FULL` the count above which a world is full.

## Settings

Definition:
```luau
LoginWorldSwitcher.allow_dangerous_worlds = false
```
When `false`, `switch` refuses worlds with a `DANGEROUS` flag.

Example:
```luau
LoginWorldSwitcher.allow_dangerous_worlds = true
```

## Types

Definition:
```luau
export type Layout = {
	columns: number,
	rows: number,
	width: number,
	height: number,
	x_gap: number,
	y_gap: number,
	x: number,
	y: number,
}
export type WorldBox = {
	index: number,
	slot: number,
	world: World,
	box: Box,
}
export type Buttons = {
	world: Box,
	cancel: Box,
	left: Box?,
	right: Box?,
}
```
`Layout` is the world grid: size, box size, gaps and origin. `WorldBox.index` is the world's place in `worlds()` and `slot` its place among the boxes shown now. `Buttons` holds the "World N" button, cancel, and the scroll arrows, set only when that direction can scroll.

## LoginWorldSwitcher.state

Definition:
```luau
function LoginWorldSwitcher.state(): WorldSelect?
```
The client's world select state (open, current world, worlds, scroll offset, hovered box), or `nil` off the login screen.

Example:
```luau
local select = LoginWorldSwitcher.state()
print(select and select.open, select and select.current)
```

## LoginWorldSwitcher.is_open

Definition:
```luau
function LoginWorldSwitcher.is_open(): boolean
```
Whether the world list is open.

Example:
```luau
print("open:", LoginWorldSwitcher.is_open())
```

## LoginWorldSwitcher.wait_open

Definition:
```luau
function LoginWorldSwitcher.wait_open(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (default 5000) for the world list to open.

Example:
```luau
print(LoginWorldSwitcher.wait_open(3000))
```

## LoginWorldSwitcher.current

Definition:
```luau
function LoginWorldSwitcher.current(): number?
```
The world you'll log in to, shown on the "World N" button.

Example:
```luau
print(LoginWorldSwitcher.current())
```

## LoginWorldSwitcher.worlds

Definition:
```luau
function LoginWorldSwitcher.worlds(): { World }?
```
Every world in list order. Empty until the switcher has been opened once.

Example:
```luau
local worlds = LoginWorldSwitcher.worlds()
print(worlds and #worlds)
```

## LoginWorldSwitcher.world

Definition:
```luau
function LoginWorldSwitcher.world(id: number): World?
```
A world by number, or `nil` if it isn't listed.

Example:
```luau
local world = LoginWorldSwitcher.world(301)
if world then
	print(world.id, world.players, world.activity)
end
```

## LoginWorldSwitcher.has_type

Definition:
```luau
function LoginWorldSwitcher.has_type(world: World, types: number): boolean
```
Whether `world` has any of the flags in `types`.

Example:
```luau
local world = LoginWorldSwitcher.world(301)
if world then
	print("members:", LoginWorldSwitcher.has_type(world, LoginWorldSwitcher.MEMBERS))
end
```

## LoginWorldSwitcher.is_dangerous

Definition:
```luau
function LoginWorldSwitcher.is_dangerous(world: World): boolean
```
Whether `world` has a `DANGEROUS` flag.

Example:
```luau
local world = LoginWorldSwitcher.world(318)
if world then
	print("dangerous:", LoginWorldSwitcher.is_dangerous(world))
end
```

## LoginWorldSwitcher.is_available

Definition:
```luau
function LoginWorldSwitcher.is_available(world: World): boolean
```
Whether `world` is neither offline nor full.

Example:
```luau
local world = LoginWorldSwitcher.world(301)
if world then
	print("available:", LoginWorldSwitcher.is_available(world))
end
```

## LoginWorldSwitcher.layout

Definition:
```luau
function LoginWorldSwitcher.layout(count: number): Layout?
```
The grid the client uses for `count` worlds, or `nil` when `count` is below 1.

Example:
```luau
local layout = LoginWorldSwitcher.layout(150)
if layout then
	print(layout.columns, "columns of", layout.rows, "rows")
end
```

## LoginWorldSwitcher.buttons

Definition:
```luau
function LoginWorldSwitcher.buttons(): Buttons?
```
Where the switcher's buttons are.

Example:
```luau
local buttons = LoginWorldSwitcher.buttons()
print(buttons and buttons.right ~= nil)
```

## LoginWorldSwitcher.boxes

Definition:
```luau
function LoginWorldSwitcher.boxes(): { WorldBox }?
```
The world boxes shown now; `nil` when the list is closed.

Example:
```luau
for _, b in LoginWorldSwitcher.boxes() or {} do
	print(b.slot, b.world.id)
end
```

## LoginWorldSwitcher.read

Definition:
```luau
function LoginWorldSwitcher.read(slot: number): number?
```
The world in visible box `slot`, 1 being the top-left, filled column by column.

Example:
```luau
print(LoginWorldSwitcher.read(1))
```

## LoginWorldSwitcher.open

Definition:
```luau
function LoginWorldSwitcher.open(): boolean
```
Clicks the "World N" button if the list is closed and waits up to 5 seconds for it to open.

Example:
```luau
print(LoginWorldSwitcher.open())
```

## LoginWorldSwitcher.close

Definition:
```luau
function LoginWorldSwitcher.close(): boolean
```
Clicks cancel if the list is open and waits up to 1.5 seconds for it to close.

Example:
```luau
print(LoginWorldSwitcher.close())
```

## LoginWorldSwitcher.previous_page

Definition:
```luau
function LoginWorldSwitcher.previous_page(): boolean
```
Clicks the left arrow, waits for the list to scroll, then pauses 0.4 to 1.2 seconds. `false` when closed or already at the start.

Example:
```luau
print(LoginWorldSwitcher.previous_page())
```

## LoginWorldSwitcher.next_page

Definition:
```luau
function LoginWorldSwitcher.next_page(): boolean
```
Clicks the right arrow, waits for the list to scroll, then pauses 0.4 to 1.2 seconds. `false` when closed or already at the end.

Example:
```luau
print(LoginWorldSwitcher.next_page())
```

## LoginWorldSwitcher.find

Definition:
```luau
function LoginWorldSwitcher.find(id: number): WorldBox?
```
Opens the list and scrolls until world `id` is visible, then returns its box. `nil` on failure; when the world isn't listed it also closes the list.

Example:
```luau
local found = LoginWorldSwitcher.find(301)
print(found and found.box.x1, found and found.box.y1)
```

## LoginWorldSwitcher.switch

Definition:
```luau
function LoginWorldSwitcher.switch(id: number): boolean
```
Switches to world `id` via `find`, clicking its box only once the client reports it hovered, and waits up to 1.5 seconds for the list to close on it. `true` at once when already on it; `false` for dangerous worlds (unless `allow_dangerous_worlds`), unavailable worlds or failures.

Example:
```luau
print(LoginWorldSwitcher.switch(301))
```

## LoginWorldSwitcher.switch_random

Definition:
```luau
function LoginWorldSwitcher.switch_random(ids: { number }): boolean
```
`true` if already on one of `ids`, otherwise switches to a random one, up to 5 attempts. `false` for an empty list.

Example:
```luau
print(LoginWorldSwitcher.switch_random({ 301, 302, 303 }))
```
