# Main.Antiban.Biometrics

A consistent per-account personality (mouse speed, click timings, sleep schedule, habits), derived from the account name so the same account always behaves the same. The profile comes from the injector (`Host.biometrics_profile`). The loader's Breaks tab Auto values come from it.

```luau
local Biometrics = require("@lib/main/antiban/biometrics")
```

## Constants

Definition:

```luau
Biometrics.MULTIPLIER = 0
Biometrics.SLEEP_H = 1
Biometrics.SLEEP_M = 2
Biometrics.SLEEP_S = 3
Biometrics.SLEEP_LENGTH = 4
Biometrics.BREAKS = 5
Biometrics.MIN_CLICKTIME = 6
Biometrics.MAX_CLICKTIME = 7
Biometrics.MOUSE_SPEED = 8
Biometrics.MOUSE_GRAVITY = 9
Biometrics.MOUSE_WIND = 10
Biometrics.FKEYS = 11
Biometrics.ESCAPE = 12
Biometrics.CHAT_KEYBOARD = 13
Biometrics.CHOOSEOPTION = 14
Biometrics.SPAM_CLICK = 15
Biometrics.PATTERN = 16
Biometrics.BANK_CONSUME = 17
Biometrics.RATING = 18
Biometrics.LIKES = 19
Biometrics.DISLIKES = 20
```

Trait indices (`Biometric`) for `get_biometric`, `get_probability` and `biometric_boolean`. Each trait is 0 to 255.

Example:

```luau
print(Biometrics.get_biometric(Biometrics.MOUSE_SPEED))
```

## Biometrics.murmur2a

Definition:

```luau
function Biometrics.murmur2a(text: string, seed: number?): number
```

Deterministic MurmurHash2A of `text` (via `Host.murmur2a`).

Example:

```luau
print(Biometrics.murmur2a("hello", 0))
```

## Biometrics.hash_string

Definition:

```luau
function Biometrics.hash_string(text: string): number
```

`murmur2a` with seed 0.

Example:

```luau
print(Biometrics.hash_string("my account"))
```

## Biometrics.setup

Definition:

```luau
function Biometrics.setup(username: string?)
```

Builds the personality for `username` and applies its `Mouse.speed`, `gravity`, `wind`, `press_min` and `press_max`. `nil` or `""` clears it.

Example:

```luau
Biometrics.setup("my account")
```

## Biometrics.clean_name

Definition:

```luau
function Biometrics.clean_name(name: string): string
```

Normalises a display name: non-breaking spaces and underscores become spaces, ends are trimmed, and it is lowercased.

Example:

```luau
print(Biometrics.clean_name("  My_Account ")) -- "my account"
```

## Biometrics.setup_player

Definition:

```luau
function Biometrics.setup_player(): boolean
```

`setup` with the logged-in character's cleaned name. Returns false if the name is unknown or empty.

Example:

```luau
Biometrics.setup_player()
```

## Biometrics.seed

Definition:

```luau
function Biometrics.seed(): string?
```

The name the current personality came from, or nil.

Example:

```luau
print(Biometrics.seed())
```

## Biometrics.hash

Definition:

```luau
function Biometrics.hash(): { number }
```

The 21 raw trait bytes. Without `setup`, creates a random profile for this run (and applies its mouse settings).

Example:

```luau
print(#Biometrics.hash())
```

## Biometrics.get_biometric

Definition:

```luau
function Biometrics.get_biometric(biometric: Biometric): number
```

One trait, 0 to 255.

Example:

```luau
print(Biometrics.get_biometric(Biometrics.MOUSE_SPEED))
```

## Biometrics.get_probability

Definition:

```luau
function Biometrics.get_probability(biometric: Biometric): number
```

One trait scaled to 0 to 1.

Example:

```luau
print(Biometrics.get_probability(Biometrics.SPAM_CLICK))
```

## Biometrics.random_double

Definition:

```luau
function Biometrics.random_double(input: number): number
```

Gaussian around `input` with std `input * MULTIPLIER` probability. Unbounded.

Example:

```luau
print(Biometrics.random_double(100))
```

## Biometrics.random_integer

Definition:

```luau
function Biometrics.random_integer(input: number): number
```

`random_double`, rounded.

Example:

```luau
print(Biometrics.random_integer(500))
```

## Biometrics.random_mode_double

Definition:

```luau
function Biometrics.random_mode_double(input: number, minimum: number, maximum: number): number
```

Like `random_double` with mode `input`, clamped to `minimum..maximum`.

Example:

```luau
print(Biometrics.random_mode_double(300, 100, 600))
```

## Biometrics.random_mode_integer

Definition:

```luau
function Biometrics.random_mode_integer(input: number, minimum: number, maximum: number): number
```

`random_mode_double`, rounded.

Example:

```luau
print(Biometrics.random_mode_integer(300, 100, 600))
```

## Biometrics.random_boolean

Definition:

```luau
function Biometrics.random_boolean(probability: number?): boolean
```

True with roughly `probability` (default 0.5), jittered by `random_double`.

Example:

```luau
if Biometrics.random_boolean(0.1) then
	print("rare")
end
```

## Biometrics.biometric_boolean

Definition:

```luau
function Biometrics.biometric_boolean(biometric: Biometric): boolean
```

True with the trait's probability.

Example:

```luau
print(Biometrics.biometric_boolean(Biometrics.SPAM_CLICK))
```

## Biometrics.sleep_hour

Definition:

```luau
function Biometrics.sleep_hour(): string
```

This personality's bedtime as "HH:MM:SS", between 23:00 and 03:00.

Example:

```luau
print(Biometrics.sleep_hour())
```

## Biometrics.sleep_length

Definition:

```luau
function Biometrics.sleep_length(): number
```

Hours of sleep, 6 to 10, two decimals.

Example:

```luau
print(Biometrics.sleep_length())
```

## Biometrics.sleep

Definition:

```luau
function Biometrics.sleep(minimum: number, maximum: number?, dir: Random.Dir?)
```

Blocks a human-like time in ms: about `minimum` alone, or between the two biased by `dir` (default `"mean"`).

Example:

```luau
Biometrics.sleep(200, 600)
```

## Biometrics.sleep_async

Definition:

```luau
function Biometrics.sleep_async(minimum: number, maximum: number?, dir: Random.Dir?)
```

Like `sleep`, but queues the wait behind async input and returns at once. Blocking input cancels what is still queued.

Example:

```luau
Mouse.click_async()
Biometrics.sleep_async(200, 600)
Mouse.click_async()
```

## Biometrics.click

Definition:

```luau
function Biometrics.click(button: Mouse.Button?, clicks: number?, probability: number?)
```

Clicks at the mouse position; with chance `probability` (default 0.08) adds 1 to `clicks` (default 3) extra clicks within 5 px, like a habitual double-clicker.

Example:

```luau
Biometrics.click()
```
