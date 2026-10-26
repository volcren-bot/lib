# Main.Interfaces.Login.TitleScreen
The login screens (welcome, credentials, errors, ...) and where their buttons are drawn.

## TitleScreen
Definition:
```luau
local TitleScreen: { WELCOME: number, CREDENTIALS: number, PLAY_NOW: number, ... }
```
The title screen helper. The constants (`WELCOME`, `CREDENTIALS`, `INVALID_CREDENTIALS`, `ERROR`,
`PLAY_NOW`, `SIGN_OUT`, `TERMS`, `DISCONNECTED`, `CONNECTION_ERROR`) are the ids of the screens
the client can show.

Example:
```luau
local TitleScreen = require("../main/interfaces/login/titlescreen")

print(TitleScreen.name(TitleScreen.PLAY_NOW))
```

## TitleScreen.Button
Definition:
```luau
export type Button = {
	name: string,
	label: string,
	x1: number, y1: number, x2: number, y2: number,
	center_x: number, center_y: number,
}
```
A button on the current screen: its name, the text on it, and its corners and center in pixels.

## TitleScreen.name
Definition:
```luau
function TitleScreen.name(screen: number): string?
```
Gets the readable name of a screen id, or `nil` if it isn't one we know.

Example:
```luau
local TitleScreen = require("../main/interfaces/login/titlescreen")

print(TitleScreen.name(TitleScreen.CREDENTIALS)) -- credentials
```

## TitleScreen.buttons
Definition:
```luau
function TitleScreen.buttons(login: LoginLayout): { [string]: Button }
```
Gets every button on the screen you're on, by name. Empty if the screen isn't one we know.

Example:
```luau
local Host = require("../host")
local TitleScreen = require("../main/interfaces/login/titlescreen")

local state = Host.game_state()
if state and state.login then
	for name, button in TitleScreen.buttons(state.login) do
		print(name, button.label, button.center_x, button.center_y)
	end
end
```

## TitleScreen.button
Definition:
```luau
function TitleScreen.button(login: LoginLayout, name: string): Button?
```
Gets one button of the screen you're on by name, or `nil` if it has no such button.

Example:
```luau
local Host = require("../host")
local TitleScreen = require("../main/interfaces/login/titlescreen")
local Mouse = require("../utils/input/mouse")

local state = Host.game_state()
local button = state and state.login and TitleScreen.button(state.login, "play_now")
if button then
	Mouse.click(button)
end
```
