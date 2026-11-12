# Main.Interfaces.Gametabs.SidePanels

The side panel tabs (combat, stats, prayer, spells, logout...): which is open, and opening one by key or click. A tab is given by number or by lowercase name (`"inventory"`, `"prayerbook"`, `"magic_spellbook"`).

```luau
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")
```

## Constants

Definition:
```luau
SidePanels.VARC = 171
SidePanels.KEY_CHANCE = 0.9

SidePanels.COMBAT_INTERFACE = 0
SidePanels.STATS = 1
SidePanels.SIDE_JOURNAL = 2
SidePanels.INVENTORY = 3
SidePanels.WORNITEMS = 4
SidePanels.PRAYERBOOK = 5
SidePanels.MAGIC_SPELLBOOK = 6
SidePanels.SIDE_CHANNELS = 7
SidePanels.ACCOUNT = 8
SidePanels.FRIENDS = 9
SidePanels.LOGOUT = 10
SidePanels.SETTINGS_SIDE = 11
SidePanels.EMOTE = 12
SidePanels.MUSIC = 13
```
The varc holding the open tab, the base chance of using a tab's key, and each tab's number (its name is the constant in lowercase).

## SidePanels.name

Definition:
```luau
function SidePanels.name(tab: number): string?
```
A tab's name from its number; nil when unknown.

Example:
```luau
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")

print(SidePanels.name(SidePanels.INVENTORY)) -- inventory
```

## SidePanels.resolve

Definition:
```luau
function SidePanels.resolve(tab: number | string): number?
```
A tab number from a number or case-insensitive name; logs and returns nil for an unknown tab.

Example:
```luau
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")

print(SidePanels.resolve("prayerbook")) -- 5
```

## SidePanels.current

Definition:
```luau
function SidePanels.current(): number?
```
The open tab's number.

Example:
```luau
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")

print(SidePanels.name(SidePanels.current() or -1))
```

## SidePanels.is_open

Definition:
```luau
function SidePanels.is_open(tab: number | string): boolean
```
Whether `tab` is the open one; false for an unknown tab.

Example:
```luau
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")

print(SidePanels.is_open("inventory"))
```

## SidePanels.button

Definition:
```luau
function SidePanels.button(tab: number | string): Widget?
```
The tab's button widget. Nil when not logged in, the tab is unknown, or the current root interface's layout isn't known.

Example:
```luau
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")

local button = SidePanels.button("stats")
```

## SidePanels.key

Definition:
```luau
function SidePanels.key(tab: number | string): number?
```
The `Keyboard.keys` code bound to the tab in the client's keybind settings (F1 to F12 or ESCAPE), nil when unbound or unreadable. Cached per tab once read, so mid-run rebinds aren't seen.

Example:
```luau
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")

print(SidePanels.key("inventory"))
```

## SidePanels.open

Definition:
```luau
function SidePanels.open(tab: number | string, key_probability: number?, timeout_ms: number?): boolean
```
Opens the tab and waits `timeout_ms` (1800) per try; true at once when already open. A bound key is pressed with chance `key_probability` (default a biometric value around `KEY_CHANCE`, or the `Biometrics.ESCAPE` probability for ESC; `1` always, `0` never). Otherwise, or if the key didn't work, the button is clicked up to 3 times. False if it never opens or the button is unavailable.

Example:
```luau
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")

SidePanels.open("stats", 0)
```

## SidePanels.open_async

Definition:
```luau
function SidePanels.open_async(tab: number | string, key_probability: number?, force: boolean?): boolean
```
`open` as one queued key press or click, without waiting or retrying. True when already open (unless `force`) or the input was queued; false for an unknown tab or missing button. Wait with `Mouse.wait()` / `Keyboard.wait()` or check `is_open` later.

Example:
```luau
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")

SidePanels.open_async("inventory")
```
