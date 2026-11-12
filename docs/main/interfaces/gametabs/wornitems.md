# Main.Interfaces.Gametabs.Wornitems

The worn equipment: every [Inv](../inv.md) function bound to the worn items container (on-screen slots `387:15` to `387:25`), plus named slots, the tab's buttons and the secondary ammo slot.

```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")
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
Wornitems.SECONDARY_AMMO = 14

Wornitems.INVENTORY_CONTAINER = 93
Wornitems.QUIVER_PARAM = 1910
Wornitems.QUIVER_AMMO_VARP = 4142
Wornitems.QUIVER_AMOUNT_VARP = 4141
Wornitems.SECONDARY_CHILD = { quiver = 28, pouch = 30 }
Wornitems.SWAP_OPTION = { quiver = "Swap", pouch = "Wear" }
Wornitems.QUIVER_FILL_OPTION = "Fill"
Wornitems.QUIVER_REMOVE_OPTION = "Quiver-Remove"
Wornitems.SWAP_TIMEOUT_MS = 2500
Wornitems.POLL_MS = 50
```
Container, size, tab group and slot numbers. `SECONDARY_AMMO` is not in the container, so Inv functions and `worn` don't see it; the remaining constants drive the [secondary ammo slot](#the-secondary-ammo-slot).

## Wornitems.BUTTONS

Definition:
```luau
Wornitems.BUTTONS: { [string]: { child: number, option: string } }
```
The tab's buttons in group 387: `stats`, `prices`, `death`, `follower`, each with its child and menu option.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

print(Wornitems.BUTTONS.stats.option)
```

## Functions from Inv

`slots`, `items`, `item`, `indices_of`, `index_of`, `find`, `contains`, `contains_any`, `contains_all`, `find_different`, `contains_different`, `count`, `count_ex`, `wait_count`, `quantity`, `slot_quantity`, `used`, `is_used`, `is_empty`, `count_used`, `wait_used`, `open`, `boxes`, `box`, `slot_at`, `hover_slot`, `click_slot`, `interact_slot`, `hover`, `click`, `interact`: as in [Inv](../inv.md). Mouse functions open the tab first. Slots 6, 8 and 11 have no box.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

Wornitems.interact("Amulet of glory(1..6)", "Edgeville")
```

## Wornitems.slot_name

Definition:
```luau
function Wornitems.slot_name(slot: number): string?
```
The slot's name (`"head"`, `"weapon"`, `"secondary ammo"`...), nil for unused numbers.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

print(Wornitems.slot_name(Wornitems.WEAPON)) -- weapon
```

## Wornitems.slot

Definition:
```luau
function Wornitems.slot(name: number | string): number?
```
The slot number for a case-insensitive name; a valid number passes through. Nil otherwise.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

print(Wornitems.slot("ring")) -- 12
```

## Wornitems.worn

Definition:
```luau
function Wornitems.worn(): { [string]: ItemSlot }?
```
Worn items keyed by slot name; empty slots are omitted.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

local worn = Wornitems.worn()
if worn and worn.weapon then
	print(worn.weapon.id)
end
```

## Wornitems.is_wearing

Definition:
```luau
function Wornitems.is_wearing(item: Item): boolean
```
Whether the item (id or name) is worn.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

print(Wornitems.is_wearing("Cape of Legends"))
```

## Wornitems.is_open

Definition:
```luau
function Wornitems.is_open(): boolean
```
Whether the worn items tab is the open side panel.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

print(Wornitems.is_open())
```

## Wornitems.remove

Definition:
```luau
function Wornitems.remove(slot: number | string): boolean
```
Takes off the slot's item with "Remove". Secondary ammo goes through its holder: the bolt pouch interface, or the quiver's "Quiver-Remove". False for an empty or unknown slot.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

Wornitems.remove("head")
```

## Wornitems.button

Definition:
```luau
function Wornitems.button(name: string): Widget?
```
The widget of a `BUTTONS` entry; available with the tab closed. Nil for an unknown name.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

local stats = Wornitems.button("stats")
```

## Wornitems.press

Definition:
```luau
function Wornitems.press(name: string): boolean
```
Opens the tab and presses a `BUTTONS` entry, checking the client acted on it.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

Wornitems.press("follower")
```

## The secondary ammo slot

A bolt pouch in the inventory or a quiver, worn or carried, adds a second ammo slot (`387:30` for a pouch, `387:28` for a quiver; a quiver wins). Its item lives in client variables: the pouch's extra stack ([Boltpouch](../mainscreen/boltpouch.md)) or the quiver varps.

## Wornitems.is_quiver

Definition:
```luau
function Wornitems.is_quiver(id: number): boolean
```
Whether the item has `QUIVER_PARAM` set; cached per id.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

print(Wornitems.is_quiver(28951))
```

## Wornitems.secondary_ammo_holder

Definition:
```luau
export type SecondaryHolder = "quiver" | "pouch"
function Wornitems.secondary_ammo_holder(): SecondaryHolder?
```
What gives the secondary ammo slot now: a quiver worn in the cape slot or carried (it overrides a pouch), else a bolt pouch in the inventory, else nil. Free and Deadman worlds, where the client hides the pouch slot, are not checked.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

print(Wornitems.secondary_ammo_holder())
```

## Wornitems.secondary_ammo_accepts

Definition:
```luau
function Wornitems.secondary_ammo_accepts(holder: SecondaryHolder, id: number): boolean
```
Whether the holder's slot can take the item: a quiver always, a pouch unless [Boltpouch](../mainscreen/boltpouch.md) rejects it.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

print(Wornitems.secondary_ammo_accepts("pouch", 9144))
```

## Wornitems.secondary_ammo

Definition:
```luau
function Wornitems.secondary_ammo(): ItemSlot?
```
The secondary slot's item with `slot = SECONDARY_AMMO`, read from the quiver varps or the pouch's extra stack. Nil when empty or no holder.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

local ammo = Wornitems.secondary_ammo()
print(ammo and ammo.quantity)
```

## Wornitems.swap_ammo

Definition:
```luau
function Wornitems.swap_ammo(): boolean
```
Swaps worn ammo with the secondary slot (either may be empty) and waits up to `SWAP_TIMEOUT_MS`. Uses `SWAP_OPTION` when the slot holds something, "Fill" on an empty quiver, or a drag in the pouch interface. True at once when both are empty; false when there is no holder.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

if Wornitems.secondary_ammo() then
	Wornitems.swap_ammo()
end
```
