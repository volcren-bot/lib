# Main.GameState

Readable names for the numbers the client uses to say what it is doing (on the login screen, loading, logged in...).

```luau
local GameState = require("../main/game_state")
```

## Constants

Definition:
```luau
GameState.STARTING = 0
GameState.LOGIN_SCREEN = 10
GameState.LOGIN_SCREEN_AUTHENTICATOR = 11
GameState.LOGGING_IN = 20
GameState.LOADING = 25
GameState.LOGGED_IN = 30
GameState.CONNECTION_LOST = 40
GameState.HOPPING = 45
GameState.FADE_GROUP = 174
```
Compare these against `game_state().game_state` instead of remembering the raw numbers.

## GameState.name

Definition:
```luau
function GameState.name(value: number): string?
```
Turns a state number into a short readable name such as `"logged in"`. Returns `nil` for numbers it does not know.

Example:
```luau
local Host = require("../host")
local GameState = require("../main/game_state")

local state = Host.game_state()
if state and state.game_state then
	print(GameState.name(state.game_state))
	print("in game:", state.game_state == GameState.LOGGED_IN)
end
```

## GameState.fading

Definition:
```luau
function GameState.fading(): boolean
```
Whether the client's full-screen black overlay is up. It shows while the client changes scene (leaving a minigame, for one), and the game still reports the old scene until it's gone. Clicks made then do nothing or repeat the last action, so wait for it to clear. `GameState.FADE_GROUP` is the interface group it lives in.

Example:
```luau
local Host = require("../host")
local GameState = require("../main/game_state")

-- after clicking "Leave": wait for the screen to go black and come back
if GameState.fading() then
	Host.sleep(200)
end
```
