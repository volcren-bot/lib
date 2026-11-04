# Main.Interfaces.Mainscreen.Balloon

The hot air balloons' map: a place to click for each balloon, opened by "Fly" on a balloon's pilot or "Use" on its basket (group 469, `zep_balloon_map` in the cache).

```luau
local Balloon = require("@lib/main/interfaces/mainscreen/balloon")
```

The pilots are different NPCs, often with an empty name in the NPC list, so "Fly" is what identifies one. A place's menu only says "Travel", so the module knows each by its component. The map shows every place whether it is unlocked or not; `is_unlocked` reads the varbit that tells. A flight is a jump of about 3 seconds, and the map goes a moment after it lands.

**Logs.** A flight spends one log of the place's kind, from the inventory or from the log storage, which is shared by every balloon. The data asks for no tinderbox.

| Place | Log | Unlock varbit |
| --- | --- | --- |
| Entrana | Logs | 2867 = 2 |
| Taverley | Logs | 2868 = 2 |
| Crafting Guild | Oak logs | 2871 = 1 |
| Varrock | Willow logs | 2872 = 1 |
| Castle Wars | Yew logs | 2869 = 1 |
| Grand Tree | Magic logs | 2870 = 1 |

**The stored counts aren't in the game's variables.** A flight that took a stored log changed no varp to match, so `stored` reads them from the chat: "This crate currently contains ..." from "Check", and "You have 29 sets of Magic logs left in storage." after a flight. For `has_log`, a kind not said yet is taken to be there, and a flight that doesn't happen takes it to be out for `OUT_MS`. Because that could waste a walk, the walker only uses a balloon with its log in the inventory, unless a script sets `Transports.BALLOON_STORAGE = true`. Using the map directly is not limited by this.

The storage's "Preferences" asks which logs go first, and one answer is "Ask me what logs to use every time". That setting, a flight with logs both held and stored, and running out of logs haven't been seen.

A destination has `name`, `area` (where to hover and click), `log` (`id` and `name`) and `unlocked`.

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
```
The interface piece numbers and options, the waits, how the pilot is found, the jump that counts as the flight, and how long a log is taken to be out.

## Balloon.Place

Definition:
```luau
export type Place = "Entrana" | "Taverley" | "Crafting Guild" | "Varrock" | "Castle Wars" | "Grand Tree"
```
Every place. `Balloon.Place` is a frozen table of them keyed without spaces (`CastleWars`, `GrandTree`, ...), and `Balloon.PLACES` has each one's component, log and unlock varbit.

## Balloon.is_open

Definition:
```luau
function Balloon.is_open(): boolean
```
Whether the map is open.

## Balloon.wait_open

Definition:
```luau
function Balloon.wait_open(timeout_ms: number?): boolean
```
Whether the map is open, polled for up to `timeout_ms` (`OPEN_TIMEOUT_MS` by default).

## Balloon.is_unlocked

Definition:
```luau
function Balloon.is_unlocked(place: Place): boolean
```
Whether the account has this balloon, by the game's varbit. It doesn't need the map.

## Balloon.destinations

Definition:
```luau
function Balloon.destinations(): { Destination }?
```
Every place on the map, unlocked or not. Nil when it isn't open.

## Balloon.find

Definition:
```luau
function Balloon.find(name: string): Destination?
```
The place called `name`, ignoring case. Nil when the map isn't open or has no such place.

## Balloon.stored

Definition:
```luau
function Balloon.stored(): { [string]: number }
```
The logs in storage as the chat last said, by log name in lowercase (`logs`, `oak logs`, ...). A kind not said yet is missing. The game keeps the chat for the session, so this can be called anywhere.

Example:
```luau
local Balloon = require("@lib/main/interfaces/mainscreen/balloon")

print(Balloon.stored()["magic logs"])
```

## Balloon.holds_log

Definition:
```luau
function Balloon.holds_log(place: Place): boolean
```
Whether the inventory holds the log a flight to this place takes.

## Balloon.has_log

Definition:
```luau
function Balloon.has_log(place: Place): boolean
```
Whether a flight to this place has a log to spend: one in the inventory, or in storage unless the chat said or a recent flight showed there are none.

## Balloon.select

Definition:
```luau
function Balloon.select(place: Place): (boolean, string?)
```
Clicks a place on the map and waits for the flight and for the map to go. The click only happens once the menu under the mouse offers that place's "Travel". True when the flight happened. When it didn't the second result says why, and the place's log is taken to be out for `OUT_MS`.

Example:
```luau
local Balloon = require("@lib/main/interfaces/mainscreen/balloon")

assert(Balloon.open())
assert(Balloon.select(Balloon.Place.Varrock))
```

## Balloon.close_button

Definition:
```luau
function Balloon.close_button(): Widget?
```
The close button, nil when the map isn't open.

## Balloon.close

Definition:
```luau
function Balloon.close(key_probability: number?): boolean
```
Closes the map: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.

## Balloon.find_pilot

Definition:
```luau
function Balloon.find_pilot(): Npc?
```
The NPC near you (within `PILOT_RANGE` tiles) that offers "Fly", found by asking: those the cache calls a balloon's first (`zep_`), then the rest, nearest first, up to `PILOT_ASK_LIMIT` hovered. Nil when there is none.

## Balloon.open

Definition:
```luau
function Balloon.open(npc: Npc?, walk: boolean?): (boolean, string?)
```
Opens the map with "Fly" on the pilot near you (or `npc`), else "Use" on the basket, walking closer first unless `walk` is false, and waits for it. True when it is open, also if it already was. When it didn't work the second result says why.

## Balloon.check

Definition:
```luau
function Balloon.check(): { [string]: number }?
```
Reads the log storage near you with "Check", dismisses the message and returns the counts. Nil when there is no storage nearby or nothing was said. It also clears what was taken to be out.
