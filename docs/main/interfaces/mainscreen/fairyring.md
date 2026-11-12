# Main.Interfaces.Mainscreen.Fairyring

The fairy ring network. "Configure" on a ring opens the **dials** (`Fairyring.Dial`, group 398) together with the **travel log** side tab (`Fairyring.Log`, group 381); with the interface closed the ring also offers "Last-destination (CODE)", "Zanaris" and a "Favourites" submenu. A house's Spiritual Fairy Tree works too: its options start with "Ring-" and it has no favourites.

```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")
```

A code is three letters, one per dial; clockwise order is `A D C B`, `I L K J`, `P S R Q` (positions 0 to 3, so `AIP` is all at the start). A destination is a code in any spelling (`"aiq"`, `"A I Q"`, `"a-i-q"`) or a case-insensitive part of a place name (`"mudskipper"`, `"zoo"`); text fitting several places is an error.

## Requirements

`open` and every `travel*` **raise an error** unless both hold:

1. Varbits 2328 ≥ 1 and 2329 ≥ 2, set while progressing "Fairytale II - Cure a Queen" (it need not be finished).
2. A Dramen or Lunar staff carried or worn, or the Lumbridge & Draynor elite diary.

## Constants

Definition:
```luau
Fairyring.OBJECT = "Fairy ring"
Fairyring.SPIRITUAL = "Spiritual Fairy Tree"
Fairyring.CONFIGURE = "Configure"
Fairyring.LAST = "Last-destination"
Fairyring.ZANARIS = "Zanaris"
Fairyring.ZANARIS_QUEST = "Lost City"
Fairyring.FAVOURITES = "Favourites"
Fairyring.FAVOURITE_VARBITS = { { 4555, 5008, 5009, 5010 }, { 5011, 5012, 5013, 5014 }, { 5015, 5016, 5017, 5018 }, { 5019, 5020, 5021, 5022 } }
Fairyring.MENU_NEAR = 4
Fairyring.OPEN_TIMEOUT_MS = 4000
Fairyring.POLL_MS = 50
Fairyring.TELEPORT_TIMEOUT_MS = 8000
Fairyring.ARRIVED_DISTANCE = 20
Fairyring.OPEN_SETTLE_MS = { 250, 500 }
Fairyring.LOG_CHANCE = 0.3
Fairyring.USE_VARBIT = 2328
Fairyring.PERMISSION_VARBIT = 2329
Fairyring.USE_NEEDED = 1
Fairyring.PERMISSION_NEEDED = 2
Fairyring.STAVES = { "Dramen staff", "Lunar staff" }
Fairyring.DIARY_REGION = "lumbridge"
Fairyring.DIARY_TIER = "elite"
```

Ring object names and options; the four favourite slots' varbits (three positions and a set flag each); `MENU_NEAR`, the tiles from the ring before opening its menu for a favourite; waits; `ARRIVED_DISTANCE`, the tiles moved (or a plane change) that count as arrived; `OPEN_SETTLE_MS`, the pause after `open`; `LOG_CHANCE`, the base chance of using the log over the dials; and the requirements.

## Fairyring.PLACES

Definition:
```luau
export type Place = { code: string, name: string }
Fairyring.PLACES: { Place }
```
The codes the travel log has been seen to list, with their places worded as the log words them (`"Asgarnia: Mudskipper Point"`). Names are matched against these and, when the log is open, against its own rows. A code that isn't here can still be given as a code.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(#Fairyring.PLACES)
```

## Fairyring.parse_code

Definition:
```luau
function Fairyring.parse_code(text: string): string?
```
Normalises a code (ignoring spaces, `-`, `.`, `_`, `,`) to three capitals. Nil when the text isn't a valid code.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.parse_code("a-i-q")) -- AIQ
```

## Fairyring.code_of

Definition:
```luau
function Fairyring.code_of(positions: { number }): string?
```
The code three dial positions (0 to 3) spell. Nil when a position is out of range.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.code_of({ 0, 0, 3 })) -- AIQ
```

## Fairyring.positions_of

Definition:
```luau
function Fairyring.positions_of(code: string): { number }?
```
The dial positions of a code. Nil when it isn't a code.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(table.concat(Fairyring.positions_of("dkr") or {}, " ")) -- 1 2 2
```

## Fairyring.place

Definition:
```luau
function Fairyring.place(code: string): string?
```
The code's place name from `PLACES`, or nil.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.place("AIQ")) -- Asgarnia: Mudskipper Point
```

## Fairyring.resolve

Definition:
```luau
function Fairyring.resolve(text: string): (string?, string?)
```
A code returns as is with its place. Otherwise matches names from the open travel log and `PLACES`: an exact name, or a name without its region, wins; else exactly one name must contain the text. Returns the code and name, or nil and a reason.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.resolve("mudskipper")) -- AIQ  Asgarnia: Mudskipper Point
print(Fairyring.resolve("d k r"))      -- DKR  Misthalin: Edgeville
```

## Fairyring.can_use

