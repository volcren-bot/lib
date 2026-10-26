# Main.Interfaces.Login.LoginWorldSwitcher
Picking the world you log in to from the login screen's world list.

## LoginWorldSwitcher
Definition:
```luau
local LoginWorldSwitcher: { ... }
```
The world switcher of the login screen. Everything below needs you to be on the login screen.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

print("current world:", LoginWorldSwitcher.current())
```

## LoginWorldSwitcher.MEMBERS (and the other world types)
Definition:
```luau
LoginWorldSwitcher.MEMBERS: number
```
Flags describing a world, found in `world.types`. Besides `MEMBERS` there is `PVP`, `BOUNTY`,
`PVP_ARENA`, `SKILL_TOTAL`, `QUEST_SPEEDRUNNING`, `HIGH_RISK`, `LAST_MAN_STANDING`, `BETA_WORLD`,
`LEGACY_ONLY`, `EOC_ONLY`, `NOSAVE_MODE`, `TOURNAMENT_WORLD`, `FRESH_START_WORLD`, `DEADMAN` and
`SEASONAL`. Use `has_type` to test them.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

local world = LoginWorldSwitcher.world(301)
if world then
	print("members world:", LoginWorldSwitcher.has_type(world, LoginWorldSwitcher.MEMBERS))
end
```

## LoginWorldSwitcher.DANGEROUS
Definition:
```luau
LoginWorldSwitcher.DANGEROUS: number
```
All the world types that can put your account at risk (PvP, bounty, high risk, deadman, ...)
combined into one flag. `switch` refuses these worlds unless `allow_dangerous_worlds` is set.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

local world = LoginWorldSwitcher.world(301)
if world then
	print("dangerous:", LoginWorldSwitcher.has_type(world, LoginWorldSwitcher.DANGEROUS))
end
```

## LoginWorldSwitcher.allow_dangerous_worlds
Definition:
```luau
LoginWorldSwitcher.allow_dangerous_worlds: boolean
```
Set this to `true` to let `switch` pick dangerous worlds. It's `false` by default.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

LoginWorldSwitcher.allow_dangerous_worlds = true
print("switched:", LoginWorldSwitcher.switch(318))
```

## LoginWorldSwitcher.OFFLINE and LoginWorldSwitcher.FULL
Definition:
```luau
LoginWorldSwitcher.OFFLINE: number
LoginWorldSwitcher.FULL: number
```
What a world's player count is when it's offline, and the count above which it's full. Neither
can be picked; `is_available` checks both for you.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

print(LoginWorldSwitcher.OFFLINE, LoginWorldSwitcher.FULL)
```

## LoginWorldSwitcher.Layout
Definition:
```luau
export type Layout = {
	columns: number, rows: number,
	width: number, height: number,
	x_gap: number, y_gap: number,
	x: number, y: number,
}
```
How the world boxes are arranged on screen: the grid size, the size of a box, the gap between
boxes and where the grid starts. Returned by `layout`.

## LoginWorldSwitcher.WorldBox
Definition:
```luau
export type WorldBox = {
	index: number,
	slot: number,
	world: World,
	box: Box,
}
```
A world's box on screen. `index` is the world's place in `worlds()`, `slot` its place among the
boxes shown right now, and `box` where to click. Returned by `boxes` and `find`.

## LoginWorldSwitcher.state
Definition:
```luau
function LoginWorldSwitcher.state(): WorldSelect?
```
Gets everything the client knows about the world switcher right now (open or not, current
world, world list, scroll position, ...). Fails if you aren't on the login screen.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

local select = LoginWorldSwitcher.state()
if select then
	print("open:", select.open, "current:", select.current)
else
	print("couldn't read")
end
```

## LoginWorldSwitcher.is_open
Definition:
```luau
function LoginWorldSwitcher.is_open(): boolean
```
Checks if the world list is open.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

print("open:", LoginWorldSwitcher.is_open())
```

## LoginWorldSwitcher.wait_open
Definition:
```luau
function LoginWorldSwitcher.wait_open(timeout_ms: number?): boolean
```
Waits until the world list is open. Gives up after `timeout_ms` (5 seconds by default) and
returns `false`.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

print("opened in time:", LoginWorldSwitcher.wait_open(3000))
```

## LoginWorldSwitcher.current
Definition:
```luau
function LoginWorldSwitcher.current(): number?
```
Gets the world you're set to log in to, the number on the "World N" button.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

print("current world:", LoginWorldSwitcher.current())
```

## LoginWorldSwitcher.worlds
Definition:
```luau
function LoginWorldSwitcher.worlds(): { World }?
```
Gets every world, in the order the switcher lists them. The list is empty until you've opened
the switcher once.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

LoginWorldSwitcher.open()
local worlds = LoginWorldSwitcher.worlds()
print("worlds:", worlds and #worlds)
LoginWorldSwitcher.close()
```

