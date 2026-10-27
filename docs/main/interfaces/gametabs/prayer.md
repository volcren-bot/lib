# Main.Interfaces.Gametabs.Prayer

The prayer tab: which prayers are active, what you can activate, and switching them on and off.

```luau
local Prayer = require("../main/interfaces/gametabs/prayer")
```

Nothing here looks at the screen's colours. Whether a prayer is active is read from its game setting (a varbit), so it works with the tab closed. Activating and deactivating click the prayer's slot in the tab (component group 541) and wait for the setting to change.

A prayer is given by its name. Case, spaces and underscores don't matter, so `"Protect from Melee"`, `"protect_from_melee"` and `"protectfrommelee"` all work. An `Info` returned by these functions can be passed instead of a name. Functions that take several prayers accept one prayer or a list.

The standard prayer book is covered, with its quick prayers. The ruinous powers book is not.

## Constants

Definition:
```luau
Prayer.GROUP = 541

Prayer.ORB_GROUP = 160
Prayer.ORB = 20
Prayer.QUICK_SELECTED_VARBIT = 4102
Prayer.QUICK_ACTIVE_VARBIT = 4103
Prayer.SETUP_GROUP = 77
Prayer.SETUP_SLOTS = 4
Prayer.SETUP_DONE = 5
```
The prayer tab's interface (its slots are components 9 to 37), then the quick prayer parts: the prayer orb on the minimap (component 160:20), the settings that hold the selected quick prayers (a bitmask) and whether they are on, and the setup panel (group 77) with its slots (the children of 77:4) and its Done button.

## Types

Definition:
```luau
export type Info = {
	key: string,
	name: string,
	child: number,
	varbit: number,
	level: number,
	defence: number?,
	unlock: number?,
	upgrade: number?,
}
export type PrayerRef = string | Info
```
A prayer. `key` is its snake_case name (`"protect_from_melee"`), `child` its slot in group 541, `varbit` the game setting that is 1 while it is active, `level` the Prayer level it needs and `defence` the Defence level it needs besides. `unlock` is the setting that is 1 once the prayer is unlocked, for Rigour, Augury and Preserve. `upgrade` is the setting of the upgraded prayer that takes this slot once its scroll is used: Deadeye for Eagle Eye and Mystic Vigour for Mystic Might.

## Prayer.PRAYERS

Definition:
```luau
Prayer.PRAYERS: { Info }
```
Every prayer, in the order of the tab.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

for _, p in ipairs(Prayer.PRAYERS) do
	print(p.level, p.name)
end
```

## Prayer.prayer

Definition:
```luau
function Prayer.prayer(prayer: PrayerRef): Info?
```
Looks a prayer up by name. Returns `nil` (and logs) for a name that isn't a prayer.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

print(Prayer.prayer("piety").level) -- 70
```

## Prayer.is_open

Definition:
```luau
function Prayer.is_open(): boolean
```
Whether the prayer tab is open.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

print(Prayer.is_open())
```

## Prayer.open

Definition:
```luau
function Prayer.open(timeout_ms: number?): boolean
```
Opens the prayer tab. Returns `true` if it is open in the end.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

assert(Prayer.open())
```

## Prayer.points

Definition:
```luau
function Prayer.points(): (number?, number?)
```
Your prayer points and your Prayer level (the points when full).

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

local points, level = Prayer.points()
print(`{points}/{level}`)
```

## Prayer.widget

Definition:
```luau
function Prayer.widget(prayer: PrayerRef): Widget?
```
The prayer's slot in the tab. `nil` when the interface isn't loaded.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

local slot = Prayer.widget("Smite")
```

## Prayer.is_visible

Definition:
```luau
function Prayer.is_visible(prayer: PrayerRef): boolean
```
Whether the prayer's slot is showing. It is hidden while the tab is closed, and when the prayer filters hide the prayer.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

print(Prayer.is_visible("Piety"))
```

## Prayer.is_unlocked

Definition:
```luau
function Prayer.is_unlocked(prayer: PrayerRef): boolean
```
Whether the prayer is unlocked. Only Rigour, Augury and Preserve are checked, the rest are `true`.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

print(Prayer.is_unlocked("Rigour"))
```

## Prayer.is_on

Definition:
```luau
function Prayer.is_on(prayer: PrayerRef): boolean
```
Whether the prayer is active. Eagle Eye and Mystic Might also count as active while their upgrade is.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

print(Prayer.is_on("Protect from Melee"))
```

## Prayer.is_active

Definition:
```luau
function Prayer.is_active(prayers: PrayerRef | { PrayerRef }): boolean
```
Whether all the prayers are active.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

if Prayer.is_active({ "Piety", "Protect from Melee" }) then
	print("both are on")
end
```

## Prayer.is_any_active

