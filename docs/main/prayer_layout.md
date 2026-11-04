# Main.PrayerLayout

Prayer layouts: what a `prayer` form field gives a script, turned on as the regular prayers or made the quick prayers.

```luau
local PrayerLayout = require("@lib/main/prayer_layout")
```

The user makes layouts in the loader, on the Prayer tab of the script's page: the prayer book as the game lays it out, where prayers are clicked together (the ones that can't be on at once deselect each other) or read from the client (the prayers on now, or the quick prayer selection); the layouts are kept per script and the form's `prayer` field picks one (see `Host.form` in [Host](../host.md)). A layout is only the set of prayers, by key as [Prayer](interfaces/gametabs/prayer.md) names them (the upgrades `deadeye`, `mystic_vigour` and `zeal` included, each taking its base prayer's slot and quick prayer bit once unlocked); the script decides whether to turn them on (`activate`) or make them the quick prayers (`set_quick`, `quick`).

```luau
local Host = require("@lib/host")
local PrayerLayout = require("@lib/main/prayer_layout")

local values = Host.form({
	title = "Slayer",
	fields = { { id = "prayers", kind = "prayer", label = "Prayers" } },
})
local layout = values and values.prayers
if layout then
	-- as the quick prayers, turned on when the fight starts
	PrayerLayout.set_quick(layout)
	-- or straight away
	PrayerLayout.activate(layout)
end
```

## Types

Definition:
```luau
export type Layout = Host.PrayerLayout
```
`{ name, prayers }`, the prayers by key (`"thick_skin"`, `"protect_from_melee"`, ...) in the prayer book's order. A key the prayer tab doesn't know (from a newer loader) is skipped.

## PrayerLayout.from_client

Definition:
```luau
function PrayerLayout.from_client(name: string?, quick: boolean?): Layout
```
A layout of the prayers on now, or with `quick` of the quick prayer selection; a selected bit shared by a base prayer and its upgrade counts as the upgrade once it is unlocked.

## PrayerLayout.is_active

Definition:
```luau
function PrayerLayout.is_active(layout: Layout): boolean
```
Whether exactly the layout's prayers are on: all of them, and no other.

## PrayerLayout.is_quick

Definition:
```luau
function PrayerLayout.is_quick(layout: Layout): boolean
```
Whether the quick prayers are exactly the layout's prayers, by their bits: an upgrade and the prayer it replaces share one, so either name matches.

## PrayerLayout.activate

Definition:
```luau
function PrayerLayout.activate(layout: Layout): boolean
```
Turns the layout's prayers on and every other prayer off, through the prayer tab: the others first, since turning a prayer on turns off the ones it can't be used with. True when exactly they are on afterwards. Needs the prayer points and levels for them; `Prayer.can_activate` says which can't be.

## PrayerLayout.deactivate

Definition:
```luau
function PrayerLayout.deactivate(): boolean
```
Turns every prayer off. True when none is on afterwards.

## PrayerLayout.set_quick

Definition:
```luau
function PrayerLayout.set_quick(layout: Layout): boolean
```
Makes the layout's prayers the quick prayers, through the setup panel (`Prayer.set_quick_prayers`). True when the quick prayers are exactly them afterwards.

## PrayerLayout.quick

Definition:
```luau
function PrayerLayout.quick(layout: Layout, active: boolean?): boolean
```
Makes the layout the quick prayers and turns them on with the minimap orb, or off with `active` false.
