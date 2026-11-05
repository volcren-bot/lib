# Main.Interfaces.Gametabs.Wornitems

The equipment you are wearing. It has every function of [Inv](../inv.md) already set up for worn items (the slots on screen are components `387:15` to `387:25`), plus named slots and the tab's buttons.

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
```
The container id, its size, the tab's interface and the slot number of each place on the body. `SECONDARY_AMMO` isn't in the container, so the functions from Inv and `worn` don't see it: see [the secondary ammo slot](#the-secondary-ammo-slot).

## Wornitems.BUTTONS

Definition:
```luau
Wornitems.BUTTONS: { [string]: { child: number, option: string } }
```
The buttons under the slots: `stats` ("View equipment stats"), `prices` ("View guide prices"), `death` ("View items kept on death") and `follower` ("Call follower"), with their component in group 387.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

print(Wornitems.BUTTONS.stats.option)
```

## Functions from Inv

`slots`, `items`, `item`, `indices_of`, `index_of`, `find`, `contains`, `contains_any`, `contains_all`, `find_different`, `contains_different`, `count`, `count_ex`, `wait_count`, `quantity`, `slot_quantity`, `used`, `is_used`, `is_empty`, `count_used`, `wait_used`, `open`, `boxes`, `box`, `slot_at`, `hover_slot`, `click_slot`, `interact_slot`, `hover`, `click` and `interact` work as described in [Inv](../inv.md), on your worn items. The ones that use the mouse open the worn items tab first. Slots are the container's (`Wornitems.HEAD`, ...), so 6, 8 and 11 have no box.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

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
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

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
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

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
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

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
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

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
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

print(Wornitems.is_open())
```

## Wornitems.remove

Definition:
```luau
function Wornitems.remove(slot: number | string): boolean
```
Takes off what's worn in `slot` (a number or a name) with its "Remove" option. `false` when the slot is empty. The secondary ammo goes through what holds it: the bolt pouch's interface, or the quiver's "Quiver-Remove".

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

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
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

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
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

print(Wornitems.press("follower"))
```

## The secondary ammo slot

A bolt pouch in the inventory or Dizana's quiver, worn or carried, adds a second ammo slot above the ammo slot (`387:30` for a pouch, `387:28` for a quiver). A quiver turns the pouch's slot off, as the client does. Its item lives in client variables: the pouch's fourth stack ([Boltpouch](../mainscreen/boltpouch.md)), or varps 4142 and 4141 for a quiver. The client's scripts hide the pouch's slot on free worlds and Deadman worlds, and this doesn't check for those.

Definition:
```luau
export type SecondaryHolder = "quiver" | "pouch"
function Wornitems.is_quiver(id: number): boolean
function Wornitems.secondary_ammo_holder(): SecondaryHolder?
function Wornitems.secondary_ammo_accepts(holder: SecondaryHolder, id: number): boolean
function Wornitems.secondary_ammo(): ItemSlot?
function Wornitems.swap_ammo(): boolean
```
`is_quiver` checks the item's param 1910, cached per id. `secondary_ammo_holder` is what gives the slot now, nil when nothing does. `secondary_ammo_accepts` says whether the slot can take an item: a pouch only stores the bolts on its list (enum 336), and a quiver isn't checked. `secondary_ammo` is what the slot holds, with `slot = SECONDARY_AMMO`; nil when it is empty or nothing gives it.

`swap_ammo` swaps the worn ammo with the slot's, either of which may be empty, and waits for it. A slot holding something uses the tab's option: "Wear" for a pouch, its left click, or "Swap" for a quiver, whose left click takes the ammo out. An empty slot uses "Fill" for a quiver, or a drag from the worn ammo in the pouch's interface. False when nothing gives the slot.

Example:
```luau
local Wornitems = require("@lib/main/interfaces/gametabs/wornitems")

if Wornitems.secondary_ammo_holder() ~= nil and Wornitems.secondary_ammo() ~= nil then
	print(Wornitems.swap_ammo())
end
```

## Wornitems.is_quiver

Definition:
```luau
function Wornitems.is_quiver(id: number): boolean
```
TODO...

Example:
```luau

```

## Wornitems.secondary_ammo_holder

Definition:
```luau
function Wornitems.secondary_ammo_holder(): SecondaryHolder?
```
TODO...

Example:
```luau

```

## Wornitems.secondary_ammo_accepts

Definition:
```luau
function Wornitems.secondary_ammo_accepts(holder: SecondaryHolder, id: number): boolean
```
TODO...

Example:
```luau

```

## Wornitems.secondary_ammo

Definition:
```luau
function Wornitems.secondary_ammo(): ItemSlot?
```
TODO...

Example:
```luau

```

## Wornitems.swap_ammo

Definition:
```luau
function Wornitems.swap_ammo(): boolean
```
TODO...

Example:
```luau

```
