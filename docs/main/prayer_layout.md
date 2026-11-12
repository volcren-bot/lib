# Main.PrayerLayout

Prayer layouts from a form's `prayer` field, turned on as regular prayers or set as the quick prayers.

```luau
local PrayerLayout = require("@lib/main/prayer_layout")
```

The user builds layouts per script on the loader's Prayer tab; the form's `prayer` field picks one (see `Host.form` in [Host](../host.md)). A layout is a set of prayer keys as [Prayer](interfaces/gametabs/prayer.md) names them (upgrades such as `deadeye`, `mystic_vigour` and `zeal` share their base prayer's slot and quick prayer bit).

A field's `locked` prayers belong to the script (a boss script's protection prayers). The loader padlocks them and every prayer exclusive with them, and the layout lists them all in `locked`. Nothing here turns them on or off or changes their quick selection.

```luau
local Host = require("@lib/host")
local PrayerLayout = require("@lib/main/prayer_layout")

local values = Host.form({
	title = "Slayer",
	fields = { { id = "prayers", kind = "prayer", label = "Prayers", locked = { "protect_from_melee", "protect_from_missiles", "protect_from_magic" } } },
})
local layout = values and values.prayers
if layout then
	PrayerLayout.activate(layout)
end
```

## Constants

Definition:
```luau
PrayerLayout.CONFIRM_MS = 1200
PrayerLayout.ATTEMPTS = 3
PrayerLayout.MOUSE_PACE = 1.2
```
For `activate`: wait per round for clicks to show, maximum rounds, and mouse speed relative to `Mouse.pace` (1.2 is 20% faster).

## Types

Definition:
```luau
export type Layout = Host.PrayerLayout
```
`{ name, prayers, locked? }`: prayer keys in prayer book order, plus the script's locked ones. Unknown keys (from a newer loader) are skipped.

## PrayerLayout.from_client

Definition:
```luau
function PrayerLayout.from_client(name: string?, quick: boolean?): Layout
```
A layout of the prayers on now, or of the quick prayer selection with `quick`. A shared bit counts as the upgrade once it is unlocked.

Example:
```luau
local current = PrayerLayout.from_client("current")
```

## PrayerLayout.is_active

Definition:
```luau
function PrayerLayout.is_active(layout: Layout): boolean
```
True when exactly the layout's prayers are on, ignoring locked ones.

Example:
```luau
print(PrayerLayout.is_active(layout))
```

## PrayerLayout.is_quick

Definition:
```luau
function PrayerLayout.is_quick(layout: Layout): boolean
```
True when the quick prayers are exactly the layout's, compared by bit (an upgrade matches its base prayer), ignoring locked ones.

Example:
```luau
print(PrayerLayout.is_quick(layout))
```

## PrayerLayout.activate

Definition:
```luau
function PrayerLayout.activate(layout: Layout): boolean
```
Turns the layout's prayers on and every other unlocked prayer off through the prayer tab. Missing prayers are clicked first, nearest the mouse first, with no wait between clicks (async mouse at `MOUSE_PACE`); leftover prayers still on are clicked off in a later round, so a click never re-enables one the game just turned off. Each round waits up to `CONFIRM_MS`, `ATTEMPTS` rounds in all. False, with the stuck prayers logged, when the result isn't exact. Needs the levels and prayer points (`Prayer.can_activate`).

Example:
```luau
if not PrayerLayout.activate(layout) then
	print("prayers didn't switch")
end
```

## PrayerLayout.deactivate

Definition:
```luau
function PrayerLayout.deactivate(): boolean
```
Turns every prayer off, locked ones included. True when none is on afterwards.

Example:
```luau
PrayerLayout.deactivate()
```

## PrayerLayout.set_quick

Definition:
```luau
function PrayerLayout.set_quick(layout: Layout): boolean
```
Sets the quick prayers to the layout through the setup panel (`Prayer.set_quick_prayers`), keeping locked prayers' selection. Does nothing when already set. True when they match afterwards.

Example:
```luau
PrayerLayout.set_quick(layout)
```

## PrayerLayout.quick

Definition:
```luau
function PrayerLayout.quick(layout: Layout, active: boolean?): boolean
```
`set_quick`, then turns the quick prayers on with the minimap orb, or off with `active` false.

Example:
```luau
PrayerLayout.quick(layout)
```
