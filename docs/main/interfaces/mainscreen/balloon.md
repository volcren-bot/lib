# Main.Interfaces.Mainscreen.Balloon

The hot air balloon map (group 469), opened with "Fly" on a pilot or "Use" on the basket. Pilots often have empty names, so they are identified by offering "Fly". Every place shows whether unlocked or not; `is_unlocked` reads its varbit. A flight takes about 3 seconds and ends in a position jump; the map closes shortly after landing.

A flight spends one log of the place's kind, from the inventory or the shared log storage:

| Place | Log | Unlock varbit |
| --- | --- | --- |
| Entrana | Logs | 2867 = 2 |
| Taverley | Logs | 2868 = 2 |
| Crafting Guild | Oak logs | 2871 = 1 |
| Varrock | Willow logs | 2872 = 1 |
| Castle Wars | Yew logs | 2869 = 1 |
| Grand Tree | Magic logs | 2870 = 1 |

Stored counts are in no varp, so they are read from chat ("This crate currently contains ...", "You have N sets of X left in storage."). An unseen kind is assumed present; a failed flight marks its kind out for `OUT_MS`. The walker only flies with the log held unless `Transports.BALLOON_STORAGE = true`. The storage's "Ask me what logs to use every time" preference, flights with logs both held and stored, and running out are untested.

A `Destination` has `name`, `area` (widget to hover and click), `log` (`LogKind`: `id`, `name`) and `unlocked`.

```luau
local Balloon = require("@lib/main/interfaces/mainscreen/balloon")
```

## Constants

Definition:
```luau
Balloon.GROUP = 469
Balloon.CLOSE = 26
Balloon.INVENTORY = 93
Balloon.OPTION = "Fly"
Balloon.BASKET = "Basket"
Balloon.BASKET_OPTION = "Use"
Balloon.STORAGE = "Log storage"
Balloon.CHECK_OPTION = "Check"
Balloon.TRAVEL = "Travel"
Balloon.OPEN_TIMEOUT_MS = 3000
Balloon.HOVER_TIMEOUT_MS = 800
Balloon.FLIGHT_TIMEOUT_MS = 6000
Balloon.CHECK_TIMEOUT_MS = 4000
Balloon.POLL_MS = 50
Balloon.SETTLE_MS = 150
Balloon.OPEN_SETTLE_MS = { 250, 500 }
Balloon.PILOT_RANGE = 12
Balloon.PILOT_ASK_LIMIT = 8
Balloon.PILOT_HOVER_MS = 350
Balloon.LAND_DISTANCE = 6
Balloon.OUT_MS = 300000
Balloon.LOG_KINDS
Balloon.PLACES
```
- Widget children, inventory container, and the object/NPC options used.
- Waits: open, hover menu, flight, check message, poll, hover settle, random pause after opening.
- `PILOT_RANGE`: tiles searched for a pilot, basket or storage; `PILOT_ASK_LIMIT`: NPCs hovered at most; `PILOT_HOVER_MS`: wait per hover.
- `LAND_DISTANCE`: tiles moved that count as the flight; `OUT_MS`: how long a log kind stays marked out.
- `LOG_KINDS`: every `LogKind`; `PLACES`: per place its `button` child, `log`, `varbit` and unlock `value`.

## Balloon.Place

Definition:
```luau
export type Place = "Entrana" | "Taverley" | "Crafting Guild" | "Varrock" | "Castle Wars" | "Grand Tree"
```
Every place. `Balloon.Place` is a frozen table of them keyed without spaces (`Balloon.Place.CastleWars`).

Example:
```luau
Balloon.select(Balloon.Place.GrandTree)
```

## Balloon.is_open

Definition:
```luau
function Balloon.is_open(): boolean
```
Whether the map is open.

Example:
```luau
print(Balloon.is_open())
```

## Balloon.wait_open

Definition:
```luau
function Balloon.wait_open(timeout_ms: number?): boolean
```
Polls for the map up to `timeout_ms` (`OPEN_TIMEOUT_MS`).

Example:
```luau
Balloon.wait_open()
```

## Balloon.is_unlocked

Definition:
```luau
function Balloon.is_unlocked(place: Place): boolean
```
Whether the place is unlocked, by varbit. Works without the map.

Example:
```luau
print(Balloon.is_unlocked(Balloon.Place.Varrock))
```

## Balloon.destinations

Definition:
```luau
function Balloon.destinations(): { Destination }?
```
Every visible place on the map, in no fixed order. `nil` when closed.

Example:
```luau
for _, d in ipairs(Balloon.destinations() or {}) do
	print(d.name, d.log.name, d.unlocked)
end
```

## Balloon.find

Definition:
```luau
function Balloon.find(name: string): Destination?
```
The place called `name`, ignoring case. `nil` when closed or absent.

Example:
```luau
local d = Balloon.find("varrock")
```

## Balloon.stored

Definition:
```luau
function Balloon.stored(): { [string]: number }
```
Stored log counts from the latest chat messages, keyed by lowercase log name (`"oak logs"`). Unseen kinds are missing. Works anywhere, since chat persists for the session.

Example:
```luau
print(Balloon.stored()["magic logs"])
```

## Balloon.holds_log

Definition:
```luau
function Balloon.holds_log(place: Place): boolean
```
Whether the inventory holds the place's log.

Example:
```luau
print(Balloon.holds_log(Balloon.Place.Entrana))
```

## Balloon.has_log

Definition:
```luau
function Balloon.has_log(place: Place): boolean
```
Whether a log is available: held, or stored unless chat said zero or a failed flight marked it out within `OUT_MS`.

Example:
```luau
print(Balloon.has_log(Balloon.Place.Entrana))
```

## Balloon.select

Definition:
```luau
function Balloon.select(place: Place): (boolean, string?)
```
Hovers the place, clicks once the menu offers its "Travel", then waits for the jump and for the map to close. `false` and a reason on failure; a flight that didn't happen also marks the log out for `OUT_MS`.

Example:
```luau
assert(Balloon.open())
assert(Balloon.select(Balloon.Place.Varrock))
```

## Balloon.close_button

Definition:
```luau
function Balloon.close_button(): Widget?
```
The close button, `nil` when closed.

Example:
```luau
local button = Balloon.close_button()
```

## Balloon.close

Definition:
```luau
function Balloon.close(key_probability: number?): boolean
```
Closes the map via `Toplevel.close` (`nil` or 0 uses the Escape biometric).

Example:
```luau
Balloon.close()
```

## Balloon.find_pilot

Definition:
```luau
function Balloon.find_pilot(): Npc?
```
Hovers NPCs within `PILOT_RANGE`, cache names containing `zep_` first then nearest first, up to `PILOT_ASK_LIMIT`, and returns the first offering "Fly". `nil` when none.

Example:
```luau
print(Balloon.find_pilot())
```

## Balloon.open

Definition:
```luau
function Balloon.open(npc: Npc?, walk: boolean?): (boolean, string?)
```
Clears other interfaces with Escape, then uses "Fly" on `npc` or `find_pilot()` (walking closer unless `walk` is false), or else "Use" on a basket within `PILOT_RANGE` (always walking), and waits for the map. `true` if open or already open; otherwise `false` and a reason.

Example:
```luau
local ok, why = Balloon.open()
assert(ok, why)
```

## Balloon.check

Definition:
```luau
function Balloon.check(): { [string]: number }?
```
"Check"s the log storage within `PILOT_RANGE`, dismisses the message, clears every out mark and returns `stored()`. `nil` when no storage is near or no message came.

Example:
```luau
local counts = Balloon.check()
```
