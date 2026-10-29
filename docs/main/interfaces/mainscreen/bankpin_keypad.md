# Main.Interfaces.Mainscreen.BankpinKeypad

The bank PIN keypad (213) that opens over the game screen before the bank does. Its digits are shuffled, and entering the
PIN is done by the injector (see `enter`), so scripts only need to know whether the keypad is open.

## BankpinKeypad
Definition:
```luau
local BankpinKeypad: { GROUP: number, ... }
```
`BankpinKeypad.GROUP` is the keypad's interface id (213). `ENTERED` are the four boxes showing the
digits entered so far, `PROMPT` the "First click the FIRST digit." line, `EXIT` and `FORGOT` the
"Exit" and "I don't know it." buttons, and `BUTTONS` the ten digit buttons in screen order (the
digit each one shows is shuffled).

## BankpinKeypad.is_open
Definition:
```luau
function BankpinKeypad.is_open(): boolean
```
Checks if the keypad is open.

## BankpinKeypad.enter
Definition:
```luau
function BankpinKeypad.enter(): string
```
Enters the bank PIN of the logged in account on the open keypad. The injector hashes the account's name, asks the loader for the PIN saved under that hash (Accounts page), and does the whole job: it
finds each button, moves the mouse and clicks, so the PIN and the digits never reach the script. A "try again"
message is continued and the PIN entered again, a "forgotten your PIN" message is waited out (up to 20 seconds)
before trying again, and "entered your PIN incorrectly several times" gives up. Up to 3 tries.

Returns one of:
- `"entered"`: the keypad is gone with none of those messages showing.
- `"closed"`: the keypad isn't open.
- `"no_pin"`: no PIN is saved for the logged in account, or the script wasn't started by the loader.
- `"unavailable"`: the account's name isn't known, or the loader couldn't read its saved accounts.
- `"locked"`: the client says the PIN was entered incorrectly several times.
- `"wrong"`: every try ended in "try again".
- `"failed"`: the buttons never loaded, a digit couldn't be clicked, or the keypad didn't open again.

Example:
```luau
local BankpinKeypad = require("../main/interfaces/mainscreen/bankpin_keypad")

if BankpinKeypad.is_open() then
	print("bank PIN:", BankpinKeypad.enter())
end
```
