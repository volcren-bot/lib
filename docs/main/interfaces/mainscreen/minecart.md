# Main.Interfaces.Mainscreen.Minecart

The Lovakengj minecart stop list, opened by "Travel" on a minecart. It is the generic list group 187, told apart by a title starting "Minecart rides" (the rest is the fare). Rows read `<col=735a28>K</col>: Name` followed by a Cancel row, and are chosen by click or by key (1 to 9, then A, B, ...); keys depend on the list, so pick stops by name. The current stop is listed and isn't told apart; no locked stop has been observed, but rows in `LOCKED_COLOUR` are marked unavailable.

```luau
local Minecart = require("@lib/main/interfaces/mainscreen/minecart")
```

A `Destination` has `key`, `name`, `available` and `row` (the row widget).

## Constants

Definition:
```luau
Minecart.GROUP = 187
Minecart.TITLE = 0
Minecart.TITLE_INDEX = 1
Minecart.TITLE_PREFIX = "Minecart rides"
Minecart.LIST = 3
Minecart.CLOSE = 4
Minecart.LOCKED_COLOUR = "5f5f5f"
Minecart.CANCEL = "(Cancel)"
Minecart.OBJECT = "Minecart"
Minecart.OPTION = "Travel"
Minecart.KEY_CHANCE = 0.5
Minecart.OPEN_TIMEOUT_MS = 3000
Minecart.CONFIRM_TIMEOUT_MS = 4000
Minecart.POLL_MS = 50
Minecart.SETTLE_MS = { 250, 500 }
```
Widget ids and the title prefix, the locked row colour, the cart object and option, the biometric centre for key-vs-click, and timings. `SETTLE_MS` is the pause after opening, since the client ignores keys pressed right after the list appears.

## Minecart.is_open

Definition:
```luau
function Minecart.is_open(): boolean
```
Whether group 187 is open with the minecart title.

## Minecart.wait_open

Definition:
```luau
function Minecart.wait_open(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (default `OPEN_TIMEOUT_MS`) for the list. False on timeout.

## Minecart.destinations

Definition:
```luau
function Minecart.destinations(): { Destination }?
```
The stops top to bottom, without Cancel. Nil when the list isn't open.

Example:
```luau
for _, d in ipairs(Minecart.destinations() or {}) do
	print(d.key, d.name, d.available)
end
```

## Minecart.names

Definition:
```luau
function Minecart.names(available_only: boolean?): { string }?
```
The stop names; with `available_only`, only unlocked ones. Nil when the list isn't open.

## Minecart.find

Definition:
```luau
function Minecart.find(name: string): Destination?
```
The stop called `name`, case-insensitive. An exact match wins; otherwise a substring match either way counts only if exactly one stop fits ("Hosidius" fits two, so nil).

## Minecart.key_code

Definition:
```luau
function Minecart.key_code(d: Destination): number?
```
The key code for `d.key` (digits and capital letters are their ASCII codes), nil for any other character.

## Minecart.Stop

Definition:
```luau
export type Stop = "Arceuus" | "Farming Guild" | "Hosidius South" | "Hosidius West" | "Kingstown" | "Kourend Woodland" | "Lovakengj" | "Mount Quidamortem" | "Northern Tundras" | "Port Piscarilius" | "Shayzien East" | "Shayzien West"
```
Every stop as the list names it. `Minecart.Stop` is a frozen table keyed without spaces (`Minecart.Stop.PortPiscarilius`).

## Minecart.select

Definition:
```luau
function Minecart.select(stop: Stop, key_probability: number?): string?
```
Chooses a stop and returns "key" or "click". The key is pressed with chance `key_probability` (nil or 0 uses a biometric around `KEY_CHANCE`); if the list is still open after `CONFIRM_TIMEOUT_MS` the row is clicked instead. Nil without acting when the stop is missing or locked, or when nothing closed the list. Doesn't wait for the ride.

Example:
```luau
assert(Minecart.open(), "couldn't open the minecart list")
print("chose by", Minecart.select(Minecart.Stop.Lovakengj))
```

## Minecart.close_button

Definition:
```luau
function Minecart.close_button(): Widget?
```
The close button, nil when the list isn't open.

## Minecart.close

Definition:
```luau
function Minecart.close(key_probability: number?): boolean
```
Closes the list via `Toplevel.close`: Escape with chance `key_probability` (nil or 0 uses the biometric), else the close button. True when closed, also if it wasn't open.

## Minecart.nearest

Definition:
```luau
function Minecart.nearest(): Loc?
```
The nearest loaded "Minecart" object, preferring your plane. Nil when none.

## Minecart.open

Definition:
```luau
function Minecart.open(cart: Loc?, walk: boolean?): boolean
```
Clears other interfaces with Escape, uses "Travel" on `cart` or the nearest minecart (walking closer unless `walk` is false), and waits for the list. If the click opened a menu on a minecart instead, picks "Travel" from it. True when open, also if it already was.

Example:
```luau
if Minecart.open() then
	print(table.concat(Minecart.names(true) or {}, ", "))
	Minecart.close()
end
```
