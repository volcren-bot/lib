# Main.Interfaces.Gametabs.Prayer

The standard prayer book and its quick prayers (not the ruinous powers book). State comes from varbits, so reads work with the tab closed; toggles click the prayer's slot in group 541 and wait for the varbit. A prayer is a name where case, spaces and punctuation are ignored (`"Protect from Melee"`, `"protect_from_melee"`), or an `Info`; multi-prayer functions take one or a list.

```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")
```

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
The prayer tab (slots 9 to 37), the minimap prayer orb, the quick prayer bitmask and on/off varbits, and the quick setup panel with its slot layer and Done button.

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
	replaces: string?,
	attack: number?,
	strength: number?,
}
export type PrayerRef = string | Info
```
`key` is the snake_case name, `child` the slot in group 541, `varbit` is 1 while active, `level`/`defence`/`attack`/`strength` are required real levels, `unlock` the varbit that is 1 once unlocked (Rigour, Augury, Preserve and the upgrades). `upgrade` is the varbit of the prayer that takes the slot once unlocked (Eagle Eye to Deadeye, Mystic Might to Mystic Vigour, Piety to Zeal); those upgrades are their own entries, with `replaces` naming the base whose slot and quick bit they share.

## Prayer.PRAYERS

Definition:
```luau
Prayer.PRAYERS: { Info }
```
Every prayer in tab order, then the three upgrades.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

for _, p in ipairs(Prayer.PRAYERS) do
	print(p.level, p.name)
end
```

## Prayer.prayer

Definition:
```luau
function Prayer.prayer(prayer: PrayerRef): Info?
```
Looks a prayer up by name (an `Info` passes through); logs and returns nil when unknown.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

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
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

print(Prayer.is_open())
```

## Prayer.open

Definition:
```luau
function Prayer.open(timeout_ms: number?): boolean
```
Opens the prayer tab via `SidePanels.open`; true once open.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

Prayer.open()
```

## Prayer.points

Definition:
```luau
function Prayer.points(): (number?, number?)
```
Current prayer points and the Prayer level (`Player.prayer`).

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

local points, level = Prayer.points()
print(`{points}/{level}`)
```

## Prayer.widget

Definition:
```luau
function Prayer.widget(prayer: PrayerRef): Widget?
```
The prayer's slot widget; nil when the interface isn't loaded or the name is unknown.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

local slot = Prayer.widget("Smite")
```

## Prayer.is_visible

Definition:
```luau
function Prayer.is_visible(prayer: PrayerRef): boolean
```
Whether the slot shows; false while the tab is closed or the prayer filters hide it.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

print(Prayer.is_visible("Piety"))
```

## Prayer.is_unlocked

Definition:
```luau
function Prayer.is_unlocked(prayer: PrayerRef): boolean
```
Whether the prayer's `unlock` varbit is set; true for prayers without one.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

print(Prayer.is_unlocked("Rigour"))
```

## Prayer.is_on

Definition:
```luau
function Prayer.is_on(prayer: PrayerRef): boolean
```
Whether the prayer is active. A base with an upgrade (Eagle Eye, Mystic Might, Piety) also counts while its upgrade is on; an upgrade counts only itself.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

print(Prayer.is_on("Protect from Melee"))
```

## Prayer.is_active

Definition:
```luau
function Prayer.is_active(prayers: PrayerRef | { read PrayerRef }): boolean
```
Whether all the given prayers are on; false if any name is unknown.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

print(Prayer.is_active({ "Piety", "Protect from Melee" }))
```

## Prayer.is_any_active

Definition:
```luau
function Prayer.is_any_active(): boolean
```
Whether any prayer is on.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

print(Prayer.is_any_active())
```

## Prayer.active

Definition:
```luau
function Prayer.active(): { Info }
```
Every prayer that `is_on`.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

for _, p in ipairs(Prayer.active()) do
	print(p.name)
end
```

## Prayer.can_activate

Definition:
```luau
function Prayer.can_activate(prayer: PrayerRef): boolean
```
Whether you have prayer points, the real Prayer, Defence, Attack and Strength levels it needs, and its unlock. Quest requirements (Chivalry, Piety) aren't readable and only show as a failed activation.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

print(Prayer.can_activate("Rigour"))
```

## Prayer.hover

Definition:
```luau
function Prayer.hover(prayer: PrayerRef): boolean
```
Opens the tab and moves the mouse over the slot; false when the slot isn't showing.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

Prayer.hover("Piety")
```

## Prayer.set

Definition:
```luau
function Prayer.set(prayer: PrayerRef, active: boolean): boolean
```
Turns one prayer on or off via "Activate"/"Deactivate" and waits up to 2 s. True at once when already so; false when it can't be activated, its slot is hidden (check the filters) or it didn't change.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

Prayer.set("Protect from Melee", true)
```

## Prayer.activate

Definition:
```luau
function Prayer.activate(prayers: PrayerRef | { read PrayerRef }): boolean
```
`set` each prayer on, trying all; true when all succeeded.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

Prayer.activate({ "Piety", "Protect from Melee" })
```

## Prayer.deactivate

Definition:
```luau
function Prayer.deactivate(prayers: PrayerRef | { read PrayerRef }): boolean
```
`set` each prayer off, trying all; true when all succeeded.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

Prayer.deactivate("Piety")
```

## Prayer.deactivate_all

Definition:
```luau
function Prayer.deactivate_all(): boolean
```
Deactivates every active prayer.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

Prayer.deactivate_all()
```

## Prayer.QUICK_ORDER

Definition:
```luau
Prayer.QUICK_ORDER: { string }
```
Prayer keys in quick setup slot order; bit 0 of the quick bitmask is the first. Upgrades use their base's bit.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

print(Prayer.QUICK_ORDER[1]) -- thick_skin
```

## Prayer.is_quick_selected

Definition:
```luau
function Prayer.is_quick_selected(prayer: PrayerRef): boolean
```
Whether the prayer is a selected quick prayer, from the varbit.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

print(Prayer.is_quick_selected("Piety"))
```

## Prayer.quick_prayers

Definition:
```luau
function Prayer.quick_prayers(): { Info }
```
Every selected quick prayer.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

print(#Prayer.quick_prayers())
```

## Prayer.is_quick_active

Definition:
```luau
function Prayer.is_quick_active(): boolean
```
Whether quick prayers are on.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

print(Prayer.is_quick_active())
```

## Prayer.set_quick_active

Definition:
```luau
function Prayer.set_quick_active(active: boolean): boolean
```
Toggles quick prayers from the orb and waits up to 2 s. Turning on fails without prayer points or any selected quick prayer.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

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
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

print(Prayer.is_quick_setup_open())
```

## Prayer.open_quick_setup

Definition:
```luau
function Prayer.open_quick_setup(): boolean
```
Opens the setup via the orb's "Setup" option; true at once when open.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

Prayer.open_quick_setup()
```

## Prayer.close_quick_setup

Definition:
```luau
function Prayer.close_quick_setup(): boolean
```
Closes the setup with Done; true at once when not open.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

Prayer.close_quick_setup()
```

## Prayer.set_quick_prayers

Definition:
```luau
function Prayer.set_quick_prayers(prayers: PrayerRef | { read PrayerRef }): boolean
```
Makes exactly these the quick prayers: opens the setup only if something differs, deselects the extras, selects the missing ones and closes it. False when any wanted prayer didn't end up selected, such as one you can't use yet or two that exclude each other.

Example:
```luau
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

Prayer.set_quick_prayers({ "Piety", "Protect from Melee" })
```