Definition:
```luau
function Fairyring.can_use(): (boolean, string?)
```
Whether the [requirements](#requirements) are met, and the reason if not.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.can_use())
```

## Fairyring.require

Definition:
```luau
function Fairyring.require()
```
Raises an error with the reason when the rings can't be used.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

Fairyring.require()
```

## Fairyring.nearest

Definition:
```luau
function Fairyring.nearest(): Loc?
```
The nearest loaded fairy ring or Spiritual Fairy Tree, preferring the player's plane. Nil when none is loaded.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local ring = Fairyring.nearest()
print(ring and ring.name)
```

## Fairyring.is_open

Definition:
```luau
function Fairyring.is_open(): boolean
```
Whether the dials are open.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.is_open())
```

## Fairyring.open

Definition:
```luau
function Fairyring.open(ring: Loc?, walk: boolean?): (boolean, string?)
```
Clears other interfaces with Escape, then "Configure"s `ring` (default `nearest()`), walking closer unless `walk` is false, and waits for the dials plus `OPEN_SETTLE_MS`. True if open (or already was); otherwise false and a reason. Errors when the rings can't be used.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.open())
```

## Fairyring.close

Definition:
```luau
function Fairyring.close(key_probability: number?): boolean
```
Closes the dials and log by Escape (chance `key_probability`, nil or 0 uses the biometric default) or the close button; see [Toplevel.close](toplevel.md).

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

Fairyring.close(0.5)
```

## Fairyring.last_code

Definition:
```luau
function Fairyring.last_code(): string?
```
The last code used, from varbit `Dial.LAST_VARBIT` (first position × 16 + second × 4 + third). It updates a moment after landing, so right after a teleport it may still be the old code.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.last_code())
```

## Fairyring.last_option

Definition:
```luau
function Fairyring.last_option(): string?
```
The ring's menu text for the last code, `"Last-destination (CODE)"`, or nil.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.last_option())
```

## Fairyring.travel_last

Definition:
```luau
function Fairyring.travel_last(ring: Loc?, walk: boolean?): boolean
```
Uses "Last-destination" on `ring` (default `nearest()`), walking closer unless `walk` is false, and waits for the teleport. False when the dials are open, there's no last code or ring, or the player didn't move. Errors when the rings can't be used.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.travel_last())
```

## Fairyring.favourites

Definition:
```luau
function Fairyring.favourites(): { string }
```
The set favourite codes in slot order (up to four), read from varbits without opening anything.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(table.concat(Fairyring.favourites(), ", "))
```

## Fairyring.is_favourite

Definition:
```luau
function Fairyring.is_favourite(code: string): boolean
```
Whether the code is a favourite.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.is_favourite("dkr"))
```

## Fairyring.travel_favourite

Definition:
```luau
function Fairyring.travel_favourite(code: string, ring: Loc?, walk: boolean?): boolean
```
Walks within `MENU_NEAR` of `ring` (default `nearest()`) unless `walk` is false, picks the code from its "Favourites" submenu and waits for the teleport. False when the code isn't a favourite, the dials are open, there's no ring or the player didn't move. Errors when the rings can't be used.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.travel_favourite("DKR"))
```

## Fairyring.travel_zanaris

Definition:
```luau
function Fairyring.travel_zanaris(ring: Loc?, walk: boolean?): boolean
```
Uses the ring's "Zanaris" option, walking closer unless `walk` is false, and waits for the teleport. Errors when the rings can't be used or Lost City isn't complete; false when the dials are open, there's no ring or the player didn't move.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.travel_zanaris())
```

## Fairyring.travel

Definition:
```luau
export type Method = "dial" | "log" | "last" | "favourite" | "zanaris"
function Fairyring.travel(text: string, method: Method?, ring: Loc?): Method?
```
Teleports to a destination and returns the method used, or nil. `"zanaris"` (text or method) uses `travel_zanaris`. With no `method` it tries, in order: "Last-destination" if the code is the last one, the favourite submenu if it's a favourite (not on a Spiritual Fairy Tree), then opens the dials and uses the travel log (chance around `LOG_CHANCE`, when listed) or the dials. A forced `"last"` or `"favourite"` that fails returns nil; a failed log selection falls back to the dials. Errors when the rings can't be used or the text names no single place.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print("went by", Fairyring.travel("mudskipper"))
print("went by", Fairyring.travel("dkr", "dial"))
```

## Fairyring.Dial

The dials (group 398): click areas that turn each dial one step, and a varbit per dial holding its position 0 to 3.

Definition:
```luau
Dial.GROUP = 398
Dial.TITLE = 2
Dial.CONFIRM = 26
Dial.CLOSE = 27
Dial.CLOCKWISE = { 19, 21, 23 }
Dial.COUNTER_CLOCKWISE = { 20, 22, 24 }
Dial.VARBITS = { 3985, 3986, 3987 }
Dial.LETTERS = { { "A", "D", "C", "B" }, { "I", "L", "K", "J" }, { "P", "S", "R", "Q" } }
Dial.LAST_VARBIT = 5374
Dial.OPEN_TIMEOUT_MS = 3000
Dial.TURN_TIMEOUT_MS = 1500
Dial.TURN_TRIES = 3
Dial.CONFIRM_TIMEOUT_MS = 4000
Dial.POLL_MS = 50
```

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.Dial.GROUP)
```

## Dial.is_open

Definition:
```luau
function Dial.is_open(): boolean
```
Whether the dials are open.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local Dial = Fairyring.Dial

print(Dial.is_open())
```

