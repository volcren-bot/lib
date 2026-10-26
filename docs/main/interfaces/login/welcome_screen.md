# Main.Interfaces.Login.WelcomeScreen
The "Click here to play" lobby you land on after logging in, before entering the game.

## WelcomeScreen
Definition:
```luau
local WelcomeScreen: { ROOT_INTERFACE: number, GROUP: number, PLAY_BUTTON: number, ... }
```
The lobby itself. The constants are the interface ids of the screen and its play button.

Example:
```luau
local WelcomeScreen = require("../main/interfaces/login/welcome_screen")

print(WelcomeScreen.GROUP, WelcomeScreen.PLAY_BUTTON)
```

## WelcomeScreen.is_open
Definition:
```luau
function WelcomeScreen.is_open(state: ClientState): boolean
```
Checks if the lobby is showing, given the client state.

Example:
```luau
local Host = require("../host")
local WelcomeScreen = require("../main/interfaces/login/welcome_screen")

local state = Host.game_state()
if state then
	print("lobby open:", WelcomeScreen.is_open(state))
end
```

## WelcomeScreen.play_button
Definition:
```luau
function WelcomeScreen.play_button(): Widget?
```
Gets the lobby's play button.

Example:
```luau
local WelcomeScreen = require("../main/interfaces/login/welcome_screen")

local button = WelcomeScreen.play_button()
print(if button then "found the play button" else `not found`)
```

## WelcomeScreen.play
Definition:
```luau
function WelcomeScreen.play(): boolean
```
Clicks the lobby's play button. Returns `false` if the lobby isn't open.

Example:
```luau
local WelcomeScreen = require("../main/interfaces/login/welcome_screen")

print("clicked play:", WelcomeScreen.play())
```