## LoginWorldSwitcher.world
Definition:
```luau
function LoginWorldSwitcher.world(id: number): World?
```
Gets a world by its number, or `nil` if it isn't in the list.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

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
Checks if a world has any of the given type flags (`MEMBERS`, `PVP`, ...).

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

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
Checks if a world is one `switch` would refuse by default (PvP, bounty, deadman, ...).

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

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
Checks if a world can be joined, meaning it's neither offline nor full.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

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
Works out how `count` world boxes are arranged on screen. Returns `nil` if `count` is below 1.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

local layout = LoginWorldSwitcher.layout(150)
if layout then
	print(layout.columns, "columns of", layout.rows, "rows")
end
```

## LoginWorldSwitcher.Buttons
Definition:
```luau
export type Buttons = {
	world: Box,
	cancel: Box,
	left: Box?,
	right: Box?,
}
```
Where the switcher's buttons are: the "World N" button, the cancel button, and the scroll
arrows (only set when you can scroll that way). Returned by `buttons`.

## LoginWorldSwitcher.buttons
Definition:
```luau
function LoginWorldSwitcher.buttons(): Buttons?
```
Gets where every button of the switcher is on screen.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

local buttons = LoginWorldSwitcher.buttons()
if buttons then
	print("can scroll right:", buttons.right ~= nil)
else
	print("couldn't read")
end
```

## LoginWorldSwitcher.boxes
Definition:
```luau
function LoginWorldSwitcher.boxes(): { WorldBox }?
```
Gets the world boxes shown on screen right now. The switcher has to be open.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

LoginWorldSwitcher.open()
local shown = LoginWorldSwitcher.boxes()
if shown then
	for _, b in shown do
		print(b.slot, b.world.id, b.world.players)
	end
end
LoginWorldSwitcher.close()
```

## LoginWorldSwitcher.read
Definition:
```luau
function LoginWorldSwitcher.read(slot: number): number?
```
Gets the world number in a visible box, where slot 1 is the top left one.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

LoginWorldSwitcher.open()
print("top left world:", LoginWorldSwitcher.read(1))
LoginWorldSwitcher.close()
```

## LoginWorldSwitcher.open
Definition:
```luau
function LoginWorldSwitcher.open(): boolean
```
Opens the world list by clicking the "World N" button. Does nothing if it's already open.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

print("opened:", LoginWorldSwitcher.open())
```

## LoginWorldSwitcher.close
Definition:
```luau
function LoginWorldSwitcher.close(): boolean
```
Closes the world list without picking a world. Does nothing if it's already closed.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

print("closed:", LoginWorldSwitcher.close())
```

## LoginWorldSwitcher.previous_page
Definition:
```luau
function LoginWorldSwitcher.previous_page(): boolean
```
Scrolls the world list one column to the left. Returns `false` if it can't scroll that way.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

LoginWorldSwitcher.open()
print("scrolled:", LoginWorldSwitcher.previous_page())
LoginWorldSwitcher.close()
```

## LoginWorldSwitcher.next_page
Definition:
```luau
function LoginWorldSwitcher.next_page(): boolean
```
Scrolls the world list one column to the right. Returns `false` if it can't scroll that way.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

LoginWorldSwitcher.open()
print("scrolled:", LoginWorldSwitcher.next_page())
LoginWorldSwitcher.close()
```

## LoginWorldSwitcher.find
Definition:
```luau
function LoginWorldSwitcher.find(id: number): WorldBox | false | nil
```
Opens the switcher and scrolls until a world is on screen, then returns its box. Returns `false`
(and closes the switcher) if the world isn't in the list.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

local found = LoginWorldSwitcher.find(301)
if found then
	print("world 301 is at", found.box.x1, found.box.y1)
end
LoginWorldSwitcher.close()
```

## LoginWorldSwitcher.switch
Definition:
```luau
function LoginWorldSwitcher.switch(id: number): boolean
```
Switches to a world, opening the list and scrolling as needed. Refuses dangerous worlds (unless
`allow_dangerous_worlds` is set) and worlds that are offline or full.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

local switched = LoginWorldSwitcher.switch(301)
print(if switched then "now on world 301" else `couldn't switch`)
```

## LoginWorldSwitcher.switch_random
Definition:
```luau
function LoginWorldSwitcher.switch_random(ids: { number }): boolean
```
Makes sure you're on one of the given worlds, switching to a random one if you aren't. Tries up
to 5 times.

Example:
```luau
local LoginWorldSwitcher = require("../main/interfaces/login/login_world_switcher")

print("on a good world:", LoginWorldSwitcher.switch_random({ 301, 302, 303, 304 }))
```
