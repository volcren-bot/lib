# Main.Interfaces.Login.Login
Logging in from the title screen.

## Login
Definition:
```luau
local Login: { login: () -> boolean }
```
The login screen helper.

## Login.login
Definition:
```luau
function Login.login(): boolean
```
Presses the main button of the login screen you're on (Play Now, or Try again after an error).
Returns `false` if you aren't on the login screen or it has no such button.

Example:
```luau
local Login = require("../main/interfaces/login/login")

print("pressed:", Login.login())
```

## Login.sign_in
Definition:
```luau
function Login.sign_in(timeout_ms: number?): boolean
```
Does the whole login: presses the login screen's button until you're logged in, clicks "Click
here to play" on the lobby, then skips the recommend survey if it shows up. Safe to call from any
point of the process, including when you're already in game.

Returns `true` once you're in game with the survey out of the way, `false` if something went
wrong (invalid credentials, a timeout, an unreadable state; the reason is printed). `timeout_ms` (default 60000) bounds
the whole thing.

Example:
```luau
local Login = require("../main/interfaces/login/login")

local ok = Login.sign_in()
print(if ok then "in game" else `login failed`)
```
