# Utils.Input.Keyboard

Key presses and typing with human-like timing: each key is held a random `press_min`..`press_max` ms and letters are spaced `interval_min()`..`interval_max()` ms apart. Async functions share the one input queue with [Mouse](mouse.md) (see [Async input](../../host.md#async-input)).

```luau
local Keyboard = require("@lib/utils/input/keyboard")
```

## Keyboard.keys

Definition:
```luau
Keyboard.keys: { [string]: number }
```
Frozen table of virtual key codes by name: `A`..`Z`, `NUM_0`..`NUM_9`, `NUMPAD_0`..`NUMPAD_9`, `F1`..`F24`, `LEFT`/`UP`/`RIGHT`/`DOWN`, `RETURN`, `ESCAPE`, `SPACE`, `SHIFT`, `CONTROL` and more.

Example:
```luau
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
`F1` to `F12`.

## Keyboard.MISC

Definition:
```luau
Keyboard.MISC: { number }
```
Harmless Ctrl, Space and Shift keys for `random_key`.

## Settings

Definition:
```luau
Keyboard.press_min = 30
Keyboard.press_max = 60
Keyboard.last_key = 0
```
Key hold range in ms; `last_key` is the last key pressed or typed (0 for a non-alphanumeric character).

## Keyboard.interval_min

Definition:
```luau
function Keyboard.interval_min(): number
```
Shortest pause between typed letters (`press_min + 10`).

Example:
```luau
print(Keyboard.interval_min())
```

## Keyboard.interval_max

Definition:
```luau
function Keyboard.interval_max(): number
```
Longest pause between typed letters (`press_max + 25`).

Example:
```luau
print(Keyboard.interval_max())
```

## Keyboard.key_down

Definition:
```luau
function Keyboard.key_down(key: number)
```
Presses and holds a key. Left and right variants of a modifier share one press.

Example:
```luau
Keyboard.key_down(Keyboard.keys.LEFT)
```

## Keyboard.key_up

Definition:
```luau
function Keyboard.key_up(key: number)
```
Releases a held key.

Example:
```luau
Keyboard.key_up(Keyboard.keys.LEFT)
```

## Keyboard.key_press

Definition:
```luau
function Keyboard.key_press(key: number)
```
Presses and releases a key after a random hold.

Example:
```luau
Keyboard.key_press(Keyboard.keys.RETURN)
```

## Keyboard.key_down_async

Definition:
```luau
function Keyboard.key_down_async(key: number)
```
Queues holding a key. Released when async input is cancelled (including by any blocking input or a minimenu read) or the script ends. Not tracked by `is_key_down`.

Example:
```luau
local Host = require("@lib/host")

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
Keyboard.key_up_async(Keyboard.keys.LEFT)
```

## Keyboard.key_press_async

Definition:
```luau
function Keyboard.key_press_async(key: number)
```
Queues down, random hold, up.

Example:
```luau
Keyboard.key_press_async(Keyboard.keys.RETURN)
```

## Keyboard.send_async

Definition:
```luau
function Keyboard.send_async(text: string, key_after: number?)
```
Queues `Keyboard.send`.

Example:
```luau
Keyboard.send_async("hello", Keyboard.keys.RETURN)
```

## Keyboard.busy

Definition:
```luau
function Keyboard.busy(): boolean
```
Whether async input (keyboard or mouse) is running or queued.

Example:
```luau
print(Keyboard.busy())
```

## Keyboard.wait

Definition:
```luau
function Keyboard.wait(): boolean
```
Waits for async input to finish; logs and returns false if one failed.

Example:
```luau
Keyboard.key_press_async(Keyboard.keys.RETURN)
Keyboard.wait()
```

## Keyboard.cancel

Definition:
```luau
function Keyboard.cancel()
```
Cancels async input, releasing what it holds and dropping the queue.

Example:
```luau
Keyboard.cancel()
```

## Keyboard.is_key_down

Definition:
```luau
function Keyboard.is_key_down(key: number): boolean
```
Whether the script holds the key via `Keyboard.key_down`.

Example:
```luau
print(Keyboard.is_key_down(Keyboard.keys.SHIFT))
```

## Keyboard.send

Definition:
```luau
function Keyboard.send(text: string, key_after: number?)
```
Types text letter by letter, then optionally presses `key_after` after a short pause. Errors if Shift, Ctrl or Alt is held.

Example:
```luau
Keyboard.send("hello world", Keyboard.keys.RETURN)
```

## Keyboard.random_key

Definition:
```luau
function Keyboard.random_key()
```
Presses a harmless key: 75% Left/Right/Up, 15% an F key, 10% a `MISC` key.

Example:
```luau
Keyboard.random_key()
```
