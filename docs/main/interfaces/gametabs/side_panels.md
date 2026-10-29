# Main.Interfaces.Gametabs.SidePanels

The row of tabs next to the inventory: combat, skills, prayer, spells, settings, logout and so on. Check which one is open and open another.

```luau
local SidePanels = require("../main/interfaces/gametabs/side_panels")
```

A tab can be given by its number or by its name (`"inventory"`, `"stats"`, `"prayerbook"`...).

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
The number of each tab, and the client setting that remembers which one is open.

## SidePanels.name

Definition:
```luau
function SidePanels.name(tab: number): string?
```
The name of a tab from its number.

Example:
```luau
local SidePanels = require("../main/interfaces/gametabs/side_panels")

print(SidePanels.name(SidePanels.INVENTORY)) -- inventory
```

## SidePanels.resolve

Definition:
```luau
function SidePanels.resolve(tab: number | string): number?
```
Turns a tab number or name into its number. Returns an error for an unknown tab.

Example:
```luau
local SidePanels = require("../main/interfaces/gametabs/side_panels")

print(SidePanels.resolve("prayerbook")) -- 5
```

## SidePanels.current

Definition:
```luau
function SidePanels.current(): number?
```
The number of the tab that is open now.

Example:
```luau
local SidePanels = require("../main/interfaces/gametabs/side_panels")

print(SidePanels.name(SidePanels.current() or -1))
```

## SidePanels.is_open

Definition:
```luau
function SidePanels.is_open(tab: number | string): boolean
```
Whether a given tab is the open one.

Example:
```luau
local SidePanels = require("../main/interfaces/gametabs/side_panels")

print("inventory open:", SidePanels.is_open("inventory"))
```

## SidePanels.button

Definition:
```luau
function SidePanels.button(tab: number | string): Widget?
```
The clickable button for a tab. Returns an error if you aren't in game.

Example:
```luau
local SidePanels = require("../main/interfaces/gametabs/side_panels")

local button = SidePanels.button("stats")
print(button and button.x, button and button.y)
```

## SidePanels.key

Definition:
```luau
function SidePanels.key(tab: number | string): number?
```
The key bound to a tab (a `Keyboard.keys` code), or `nil` if it's unbound or you aren't in game. It's read from the client's own keybind settings, found by the names the game cache gives them, so it follows rebinding. Each tab is read once and kept, so rebinding mid-run isn't noticed.

Example:
```luau
local SidePanels = require("../main/interfaces/gametabs/side_panels")
local Keyboard = require("../utils/input/keyboard")

print(SidePanels.key("inventory") == Keyboard.keys.ESCAPE)
```

## SidePanels.open

Definition:
```luau
function SidePanels.open(tab: number | string, key_probability: number?, timeout_ms: number?): boolean
```
Opens a tab and waits for it to open (`timeout_ms` for each try, 3 ticks by default). Does nothing if it's already open.

If the tab has a key bound (see `SidePanels.key`), it presses it with the chance `key_probability`. By default that is a biometric random around `SidePanels.KEY_CHANCE` (0.9), or the `Biometrics.ESCAPE` probability when the key is ESC, since ESC also closes interfaces. Pass `1` to always use the key and `0` to never use it. A tab with no key, or a key press that didn't open the tab, is clicked with the mouse, up to 3 times. Returns `false` if it still isn't open, or if the tab's button isn't available (the click needs it, the key doesn't).

Example:
```luau
local SidePanels = require("../main/interfaces/gametabs/side_panels")

print(SidePanels.open("inventory"))
print(SidePanels.open("stats", 0)) -- always with the mouse
```

## SidePanels.open_async

Definition:
```luau
function SidePanels.open_async(tab: number | string, key_probability: number?, force: boolean?): boolean
```
Like `SidePanels.open`, but queues the key press or click as async input and returns immediately: it doesn't wait for the tab to open and doesn't retry. Returns `true` if the tab was already open or the input was queued, `false` if the tab is unknown or its button isn't available. `force` queues it even when the tab is open now, for a tab that an earlier queued input leaves. Check `SidePanels.is_open` later, or `Mouse.wait()` / `Keyboard.wait()` to wait for the input.

Example:
```luau
local SidePanels = require("../main/interfaces/gametabs/side_panels")

SidePanels.open_async("inventory")
```
