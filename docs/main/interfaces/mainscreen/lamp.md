# Main.Interfaces.Mainscreen.Lamp

The experience lamp interface (group 240): a grid of skills and a "Confirm" button. Opening, choosing and closing keep the lamp; only "Confirm" spends it (`Lamp.confirm`, `Lamp.use`), after which the interface closes and a continue message box shows, which those functions dismiss. Items are found by name (`Lamp.NAMES`), since many unrelated items are called lamps; the `Lamp` and `Book of Knowledge` are tested, the rest are assumed to work the same. A `Cell` has `name` and `area`. Skills are `Stats.Skill` values, so a misspelled skill is a type error.

```luau
local Lamp = require("@lib/main/interfaces/mainscreen/lamp")
```

## Constants

Definition:
```luau
Lamp.GROUP = 240
Lamp.FIRST_SKILL = 2
Lamp.LAST_SKILL = 25
Lamp.TITLE = 26
Lamp.CONFIRM = 27
Lamp.CONFIRM_LABEL_INDEX = 9
Lamp.CLOSE = 28
Lamp.INVENTORY = 93
Lamp.OPTION = "Rub"
Lamp.CONFIRM_OPTION = "Confirm"
Lamp.NAMES = { "Lamp", "Antique lamp", "Dusty lamp", "Ancient lamp", "Champion's lamp", "Lamp of knowledge", "Lamp of the Gatherer", "Event lamp", "Magic lamp", "Book of Knowledge" }
Lamp.OPTIONS = { ["Book of Knowledge"] = "Read" }
Lamp.OPEN_TIMEOUT_MS = 3000
Lamp.HOVER_TIMEOUT_MS = 800
Lamp.CHOOSE_TIMEOUT_MS = 2400
Lamp.CONFIRM_TIMEOUT_MS = 4000
Lamp.MESSAGE_TIMEOUT_MS = 3000
Lamp.POLL_MS = 50
Lamp.SETTLE_MS = 150
Lamp.OPEN_SETTLE_MS = { 250, 500 }
```
- Widget children of the interface, and the inventory container.
- `OPTION`/`OPTIONS`: the option that opens an item (`OPTIONS` overrides per name); `CONFIRM_OPTION` spends it.
- `NAMES`: items `open` and `slot` look for by default.
- Timeouts: open, hover menu, choice, close after Confirm, message; `POLL_MS` between looks, `SETTLE_MS` after a hover, `OPEN_SETTLE_MS` random pause after opening.

## Lamp.is_open

Definition:
```luau
function Lamp.is_open(): boolean
```
Whether the interface is open.

Example:
```luau
print(Lamp.is_open())
```

## Lamp.wait_open

Definition:
```luau
function Lamp.wait_open(timeout_ms: number?): boolean
```
Polls for the interface up to `timeout_ms` (`OPEN_TIMEOUT_MS` by default).

Example:
```luau
Lamp.wait_open()
```

## Lamp.skills

Definition:
```luau
function Lamp.skills(): { Cell }?
```
The visible skill cells in interface order, named by their menu option. `nil` when closed.

Example:
```luau
print(#(Lamp.skills() or {}))
```

## Lamp.find

Definition:
```luau
function Lamp.find(name: string): Cell?
```
The cell of skill `name`, ignoring case. `nil` when closed or absent.

Example:
```luau
local cell = Lamp.find("herblore")
```

## Lamp.selected

Definition:
```luau
function Lamp.selected(): SkillName?
```
The chosen skill, read from the button label ("Confirm: Herblore"). `nil` when none or closed.

Example:
```luau
print(Lamp.selected())
```

## Lamp.choose

Definition:
```luau
function Lamp.choose(skill: SkillName): boolean
```
Hovers the skill, clicks only once the menu offers it, and waits for the button to name it. Spends nothing. `true` at once if already chosen; `false` if absent or the choice didn't take.

Example:
```luau
local Stats = require("@lib/main/interfaces/gametabs/stats")

assert(Lamp.choose(Stats.Skill.Herblore))
```

## Lamp.confirm

Definition:
```luau
function Lamp.confirm(): boolean
```
Clicks "Confirm", **spending the lamp**, waits for the interface to close and dismisses the message. `false` with no click when no skill is chosen. `true` once spent, even if the message couldn't be dismissed (logged).

Example:
```luau
assert(Lamp.confirm())
```

## Lamp.close_message

Definition:
```luau
function Lamp.close_message(key_probability: number?, timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (`MESSAGE_TIMEOUT_MS`) for the post-Confirm message and continues it by key (chance `key_probability`, `nil` for the biometric) or click, falling back to a click. `true` when dismissed. For a message left open; `confirm` already calls it.

Example:
```luau
Lamp.close_message()
```

## Lamp.close_button

Definition:
```luau
function Lamp.close_button(): Widget?
```
The close button, `nil` when closed.

Example:
```luau
local button = Lamp.close_button()
```

## Lamp.close

Definition:
```luau
function Lamp.close(key_probability: number?): boolean
```
Closes the interface, keeping the lamp, via `Toplevel.close` (`nil` or 0 uses the Escape biometric).

Example:
```luau
Lamp.close()
```

## Lamp.slot

Definition:
```luau
function Lamp.slot(item: (number | string)?): number?
```
The inventory slot of `item` (id, or name ignoring case), or by default of the first item named in `NAMES`. `nil` when not held.

Example:
```luau
print(Lamp.slot())
```

## Lamp.open

Definition:
```luau
function Lamp.open(item: (number | string)?): (boolean, string?)
```
Clears any other open interface with Escape, then rubs (or `OPTIONS` option) the lamp and waits for the interface. Spends nothing. `true` if open or already open; otherwise `false` and a reason ("no lamp held", "another interface is open", ...).

Example:
```luau
local ok, why = Lamp.open()
assert(ok, why)
```

## Lamp.use

Definition:
```luau
function Lamp.use(skill: SkillName, item: (number | string)?): (boolean, string?)
```
`open`, `choose` and `confirm`: **spends the lamp** on `skill`. `false` and a reason on failure.

Example:
```luau
local Stats = require("@lib/main/interfaces/gametabs/stats")

local ok, why = Lamp.use(Stats.Skill.Herblore)
assert(ok, why)
```
