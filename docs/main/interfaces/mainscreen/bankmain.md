# Main.Interfaces.Mainscreen.Bankmain

The bank. It has every function of [Inv](../inv.md) already set up for the bank's contents, and can enter your bank PIN if the keypad is in the way.

```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")
```

## Constants

Definition:
```luau
Bankmain.CONTAINER = 95
Bankmain.GROUP = 12
```
The bank's container id and its interface group.

## Bankmain.pin

Definition:
```luau
Bankmain.pin: string?
```
Set this to your 4-digit bank PIN and `is_open` will type it for you whenever the PIN keypad shows up. Leave it `nil` to not enter anything.

Example:
```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

Bankmain.pin = "1234"
```

## Functions from Inv

`slots`, `items`, `indices_of`, `index_of`, `find`, `contains`, `contains_any`, `contains_all`, `count`, `count_ex` and `wait_count` work as described in [Inv](../inv.md), on the bank's contents.

## Bankmain.is_open

Definition:
```luau
function Bankmain.is_open(): boolean
```
Whether the bank window is open. If a PIN is set and the keypad is showing, it enters the PIN first.

Example:
```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

if Bankmain.is_open() then
	print("coins in the bank:", Bankmain.count_ex("Coins"))
end
```

## Bankmain.close_button

Definition:
```luau
function Bankmain.close_button(): Widget?
```
The bank's close button, or `nil` when the bank is closed or it isn't where the frame keeps it.

Example:
```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

print(Bankmain.close_button())
```

## Bankmain.close

Definition:
```luau
function Bankmain.close(key_probability: number?, timeout_ms: number?): boolean
```
Closes the bank, like `DepositBox.close`: Escape with the chance `key_probability` (by default the `Biometrics.ESCAPE` probability), then the close button, up to 3 times. See `Toplevel.close`.

Example:
```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

Bankmain.close()
```