Definition:
```luau
function Prayer.is_any_active(): boolean
```
Whether any prayer is active.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

print(Prayer.is_any_active())
```

## Prayer.active

Definition:
```luau
function Prayer.active(): { Info }
```
Every active prayer.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

for _, p in ipairs(Prayer.active()) do
	print(p.name)
end
```

## Prayer.can_activate

Definition:
```luau
function Prayer.can_activate(prayer: PrayerRef): boolean
```
Whether you have what the prayer needs: prayer points, the Prayer level, the Defence level (the real one) and the unlock. Quest requirements (Chivalry and Piety need King's Ransom) can't be read, so those are only found out when the activation fails.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

print(Prayer.can_activate("Rigour"))
```

## Prayer.hover

Definition:
```luau
function Prayer.hover(prayer: PrayerRef): boolean
```
Opens the tab and moves the mouse over the prayer's slot. Returns `false` if the slot isn't showing.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

Prayer.hover("Piety")
```

## Prayer.set

Definition:
```luau
function Prayer.set(prayer: PrayerRef, active: boolean): boolean
```
Turns one prayer on or off and waits for it to change. Does nothing if it is already so. Returns `false` if it can't be activated, its slot isn't showing, or it didn't change.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

Prayer.set("Protect from Melee", true)
```

## Prayer.activate

Definition:
```luau
function Prayer.activate(prayers: PrayerRef | { PrayerRef }): boolean
```
Turns on each of the prayers that is off. Tries all of them, and returns `true` if all are active in the end.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

if not Prayer.activate({ "Piety", "Protect from Melee" }) then
	print("couldn't turn the prayers on")
end
```

## Prayer.deactivate

Definition:
```luau
function Prayer.deactivate(prayers: PrayerRef | { PrayerRef }): boolean
```
Turns off each of the prayers that is on. Returns `true` if all are off in the end.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

Prayer.deactivate("Piety")
```

## Prayer.deactivate_all

Definition:
```luau
function Prayer.deactivate_all(): boolean
```
Turns off every active prayer.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

Prayer.deactivate_all()
```

## Prayer.QUICK_ORDER

Definition:
```luau
Prayer.QUICK_ORDER: { string }
```
The keys of the prayers in the order of the quick prayer setup's slots. The selected quick prayers are a bitmask of them, where bit 0 is the first.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

print(Prayer.QUICK_ORDER[1]) -- thick_skin
```

## Prayer.is_quick_selected

Definition:
```luau
function Prayer.is_quick_selected(prayer: PrayerRef): boolean
```
Whether the prayer is one of your quick prayers. Reads a game setting, so no panel has to be open.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

print(Prayer.is_quick_selected("Piety"))
```

## Prayer.quick_prayers

Definition:
```luau
function Prayer.quick_prayers(): { Info }
```
Your quick prayers.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

for _, p in ipairs(Prayer.quick_prayers()) do
	print(p.name)
end
```

## Prayer.is_quick_active

Definition:
```luau
function Prayer.is_quick_active(): boolean
```
Whether the quick prayers are on.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

print(Prayer.is_quick_active())
```

## Prayer.set_quick_active

Definition:
```luau
function Prayer.set_quick_active(active: boolean): boolean
```
Turns the quick prayers on or off from the minimap orb and waits for it to change. Turning them on needs prayer points and at least one quick prayer, otherwise it returns `false`.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

Prayer.set_quick_active(true)
```

## Prayer.is_quick_setup_open

Definition:
```luau
function Prayer.is_quick_setup_open(): boolean
```
Whether the quick prayer setup panel is open.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

print(Prayer.is_quick_setup_open())
```

## Prayer.open_quick_setup

Definition:
```luau
function Prayer.open_quick_setup(): boolean
```
Opens the quick prayer setup from the orb's right-click menu.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

assert(Prayer.open_quick_setup())
```

## Prayer.close_quick_setup

Definition:
```luau
function Prayer.close_quick_setup(): boolean
```
Closes the quick prayer setup with its Done button.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

Prayer.close_quick_setup()
```

## Prayer.set_quick_prayers

Definition:
```luau
function Prayer.set_quick_prayers(prayers: PrayerRef | { PrayerRef }): boolean
```
Makes these your quick prayers: opens the setup, deselects the other prayers, selects the ones missing and closes it. Returns `true` if the quick prayers are exactly these in the end. Prayers you can't use yet can't be selected, and prayers that exclude each other (Thick Skin and Rock Skin, Burst of Strength and Superhuman Strength...) can't be selected together, so it returns `false` for those.

Example:
```luau
local Prayer = require("../main/interfaces/gametabs/prayer")

if not Prayer.set_quick_prayers({ "Piety", "Protect from Melee" }) then
	print("couldn't set the quick prayers")
end
```