## Dial.wait_open

Definition:
```luau
function Dial.wait_open(timeout_ms: number?): boolean
```
Polls `is_open` for up to `timeout_ms` (default `OPEN_TIMEOUT_MS`).

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local Dial = Fairyring.Dial

print(Dial.wait_open())
```

## Dial.positions

Definition:
```luau
function Dial.positions(): { number }
```
The three dial positions from their varbits; works with the dials closed.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local Dial = Fairyring.Dial

print(table.concat(Dial.positions(), " "))
```

## Dial.code

Definition:
```luau
function Dial.code(): string?
```
The code the dials currently spell.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local Dial = Fairyring.Dial

print(Dial.code())
```

## Dial.turn

Definition:
```luau
function Dial.turn(dial: number, clockwise: boolean): boolean
```
Clicks dial `dial`'s (1 to 3) turn area and waits for its varbit to change, up to `TURN_TRIES` clicks. False when the area isn't shown or the dial never moved.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local Dial = Fairyring.Dial

print(Dial.turn(1, true))
```

## Dial.set

Definition:
```luau
function Dial.set(code: string): boolean
```
Turns each dial the shortest way to `code` (a half turn goes either way at random) with random pauses between clicks. False when the dials are closed or the code invalid; true when they spell it.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local Dial = Fairyring.Dial

print(Dial.set("AIQ"))
```

## Dial.confirm

Definition:
```luau
function Dial.confirm(): boolean
```
Clicks "Confirm" (teleports) and waits for the dials to close. False (logged) when they stay open, e.g. a code with no ring.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local Dial = Fairyring.Dial

if Dial.set("AIQ") then
	Dial.confirm()
end
```

## Dial.close_button

Definition:
```luau
function Dial.close_button(): Widget?
```
The close button, nil when the dials aren't open.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local Dial = Fairyring.Dial

print(Dial.close_button() ~= nil)
```

## Dial.close

Definition:
```luau
function Dial.close(key_probability: number?): boolean
```
Same as `Fairyring.close`; true if already closed.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local Dial = Fairyring.Dial

Dial.close()
```

## Fairyring.Log

The travel log (group 381, a side tab): a scrolling list of codes used before, each with its place. `Fairyring.Log` is `TravelLog` below.

Definition:
```luau
export type Destination = { code: string, name: string, visible: boolean, row: Widget }
TravelLog.GROUP = 381
TravelLog.TITLE = 6
TravelLog.LIST = 8
TravelLog.TITLE_TEXT = "Travel log"
TravelLog.OPTION = "Use code"
TravelLog.FIRST_COMPONENT = 12
TravelLog.LAST_COMPONENT = 170
TravelLog.MAX_SCROLLS = 40
TravelLog.OPEN_TIMEOUT_MS = 3000
TravelLog.CONFIRM_TIMEOUT_MS = 4000
TravelLog.POLL_MS = 50
```

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print(Fairyring.Log.is_open())
```

## TravelLog.is_open

Definition:
```luau
function TravelLog.is_open(): boolean
```
Whether the side tab shows the "Travel log" title.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local TravelLog = Fairyring.Log

print(TravelLog.is_open())
```

## TravelLog.wait_open

Definition:
```luau
function TravelLog.wait_open(timeout_ms: number?): boolean
```
Polls `is_open` for up to `timeout_ms` (default `OPEN_TIMEOUT_MS`).

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local TravelLog = Fairyring.Log

print(TravelLog.wait_open())
```

## TravelLog.destinations

Definition:
```luau
function TravelLog.destinations(): { Destination }?
```
Every listed row top to bottom; `visible` is whether the row lies fully inside the scrolled view. Nil when the log isn't open.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local TravelLog = Fairyring.Log

for _, d in ipairs(TravelLog.destinations() or {}) do
	print(d.code, d.name, d.visible)
end
```

## TravelLog.find

Definition:
```luau
function TravelLog.find(text: string): Destination?
```
The row for a code or place text (via `Fairyring.resolve`). Nil when the log is closed or doesn't list it.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local TravelLog = Fairyring.Log

local d = TravelLog.find("zoo")
print(d and d.code)
```

## TravelLog.scroll_to

Definition:
```luau
function TravelLog.scroll_to(text: string): Destination?
```
Scrolls the list until the row is fully visible, up to `MAX_SCROLLS`. Nil when not listed or scrolling stops moving it.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local TravelLog = Fairyring.Log

TravelLog.scroll_to("mudskipper")
```

## TravelLog.select

Definition:
```luau
function TravelLog.select(text: string): boolean
```
Scrolls to and clicks the row ("Use code"), which **turns the dials but doesn't teleport**; follow with `Dial.confirm`. True once the dials spell the code.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

assert(Fairyring.open())
assert(Fairyring.Log.select("zoo"), "the log has no zoo")
assert(Fairyring.Dial.confirm(), "couldn't confirm")
```
