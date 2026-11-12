# Main.Interfaces.Mainscreen.BankpinKeypad

The bank PIN keypad (group 213) that opens before the bank. Its digits are shuffled and the injector enters the PIN, so scripts only check whether it is open and call `enter`.

```luau
local BankpinKeypad = require("@lib/main/interfaces/mainscreen/bankpin_keypad")
```

## BankpinKeypad
Definition:
```luau
local BankpinKeypad: { GROUP: number, TITLE: number, ENTERED: { number }, INSTRUCTION: number, PROMPT: number, EXIT: number, FORGOT: number, BUTTONS: { number } }
```
Widget ids: `GROUP` 213, `ENTERED` the four entered-digit boxes, `PROMPT` the "First click the FIRST digit." line, `EXIT`/`FORGOT` the "Exit" and "I don't know it." buttons, `BUTTONS` the ten digit buttons in screen order (digits shuffled).

## BankpinKeypad.is_open
Definition:
```luau
function BankpinKeypad.is_open(): boolean
```
Whether the keypad is open.

## BankpinKeypad.enter
Definition:
```luau
function BankpinKeypad.enter(): string
```
Enters the logged-in account's PIN, saved on the loader's Accounts page. The injector does the lookup, mouse moves and clicks, so the PIN never reaches the script. It retries on "try again", waits out "forgotten your PIN" (up to 20 s) and stops on "entered incorrectly several times"; at most 3 tries.

Returns `"entered"`, `"closed"` (keypad not open), `"no_pin"` (none saved, or not started by the loader), `"unavailable"` (account name unknown or accounts unreadable), `"locked"`, `"wrong"` (every try said "try again") or `"failed"` (buttons never loaded, a click failed, or the keypad didn't reopen).

Example:
```luau
if BankpinKeypad.is_open() then
	print("bank PIN:", BankpinKeypad.enter())
end
```
