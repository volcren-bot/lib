# Main.Interfaces.Login.Login

Logging in from the title screen through the lobby into the game. Reasons for failure are logged.

```luau
local Login = require("@lib/main/interfaces/login/login")
```

## Login.login

Definition:
```luau
function Login.login(): boolean
```
Clicks the current login screen's next button once: Play Now, or Try again after a disconnect, error or invalid credentials. `false` when not on the login screen, its layout is unknown, or the screen has no such button.

Example:
```luau
print(Login.login())
```

## Login.sign_in

Definition:
```luau
function Login.sign_in(timeout_ms: number?): boolean
```
Logs in fully from any point, including already in game: presses `Login.login` until logged in, clicks play on the lobby (waiting up to 8 seconds for it), then skips the recommend survey if it shows within 2 seconds. `false` on invalid credentials or when `timeout_ms` (default 60000, covering the whole process) runs out.

Example:
```luau
if not Login.sign_in() then
	print("login failed")
end
```
