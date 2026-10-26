# Utils.Input.Keyboard

Pressing keys and typing text with human-like timing: every key is held for a slightly different time and there is a natural pause between letters.

```luau
local Keyboard = require("../utils/input/keyboard")
```

## Keyboard.keys

Definition:
```luau
Keyboard.keys: { [string]: number }
```
A table of key codes by name, such as `keys.A`, `keys.RETURN`, `keys.ESCAPE`, `keys.SPACE`, `keys.F1` to `keys.F24`, the arrows (`keys.LEFT`, `keys.UP`, `keys.RIGHT`, `keys.DOWN`), digits (`keys.NUM_0` to `keys.NUM_9`) and the numeric keypad (`keys.NUMPAD_0` to `keys.NUMPAD_9`). It can't be changed.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")

Keyboard.key_press(Keyboard.keys.ESCAPE)
```

## Keyboard.ARROWS

Definition:
```luau
Keyboard.ARROWS: { number }
```
The four arrow keys.

## Keyboard.FKEYS

Definition:
```luau
Keyboard.FKEYS: { number }
```
The keys `F1` to `F12`.

## Keyboard.MISC

Definition:
```luau
Keyboard.MISC: { number }
```
A few harmless extra keys (Ctrl, Space, Shift) used for random key presses.

## Settings

Definition:
```luau
Keyboard.press_min = 30
Keyboard.press_max = 60
```
The shortest and longest time (in milliseconds) a key is held down.

## Keyboard.interval_min

Definition:
```luau
function Keyboard.interval_min(): number
```
The shortest pause between two typed letters, in milliseconds.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")

print(Keyboard.interval_min())
```

## Keyboard.interval_max

Definition:
```luau
function Keyboard.interval_max(): number
```
The longest pause between two typed letters, in milliseconds.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")

print(Keyboard.interval_max())
```

## Keyboard.key_down

Definition:
```luau
function Keyboard.key_down(key: number)
```
Presses a key and keeps it held until you call `key_up`.

Example:
```luau
local Host = require("../host")
local Keyboard = require("../utils/input/keyboard")

Keyboard.key_down(Keyboard.keys.LEFT)
Host.sleep(500)
Keyboard.key_up(Keyboard.keys.LEFT)
```

## Keyboard.key_up

Definition:
```luau
function Keyboard.key_up(key: number)
```
Releases a key that is being held.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")

Keyboard.key_up(Keyboard.keys.LEFT)
```

## Keyboard.key_press

Definition:
```luau
function Keyboard.key_press(key: number)
```
Presses a key and releases it after a short, slightly random time.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")

Keyboard.key_press(Keyboard.keys.RETURN)
```

## Keyboard.key_down_async

Definition:
```luau
function Keyboard.key_down_async(key: number)
```
Queues pressing a key and keeping it held, and returns at once. A key held this way is released when the input is cancelled (`Keyboard.cancel`, any blocking input such as `Keyboard.key_press` or `Mouse.click`, a minimenu read) or the script ends, even in the middle of a pause or a mouse move. It doesn't change what `Keyboard.is_key_down` reports.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")
local Host = require("../host")

Keyboard.key_down_async(Keyboard.keys.LEFT)
Host.sleep_async(300)
Keyboard.key_up_async(Keyboard.keys.LEFT)
```

## Keyboard.key_up_async

Definition:
```luau
function Keyboard.key_up_async(key: number)
```
Queues releasing a key.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")

Keyboard.key_up_async(Keyboard.keys.LEFT)
```

## Keyboard.key_press_async

Definition:
```luau
function Keyboard.key_press_async(key: number)
```
Queues a key press: down, a short random pause, up. Cancelling during the pause still releases the key.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")

Keyboard.key_press_async(Keyboard.keys.RETURN)
```

## Keyboard.send_async

Definition:
```luau
function Keyboard.send_async(text: string, key_after: number?)
```
Queues typing text, like `Keyboard.send`, and returns at once.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")

Keyboard.send_async("hello", Keyboard.keys.RETURN)
Keyboard.wait()
```

## Keyboard.busy

Definition:
```luau
function Keyboard.busy(): boolean
```
Whether async input (keyboard or mouse; they share one queue) is still running or queued.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")

Keyboard.key_press_async(Keyboard.keys.RETURN)
print(Keyboard.busy())
```

## Keyboard.wait

Definition:
```luau
function Keyboard.wait(): boolean
```
Waits for async input to finish. Returns `false`, after printing the reason, if one failed.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")

Keyboard.key_press_async(Keyboard.keys.RETURN)
Keyboard.wait()
```

## Keyboard.cancel

Definition:
```luau
function Keyboard.cancel()
```
Stops async input, releases the keys and buttons it holds, and drops what was queued.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")

Keyboard.key_down_async(Keyboard.keys.LEFT)
Keyboard.cancel()
```

## Keyboard.is_key_down

Definition:
```luau
function Keyboard.is_key_down(key: number): boolean
```
Whether the script is currently holding that key.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")

Keyboard.key_down(Keyboard.keys.SHIFT)
print(Keyboard.is_key_down(Keyboard.keys.SHIFT)) -- true
Keyboard.key_up(Keyboard.keys.SHIFT)
```

## Keyboard.send

Definition:
```luau
function Keyboard.send(text: string, key_after: number?)
```
Types a piece of text one letter at a time, then optionally presses one more key (for example Enter). Release Shift, Ctrl and Alt first or it stops with an error.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")

Keyboard.send("hello world", Keyboard.keys.RETURN)
```

## Keyboard.random_key

Definition:
```luau
function Keyboard.random_key()
```
Presses a random harmless key, most often an arrow key. A small thing a real person does while idle.

Example:
```luau
local Keyboard = require("../utils/input/keyboard")

Keyboard.random_key()
```
