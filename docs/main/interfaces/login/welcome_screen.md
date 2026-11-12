# Main.Interfaces.Login.WelcomeScreen

The "Click here to play" lobby shown after logging in, before entering the game.

```luau
local WelcomeScreen = require("@lib/main/interfaces/login/welcome_screen")
local Host = require("@lib/host")
```

## Constants

Definition:
```luau
WelcomeScreen.ROOT_INTERFACE = 165
WelcomeScreen.GROUP = 378
WelcomeScreen.PLAY_BUTTON = 72
```
The lobby's root interface, its interface and the play button component.

## WelcomeScreen.is_open

Definition:
```luau
function WelcomeScreen.is_open(state: ClientState): boolean
```
Whether `state` is logged in with the lobby as root interface.

Example:
```luau
print(WelcomeScreen.is_open(Host.game_state()))
```

## WelcomeScreen.play_button

Definition:
```luau
function WelcomeScreen.play_button(): Widget?
```
The lobby's play button widget, or `nil`.

Example:
```luau
print(WelcomeScreen.play_button() ~= nil)
```

## WelcomeScreen.play

Definition:
```luau
function WelcomeScreen.play(): boolean
```
Clicks the play button without waiting for the game to load. `false` when the lobby isn't open or the button is missing.

Example:
```luau
print(WelcomeScreen.play())
```
