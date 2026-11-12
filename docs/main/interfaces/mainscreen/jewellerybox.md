# Main.Interfaces.Mainscreen.Jewellerybox

The house jewellery box menu (group 590), opened by "Teleport Menu" on any size of box: panels of free teleports grouped by the jewellery they copy. Each line reads like `<col=ccccff>1:</col> Emir's Arena`; its digit or letter is also its key, and a struck-through line is unavailable. Only the ornate box (six panels) has been observed. The box's direct destination option and "Remove" are never used, and house rows aren't in the transports.

```luau
local Jewellerybox = require("@lib/main/interfaces/mainscreen/jewellerybox")
```

A `Destination` has `name`, `key`, `jewellery` (its panel's title), `available` and `area` (the line widget).

## Constants

Definition:
```luau
Jewellerybox.GROUP = 590
Jewellerybox.FRAME = 1
Jewellerybox.CLOSE_INDEX = 11
Jewellerybox.FIRST_PANEL = 2
Jewellerybox.LAST_PANEL = 7
Jewellerybox.OBJECT = "jewellery box"
Jewellerybox.OPTION = "Teleport Menu"
Jewellerybox.KEY_CHANCE = 0.5
Jewellerybox.OPEN_TIMEOUT_MS = 3000
Jewellerybox.HOVER_TIMEOUT_MS = 800
Jewellerybox.CONFIRM_TIMEOUT_MS = 4000
Jewellerybox.POLL_MS = 50
Jewellerybox.HOVER_SETTLE_MS = 150
Jewellerybox.SETTLE_MS = { 250, 500 }
```
Widget ids, the object-name substring and option, the biometric centre for key-vs-click, and timings.

## Jewellerybox.Place

Definition:
```luau
export type Place = "Emir's Arena" | "Castle Wars" | "Ferox Enclave" | "Fortis Colosseum" | "Burthorpe" | "Barbarian Outpost" | "Corporeal Beast" | "Tears of Guthix" | "Wintertodt Camp" | "Warriors' Guild" | "Champions' Guild" | "Monastery" | "Ranging Guild" | "Fishing Guild" | "Mining Guild" | "Crafting Guild" | "Cooking Guild" | "Woodcutting Guild" | "Farming Guild" | "Miscellania" | "Grand Exchange" | "Falador Park" | "Dondakan's Rock" | "Edgeville" | "Karamja" | "Draynor Village" | "Al Kharid"
```
Every destination of the biggest box. `Jewellerybox.Place` is a frozen table keyed without spaces or punctuation (`EmirsArena`, `TearsofGuthix`, `GrandExchange`).

## Jewellerybox.is_open

Definition:
```luau
function Jewellerybox.is_open(): boolean
```
Whether the menu is open.

## Jewellerybox.wait_open

Definition:
```luau
function Jewellerybox.wait_open(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (default `OPEN_TIMEOUT_MS`) for the menu. False on timeout.

## Jewellerybox.destinations

Definition:
```luau
function Jewellerybox.destinations(): { Destination }?
```
Every destination, panel by panel, read from memory without hovering. Nil when the menu isn't open.

Example:
```luau
for _, d in ipairs(Jewellerybox.destinations() or {}) do
	print(d.key, d.name, d.jewellery, d.available)
end
```

## Jewellerybox.names

Definition:
```luau
function Jewellerybox.names(): { string }?
```
The destination names in menu order. Nil when the menu isn't open.

## Jewellerybox.find

Definition:
```luau
function Jewellerybox.find(name: string): Destination?
```
The destination called `name`, case-insensitive. An exact match wins; otherwise a substring match either way counts only if exactly one fits ("Exchange" finds Grand Exchange, "Guild" finds nothing).

## Jewellerybox.select

Definition:
```luau
function Jewellerybox.select(place: Place, key_probability: number?): string?
```
Chooses a destination and returns "key" or "click". The key is pressed with chance `key_probability` (nil or 0 uses a biometric around `KEY_CHANCE`); if the menu is still open after `CONFIRM_TIMEOUT_MS` it falls back to hovering the line and clicking only once the menu offers that destination. Nil when not found, struck through, or nothing closed the menu. Doesn't wait for the teleport.

Example:
```luau
assert(Jewellerybox.open())
assert(Jewellerybox.select(Jewellerybox.Place.GrandExchange), "couldn't choose the Grand Exchange")
```

## Jewellerybox.close_button

Definition:
```luau
function Jewellerybox.close_button(): Widget?
```
The close button, nil when the menu isn't open.

## Jewellerybox.close

Definition:
```luau
function Jewellerybox.close(key_probability: number?): boolean
```
Closes the menu via `Toplevel.close`: Escape with chance `key_probability` (nil or 0 uses the biometric), else the close button. True when closed, also if it wasn't open.

## Jewellerybox.nearest

Definition:
```luau
function Jewellerybox.nearest(): Loc?
```
The nearest object whose name contains "jewellery box", nil when none.

## Jewellerybox.open

Definition:
```luau
function Jewellerybox.open(box: Loc?, walk: boolean?): (boolean, string?)
```
Clears other interfaces with Escape, uses "Teleport Menu" on `box` or the nearest box (walking closer unless `walk` is false), and waits for the menu. True when open, also if it already was; otherwise false and the reason.

Example:
```luau
local ok, why = Jewellerybox.open()
assert(ok, why)
print(table.concat(Jewellerybox.names() or {}, ", "))
```
