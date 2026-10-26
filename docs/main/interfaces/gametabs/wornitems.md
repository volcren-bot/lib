# Main.Interfaces.Gametabs.Wornitems

The equipment you are wearing. It has every function of [Inv](../inv.md) already set up for worn items (the slots on screen are components `387:15` to `387:25`), plus named slots and the tab's buttons.

```luau
local Wornitems = require("../main/interfaces/gametabs/wornitems")
```

## Constants

Definition:
```luau
Wornitems.CONTAINER = 94
Wornitems.SIZE = 14
Wornitems.GROUP = 387

Wornitems.HEAD = 0
Wornitems.CAPE = 1
Wornitems.AMULET = 2
Wornitems.WEAPON = 3
Wornitems.BODY = 4
Wornitems.SHIELD = 5
Wornitems.LEGS = 7
Wornitems.HANDS = 9
Wornitems.FEET = 10
Wornitems.RING = 12
Wornitems.AMMO = 13
```
The container id, its size, the tab's interface and the slot number of each place on the body.

## Wornitems.BUTTONS

Definition:
```luau
Wornitems.BUTTONS: { [string]: { child: number, option: string } }
```
The buttons under the slots: `stats` ("View equipment stats"), `prices` ("View guide prices"), `death` ("View items kept on death") and `follower` ("Call follower"), with their component in group 387.

Example:
```luau
local Wornitems = require("../main/interfaces/gametabs/wornitems")

print(Wornitems.BUTTONS.stats.option)
```

## Functions from Inv

`slots`, `items`, `item`, `indices_of`, `index_of`, `find`, `contains`, `contains_any`, `contains_all`, `find_different`, `contains_different`, `count`, `count_ex`, `wait_count`, `quantity`, `slot_quantity`, `used`, `is_used`, `is_empty`, `count_used`, `wait_used`, `open`, `boxes`, `box`, `slot_at`, `hover_slot`, `click_slot`, `interact_slot`, `hover`, `click` and `interact` work as described in [Inv](../inv.md), on your worn items. The ones that use the mouse open the worn items tab first. Slots are the container's (`Wornitems.HEAD`, ...), so 6, 8 and 11 have no box.

Example:
```luau
local Wornitems = require("../main/interfaces/gametabs/wornitems")

print("arrows:", Wornitems.slot_quantity(Wornitems.AMMO))
Wornitems.interact("Amulet of glory(1..6)", "Edgeville")
```

## Wornitems.slot_name

Definition:
```luau
function Wornitems.slot_name(slot: number): string?
```
The name of a slot (`"head"`, `"weapon"`, `"ring"`...). Returns `nil` for slot numbers that aren't used.

Example:
```luau
local Wornitems = require("../main/interfaces/gametabs/wornitems")

print(Wornitems.slot_name(Wornitems.WEAPON)) -- weapon
```

## Wornitems.slot

Definition:
```luau
function Wornitems.slot(name: number | string): number?
```
The slot number of a slot name (`"head"`, `"Legs"`...; case doesn't matter). A slot number is passed through.

Example:
```luau
local Wornitems = require("../main/interfaces/gametabs/wornitems")

print(Wornitems.slot("ring")) -- 12
```

## Wornitems.worn

Definition:
```luau
function Wornitems.worn(): { [string]: ItemSlot }?
```
What you wear, as a table keyed by slot name. Empty slots are left out.

Example:
```luau
local Wornitems = require("../main/interfaces/gametabs/wornitems")

local worn = Wornitems.worn()
if worn and worn.weapon then
	print("weapon id:", worn.weapon.id)
end
```

## Wornitems.is_wearing

Definition:
```luau
function Wornitems.is_wearing(item: Item): boolean
```
Whether you are wearing the item (given by id or name).

Example:
```luau
local Wornitems = require("../main/interfaces/gametabs/wornitems")

print("wearing a cape:", Wornitems.is_wearing("Cape of Legends"))
```

## Wornitems.is_open

Definition:
```luau
function Wornitems.is_open(): boolean
```
Whether the worn items tab is the open side panel.

Example:
```luau
local Wornitems = require("../main/interfaces/gametabs/wornitems")

print(Wornitems.is_open())
```

## Wornitems.remove

Definition:
```luau
function Wornitems.remove(slot: number | string): boolean
```
Takes off what's worn in `slot` (a number or a name) with its "Remove" option. `false` when the slot is empty.

Example:
```luau
local Wornitems = require("../main/interfaces/gametabs/wornitems")

print(Wornitems.remove("head"))
print(Wornitems.wait_used(0, 2000))
```

## Wornitems.button

Definition:
```luau
function Wornitems.button(name: string): Widget?
```
The component of one of `BUTTONS`. Its position is known with the tab closed too.

Example:
```luau
local Wornitems = require("../main/interfaces/gametabs/wornitems")

local stats = Wornitems.button("stats")
print(stats and stats.x, stats and stats.y)
```

## Wornitems.press

Definition:
```luau
function Wornitems.press(name: string): boolean
```
Opens the tab and presses one of `BUTTONS`, checking the client acted on it.

Example:
```luau
local Wornitems = require("../main/interfaces/gametabs/wornitems")

print(Wornitems.press("follower"))
```
