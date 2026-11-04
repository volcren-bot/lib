# Main.Interfaces.Mainscreen.Lamp

The experience lamp interface: a grid of the skills and a button, opened by "Rub" on a lamp (group 240, `xpreward` in the cache).

```luau
local Lamp = require("@lib/main/interfaces/mainscreen/lamp")
```

Rubbing a lamp, choosing a skill and closing the interface all keep the lamp. Only "Confirm" spends it, so only `Lamp.confirm` and `Lamp.use` do. Closing forgets the chosen skill. After "Confirm" the interface closes, the lamp leaves the inventory, and a message box (group 229, `messagebox`) says `Your wish has been granted!`, then `You have been awarded 990 Slayer XP!` (seen once, at level 99), until it is continued. `Lamp.confirm` and `Lamp.use` dismiss it.

Only the plain `Lamp` (id 2528, from the genie) has been seen opening this. The other names in `Lamp.NAMES` come from the cache and are assumed to work the same; `open` fails with a reason if one doesn't. Many other items are called lamps, like an oil lamp, which is why these go by name.

A cell has `name` and `area` (where to hover and click). Skills are given with `Stats.Skill` (`Lamp.choose(Stats.Skill.Herblore)`), so a misspelled skill is a type error.

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
Lamp.NAMES = { "Lamp", "Antique lamp", "Dusty lamp", "Ancient lamp", "Champion's lamp", "Lamp of knowledge", "Lamp of the Gatherer", "Event lamp", "Magic lamp" }
Lamp.OPEN_TIMEOUT_MS = 3000
Lamp.HOVER_TIMEOUT_MS = 800
Lamp.CHOOSE_TIMEOUT_MS = 2400
Lamp.CONFIRM_TIMEOUT_MS = 4000
Lamp.MESSAGE_TIMEOUT_MS = 3000
Lamp.POLL_MS = 50
Lamp.SETTLE_MS = 150
Lamp.OPEN_SETTLE_MS = { 250, 500 }
```
The interface piece numbers, the inventory's container, the options that open the interface and spend the lamp, the items `open` looks for by default, and the waits: for `wait_open`, for a hover to show the menu, for a choice to show, for the interface to go after "Confirm", for the message after it, between looks, for the menu to follow the mouse, and the pause `open` makes once the interface shows.

## Lamp.is_open

Definition:
```luau
function Lamp.is_open(): boolean
```
Whether the interface is open.

## Lamp.wait_open

Definition:
```luau
function Lamp.wait_open(timeout_ms: number?): boolean
```
Whether the interface is open, polled for up to `timeout_ms` (3 seconds by default).

## Lamp.skills

Definition:
```luau
function Lamp.skills(): { Cell }?
```
The skills in the interface's order. Each cell keeps its skill's name as its first menu option, so nothing is hovered. Nil when the interface isn't open.

## Lamp.find

Definition:
```luau
function Lamp.find(name: string): Cell?
```
The cell of `name`, ignoring case. Nil when the interface isn't open or it has no such skill.

## Lamp.selected

Definition:
```luau
function Lamp.selected(): SkillName?
```
The skill chosen now, read from the button's label ("Confirm: Herblore"). Nil when none is, or the interface isn't open.

## Lamp.choose

Definition:
```luau
function Lamp.choose(skill: SkillName): boolean
```
Chooses a skill, which spends nothing, and waits for the button to name it. The click only happens once the menu under the mouse offers that skill. True at once when it is chosen already. False when the interface has no such skill or the choice didn't take.

Example:
```luau
local Lamp = require("@lib/main/interfaces/mainscreen/lamp")
local Stats = require("@lib/main/interfaces/gametabs/stats")

assert(Lamp.open())
assert(Lamp.choose(Stats.Skill.Herblore), "couldn't choose Herblore")
print(Lamp.selected())
```

## Lamp.confirm

Definition:
```luau
function Lamp.confirm(): boolean
```
Clicks "Confirm", which **spends the lamp** on the chosen skill, waits for the interface to go and dismisses the message that follows. False, with no click, when no skill is chosen. True once the lamp is spent, even if the message couldn't be dismissed, which is logged.

## Lamp.close_message

Definition:
```luau
function Lamp.close_message(key_probability: number?, timeout_ms: number?): boolean
```
Dismisses the message box the game shows after "Confirm", waiting up to `timeout_ms` for it (`MESSAGE_TIMEOUT_MS` by default). By key or click (`key_probability`; nil is the biometric), by click if the key doesn't take. True when one was dismissed. `Lamp.confirm` already does this; it's for a message left open.

## Lamp.close_button

Definition:
```luau
function Lamp.close_button(): Widget?
```
The close button, nil when the interface isn't open.

## Lamp.close

Definition:
```luau
function Lamp.close(key_probability: number?): boolean
```
Closes the interface, keeping the lamp: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.

## Lamp.slot

Definition:
```luau
function Lamp.slot(item: (number | string)?): number?
```
The inventory slot of `item` (an id or a name, ignoring case), or by default of the first item called one of `NAMES`. Nil when none is held.

## Lamp.open

Definition:
```luau
function Lamp.open(item: (number | string)?): (boolean, string?)
```
Opens the interface by rubbing a lamp in the inventory (`item`, an id or a name; by default the first of `NAMES`), which spends nothing yet, and waits for it. True when it is open, also if it already was. When it didn't work the second result says why.

Example:
```luau
local Lamp = require("@lib/main/interfaces/mainscreen/lamp")

local ok, why = Lamp.open()
assert(ok, why)
print(#(Lamp.skills() or {}), "skills")
assert(Lamp.close(), "couldn't close it")
```

## Lamp.use

Definition:
```luau
function Lamp.use(skill: SkillName, item: (number | string)?): (boolean, string?)
```
Opens the interface if needed, chooses `skill` and confirms, **spending the lamp** and dismissing the message after it. When it didn't work the second result says why.

Example:
```luau
local Lamp = require("@lib/main/interfaces/mainscreen/lamp")
local Stats = require("@lib/main/interfaces/gametabs/stats")

local ok, why = Lamp.use(Stats.Skill.Herblore)
assert(ok, why)
```
