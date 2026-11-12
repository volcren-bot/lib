# Main.GameState

Names for the client's state numbers (login screen, loading, logged in...).

```luau
local GameState = require("@lib/main/game_state")
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
Compare against `Host.game_state().game_state`. `FADE_GROUP` is the interface group of the scene-change overlay.

## GameState.name

Definition:
```luau
function GameState.name(value: number): string?
```
A short name such as `"logged in"`, or `nil` for an unknown number.

Example:
```luau
local Host = require("@lib/host")
local GameState = require("@lib/main/game_state")

local state = Host.game_state()
if state and state.game_state then
	print(GameState.name(state.game_state))
end
```

## GameState.fading

Definition:
```luau
function GameState.fading(): boolean
```
Whether the full-screen black scene-change overlay is up. The game reports the old scene until it clears, and clicks meanwhile do nothing or repeat the last action, so wait it out.

Example:
```luau
local Host = require("@lib/host")
local GameState = require("@lib/main/game_state")

while GameState.fading() do
	Host.sleep(200)
end
```
