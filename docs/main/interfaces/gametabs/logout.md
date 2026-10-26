# Main.Interfaces.Gametabs.Logout

Logging out of the game, and (optionally) rating it before you leave. It also handles the world switcher that can be showing instead of the logout buttons.

```luau
local Logout = require("../main/interfaces/gametabs/logout")
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
The numbers of the interface pieces involved: the tab, its buttons, the five rating stars and the world switcher shown in its place.

## Logout.is_open

Definition:
```luau
function Logout.is_open(): boolean
```
Whether the logout tab is the open tab.

Example:
```luau
local Logout = require("../main/interfaces/gametabs/logout")

print("open:", Logout.is_open())
```

## Logout.shows_world_switcher

Definition:
```luau
function Logout.shows_world_switcher(): boolean
```
Whether the logout tab currently shows the world switcher instead of the logout buttons.

Example:
```luau
local Logout = require("../main/interfaces/gametabs/logout")

print("switcher showing:", Logout.shows_world_switcher())
```

## Logout.open

Definition:
```luau
function Logout.open(): boolean
```
Opens the logout tab, and closes the world switcher if it was showing.

Example:
```luau
local Logout = require("../main/interfaces/gametabs/logout")

print(Logout.open())
```

## Logout.buttons

Definition:
```luau
function Logout.buttons(): Buttons?
```
The buttons of the logout tab: the five rating stars (`ratings`), the world switcher button and the logout button.

Example:
```luau
local Logout = require("../main/interfaces/gametabs/logout")

Logout.open()
local buttons = Logout.buttons()
print(if buttons then `logout button at {buttons.logout.x}, {buttons.logout.y}` else "unavailable")
```

## Logout.rating

Definition:
```luau
function Logout.rating(): number?
```
The number of stars you gave this session (1 to 5), or 0 if you haven't rated.

Example:
```luau
local Logout = require("../main/interfaces/gametabs/logout")

print("rating:", Logout.rating())
```

## Logout.is_rated

Definition:
```luau
function Logout.is_rated(): boolean
```
Whether you already gave a rating this session.

Example:
```luau
local Logout = require("../main/interfaces/gametabs/logout")

print("rated:", Logout.is_rated())
```

## Logout.rate

Definition:
```luau
function Logout.rate(stars: number): boolean
```
Gives the game a rating from 1 to 5 stars. Does nothing if that's already your rating.

Example:
```luau
local Logout = require("../main/interfaces/gametabs/logout")

print(Logout.rate(5))
```

## Logout.logout_from_world_switcher

Definition:
```luau
function Logout.logout_from_world_switcher(attempts: number?, time_ms: number?): boolean
```
Logs out using the button at the bottom of the world switcher. It presses up to `attempts` times (5 by default) spread over `time_ms` (20 seconds by default). Returns `false` if the world switcher isn't showing.

Example:
```luau
local Logout = require("../main/interfaces/gametabs/logout")

print(Logout.logout_from_world_switcher())
```

## Logout.logout

Definition:
```luau
function Logout.logout(attempts: number?, time_ms: number?): boolean
```
Logs you out. It opens the logout tab, sometimes rates the game first (how often and how high depends on the account's [Biometrics](../../antiban/biometrics.md)), then presses the logout button until you're out. Returns `true` straight away if you're already logged out.

Example:
```luau
local Logout = require("../main/interfaces/gametabs/logout")

local ok = Logout.logout()
print(if ok then "logged out" else "unavailable")
```
