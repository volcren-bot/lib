# Main.Antiban.Biometrics

Gives each account its own consistent "personality" so a script doesn't behave identically for everyone: mouse speed, click timings, sleep schedule and how often it makes small human-like mistakes. The personality is generated from the account name, so the same account always behaves the same way.

```luau
local Biometrics = require("../main/antiban/biometrics")
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
The traits that make up a personality. Each one is a number between 0 and 255 that you read with `get_biometric` or `get_probability`.

## Biometrics.murmur2a

Definition:
```luau
function Biometrics.murmur2a(text: string, seed: number?): number
```
A fast text-scrambling function (a hash) that turns any text into a number. The same text and seed always give the same number.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

print(Biometrics.murmur2a("hello", 0))
```

## Biometrics.hash_string

Definition:
```luau
function Biometrics.hash_string(text: string): number
```
Same as `murmur2a` with the default seed.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

print(Biometrics.hash_string("my account"))
```

## Biometrics.setup

Definition:
```luau
function Biometrics.setup(username: string?)
```
Creates the personality for an account name and applies the matching mouse speed and click timing. Passing `nil` or an empty name forgets the current personality.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

Biometrics.setup("my account")
```

## Biometrics.clean_name

Definition:
```luau
function Biometrics.clean_name(name: string): string
```
Tidies a display name so the same account always gives the same text: special spaces and underscores become normal spaces, the ends are trimmed and everything is lowercase.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

print(Biometrics.clean_name("  My_Account ")) -- "my account"
```

## Biometrics.setup_player

Definition:
```luau
function Biometrics.setup_player(): boolean
```
Sets up the personality from the name of the character you are logged in as. Returns `true` when done.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

local ok = Biometrics.setup_player()
print(if ok then "personality ready" else `couldn't set up`)
```

## Biometrics.seed

Definition:
```luau
function Biometrics.seed(): string?
```
The account name the current personality was made from, or `nil` if none has been set up.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

Biometrics.setup("my account")
print(Biometrics.seed())
```

## Biometrics.hash

Definition:
```luau
function Biometrics.hash(): { number }
```
The raw list of numbers that makes up the personality. If none was set up, a random one is created for this run.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

print(#Biometrics.hash())
```

## Biometrics.get_biometric

Definition:
```luau
function Biometrics.get_biometric(biometric: Biometric): number
```
One trait of the personality as a number from 0 to 255.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

print(Biometrics.get_biometric(Biometrics.MOUSE_SPEED))
```

## Biometrics.get_probability

Definition:
```luau
function Biometrics.get_probability(biometric: Biometric): number
```
One trait as a number from 0 to 1.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

print(Biometrics.get_probability(Biometrics.SPAM_CLICK))
```

## Biometrics.random_double

Definition:
```luau
function Biometrics.random_double(input: number): number
```
Returns a number near `input`, with a little random variation. How much it varies depends on the personality.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

print(Biometrics.random_double(100))
```

## Biometrics.random_integer

Definition:
```luau
function Biometrics.random_integer(input: number): number
```
Like `random_double` but rounded to a whole number.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

print(Biometrics.random_integer(500))
```

## Biometrics.random_mode_double

Definition:
```luau
function Biometrics.random_mode_double(input: number, minimum: number, maximum: number): number
```
Like `random_double`, but the result always stays between `minimum` and `maximum`.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

print(Biometrics.random_mode_double(300, 100, 600))
```

## Biometrics.random_mode_integer

Definition:
```luau
function Biometrics.random_mode_integer(input: number, minimum: number, maximum: number): number
```
Like `random_mode_double` but rounded to a whole number.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

print(Biometrics.random_mode_integer(300, 100, 600))
```

## Biometrics.random_boolean

Definition:
```luau
function Biometrics.random_boolean(probability: number?): boolean
```
Randomly returns `true` or `false`. `probability` (0 to 1, default 0.5) is roughly how often `true` comes up, varying a little with the personality.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

if Biometrics.random_boolean(0.1) then
	print("1 in 10")
end
```

## Biometrics.biometric_boolean

Definition:
```luau
function Biometrics.biometric_boolean(biometric: Biometric): boolean
```
Randomly returns `true` or `false` where the chance of `true` is the strength of that trait for this personality. A person with a high `SPAM_CLICK` says `true` often.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

print(Biometrics.biometric_boolean(Biometrics.SPAM_CLICK))
```

## Biometrics.sleep_hour

Definition:
```luau
function Biometrics.sleep_hour(): string
```
The time of day (`"HH:MM:SS"`) this personality goes to sleep, somewhere between 23:00 and 03:00.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

print("goes to bed at", Biometrics.sleep_hour())
```

## Biometrics.sleep_length

Definition:
```luau
function Biometrics.sleep_length(): number
```
How many hours this personality sleeps, between 6 and 10.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

print("sleeps", Biometrics.sleep_length(), "hours")
```

## Biometrics.sleep

Definition:
```luau
function Biometrics.sleep(minimum: number, maximum: number?, dir: Random.Dir?)
```
Waits for a human-like amount of time in milliseconds. With one number it waits about that long; with two it waits somewhere between them.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

Biometrics.sleep(200, 600)
```

## Biometrics.sleep_async

Definition:
```luau
function Biometrics.sleep_async(minimum: number, maximum: number?, dir: Random.Dir?)
```
Like `Biometrics.sleep`, but queues the wait behind the async input and returns at once. Blocking input cancels what is still queued.

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

Mouse.click_async()
Biometrics.sleep_async(200, 600)
Mouse.click_async()
```

## Biometrics.click

Definition:
```luau
function Biometrics.click(button: Mouse.Button?, clicks: number?, probability: number?)
```
Clicks at the current mouse position, and sometimes (`probability`, 0.08 by default) clicks a few extra times nearby like a person who double-clicks by habit. `clicks` is the most extra clicks (3 by default).

Example:
```luau
local Biometrics = require("../main/antiban/biometrics")

Biometrics.click()
```
