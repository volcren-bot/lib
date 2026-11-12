# Main.Interfaces.Login.TitleScreen

The login screens and where their buttons are drawn, computed from the client's login layout (`Host.game_state().login`) and its scale.

```luau
local TitleScreen = require("@lib/main/interfaces/login/titlescreen")
local Host = require("@lib/host")
local Mouse = require("@lib/utils/input/mouse")
```

## Constants

Definition:
```luau
TitleScreen.WELCOME = 0
TitleScreen.CREDENTIALS = 2
TitleScreen.INVALID_CREDENTIALS = 3
TitleScreen.ERROR = 9
TitleScreen.PLAY_NOW = 10
TitleScreen.SIGN_OUT = 11
TitleScreen.TERMS = 12
TitleScreen.DISCONNECTED = 24
TitleScreen.CONNECTION_ERROR = 39
```
The login screen ids (`login.screen`) with known buttons.

## Types

Definition:
```luau
export type Button = {
	name: string,
	label: string,
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	center_x: number,
	center_y: number,
}
```
A button: its key (`"play_now"`, `"try_again"`, ...), the text on it, and its corners and center in client pixels.

## TitleScreen.name

Definition:
```luau
function TitleScreen.name(screen: number): string?
```
The readable name of a screen id, or `nil` if unknown.

Example:
```luau
print(TitleScreen.name(TitleScreen.CREDENTIALS)) --> credentials
```

## TitleScreen.buttons

Definition:
```luau
function TitleScreen.buttons(login: LoginLayout): { [string]: Button }
```
Every button on the current screen by name. Empty for an unknown screen.

Example:
```luau
local login = Host.game_state().login
if login then
	for name, button in TitleScreen.buttons(login) do
		print(name, button.center_x, button.center_y)
	end
end
```

## TitleScreen.button

Definition:
```luau
function TitleScreen.button(login: LoginLayout, name: string): Button?
```
One button of the current screen by name, or `nil` if the screen has none.

Example:
```luau
local login = Host.game_state().login
local button = login and TitleScreen.button(login, "play_now")
if button then
	Mouse.click(button)
end
```
