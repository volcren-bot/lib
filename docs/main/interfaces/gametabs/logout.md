# Main.Interfaces.Gametabs.Logout

Logging out, optionally rating the game first, including when the world switcher shows in place of the logout buttons.

```luau
local Logout = require("@lib/main/interfaces/gametabs/logout")
```

## Constants

Definition:
```luau
Logout.GROUP = 182
Logout.WORLD_SWITCHER = 3
Logout.LOGOUT = 8
Logout.RATINGS = 18
Logout.FIRST_STAR = 19
Logout.RATING_VARP = 1707
Logout.SWITCHER_GROUP = 69
Logout.SWITCHER_CLOSE = 5
Logout.SWITCHER_LOGOUT = 25
```
The tab and its buttons, the first of five rating stars, the rating varp, and the world switcher's group, close and logout buttons.

## Logout.is_open

Definition:
```luau
function Logout.is_open(): boolean
```
Whether the logout tab is the open side panel.

Example:
```luau
local Logout = require("@lib/main/interfaces/gametabs/logout")

print(Logout.is_open())
```

## Logout.shows_world_switcher

Definition:
```luau
function Logout.shows_world_switcher(): boolean
```
Whether the open logout tab shows the world switcher instead of its buttons.

Example:
```luau
local Logout = require("@lib/main/interfaces/gametabs/logout")

print(Logout.shows_world_switcher())
```

## Logout.open

Definition:
```luau
function Logout.open(): boolean
```
Opens the logout tab and closes the world switcher if it shows. False if it doesn't close within 1.2 s.

Example:
```luau
local Logout = require("@lib/main/interfaces/gametabs/logout")

Logout.open()
```

## Logout.buttons

Definition:
```luau
export type Buttons = { ratings: { Widget }, world_switcher: Widget, logout: Widget }
function Logout.buttons(): Buttons?
```
The five star widgets, the world switcher button and the logout button; nil when any is missing.

Example:
```luau
local Logout = require("@lib/main/interfaces/gametabs/logout")

local buttons = Logout.buttons()
print(buttons and buttons.logout.x)
```

## Logout.rating

Definition:
```luau
function Logout.rating(): number?
```
This session's rating, 1 to 5, or 0 when unrated; nil when unreadable.

Example:
```luau
local Logout = require("@lib/main/interfaces/gametabs/logout")

print(Logout.rating())
```

## Logout.is_rated

Definition:
```luau
function Logout.is_rated(): boolean
```
Whether a rating was given this session.

Example:
```luau
local Logout = require("@lib/main/interfaces/gametabs/logout")

print(Logout.is_rated())
```

## Logout.rate

Definition:
```luau
function Logout.rate(stars: number): boolean
```
Clicks the star for an integer rating 1 to 5 and waits for it to register. True at once when already that rating; false for an invalid value.

Example:
```luau
local Logout = require("@lib/main/interfaces/gametabs/logout")

Logout.rate(5)
```

## Logout.logout_from_world_switcher

Definition:
```luau
function Logout.logout_from_world_switcher(attempts: number?, time_ms: number?): boolean
```
Presses the world switcher's logout button up to `attempts` times (5) spread over `time_ms` (20000) with jitter, until logged out. False when the switcher isn't showing.

Example:
```luau
local Logout = require("@lib/main/interfaces/gametabs/logout")

Logout.logout_from_world_switcher()
```

## Logout.logout

Definition:
```luau
function Logout.logout(attempts: number?, time_ms: number?): boolean
```
Opens the tab, sometimes rates the game first (chance and stars from [Biometrics](../../antiban/biometrics.md)), then presses logout as `logout_from_world_switcher` does, using the switcher's button when it shows. True at once when already logged out.

Example:
```luau
local Logout = require("@lib/main/interfaces/gametabs/logout")

Logout.logout()
```
