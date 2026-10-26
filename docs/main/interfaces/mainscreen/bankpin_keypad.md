# Main.Interfaces.Mainscreen.BankpinKeypad

The bank PIN keypad (213) that opens over the game screen before the bank does. The digits are shuffled, so they are read
from the buttons' own text components, which keep their digit even while the mouse hides it.

Functions that act return `false` if the keypad isn't open and `nil` if something went wrong.

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

## BankpinKeypad.wait_open
Definition:
```luau
function BankpinKeypad.wait_open(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (600 by default) for the keypad to open.

## BankpinKeypad.buttons
Definition:
```luau
function BankpinKeypad.buttons(): { [string]: Widget }?
```
The digit buttons by the digit ("0" to "9") they show right now. Missing digits mean the keypad is
still loading (see `is_loading`). An empty table when the keypad isn't open.

## BankpinKeypad.is_loading
Definition:
```luau
function BankpinKeypad.is_loading(): boolean
```
True while the keypad is open but its buttons don't show all ten digits yet: it starts that way
and clears them again after every digit entered.

## BankpinKeypad.wait_loading
Definition:
```luau
function BankpinKeypad.wait_loading(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (600 by default) for the buttons to finish loading. True once they show
every digit.

## BankpinKeypad.digit_index
Definition:
```luau
function BankpinKeypad.digit_index(): number?
```
Which digit of the PIN (1 to 4) the keypad asks for next, read from its "click the FIRST digit"
line. 0 when it isn't asking for one (closed, or between digits).

## BankpinKeypad.find_digit
Definition:
```luau
function BankpinKeypad.find_digit(digit: string | number): Widget?
```
The button showing `digit` right now, or nil if no button shows it (closed or loading).

## BankpinKeypad.click_digit
Definition:
```luau
function BankpinKeypad.click_digit(digit: string | number): boolean
```
Moves to the button showing `digit` and clicks it once the client's top menu entry is that button.

## BankpinKeypad.enter
Definition:
```luau
function BankpinKeypad.enter(pin: string, attempts: number?): boolean
```
Enters the 4 digit `pin`, one button at a time, picking up from whichever digit the keypad asks
for. A "try again" message is continued and the PIN entered again,
a "forgotten your PIN" message is waited out (up to 20 seconds) before trying again, and "entered
your PIN incorrectly several times" gives up. Up to `attempts` (3 by default) tries. True once the
keypad is gone with none of those messages showing.

Example:
```luau
local BankpinKeypad = require("../main/interfaces/mainscreen/bankpin_keypad")

if BankpinKeypad.is_open() then
	print("entered:", BankpinKeypad.enter("1234"))
end
```
