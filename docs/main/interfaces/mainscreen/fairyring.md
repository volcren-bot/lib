# Main.Interfaces.Mainscreen.Fairyring

The fairy ring network. A ring is used through its **dials** (the main screen interface, group 398 `fairyrings`) or through the **travel log** (the side tab that opens beside it, group 381); both are opened together by the "Configure" option of a "Fairy ring". When the interface is closed, the ring also offers "Last-destination (CODE)" for the last code used.

```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")
```

A code is three letters, one from each dial. Turning a dial clockwise goes through its letters in this order: the first dial `A D C B`, the second `I L K J`, the third `P S R Q` (so `AIP` is all three dials at their start and `BJQ` the last position of each). `Fairyring.Dial` is the dials, `Fairyring.Log` is the travel log; the functions on `Fairyring` itself work over both.

A destination is given as a code in any way a player writes it (`"aiq"`, `"A I Q"`, `"a-i-q"`) or as a part of a place's name in any case (`"mudskipper"`, `"zoo"`, `"Ardougne zoo"`). A text fitting several places (`"islands"`) is an error.

## Requirements

Using the rings needs two things, and `Fairyring.travel` and `Fairyring.open` **raise an error** when they are not met:

1. The quest part: the game's own check. The "Use of fairy rings" requirement of the diary list reads two varbits, `fairyring_use` (2328) at least 1 and `fairyring_permission` (2329) at least 2, which "Fairytale II - Cure a Queen" sets as you advance in it. They are what is checked here, so the quest need not be finished.
2. One of: a Dramen staff or a Lunar staff in the inventory or worn, or the Lumbridge & Draynor elite diary.

## Constants

Definition:
```luau
Fairyring.OBJECT = "Fairy ring"
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
The ring object and its options (the favourites submenu, the varbits of the four favourites, and how close to the ring to get before its menu is opened), the waits, how far a position must move to count as arrived, the pause `open` makes once the interface shows, the chance a biometric is rolled around for using the travel log rather than the dials, and what the rings require.

## Fairyring.PLACES

Definition:
```luau
export type Place = { code: string, name: string }
Fairyring.PLACES: { Place }
```
The codes the travel log has been seen to list, with their places worded as the log words them (`"Asgarnia: Mudskipper Point"`). Names are matched against these and, when the log is open, against its own rows. A code that isn't here can still be given as a code.

## Fairyring.parse_code

Definition:
```luau
function Fairyring.parse_code(text: string): string?
```
A code written as a player might (`"aiq"`, `"A I Q"`, `"a-i-q"`) as three capital letters, each from its dial. Nil when the text is not a code.

## Fairyring.code_of / Fairyring.positions_of / Fairyring.place

Definition:
```luau
function Fairyring.code_of(positions: { number }): string?
function Fairyring.positions_of(code: string): { number }?
function Fairyring.place(code: string): string?
```
The code three dial positions (0 to 3 each) spell, the positions of a code, and a code's place among `PLACES`.

## Fairyring.resolve

Definition:
```luau
function Fairyring.resolve(text: string): (string?, string?)
```
What a text names: a code as it is, else a part of a place's name (an exact name, or the place without its region, wins; otherwise exactly one place must contain the text). Returns the code and the place's name, or nil and why not.

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
Whether the rings can be used now, and if not why. See Requirements.

## Fairyring.require

Definition:
```luau
function Fairyring.require()
```
Raises an error with the reason when the rings can't be used.

## Fairyring.nearest

Definition:
```luau
function Fairyring.nearest(): Loc?
```
The nearest "Fairy ring" among the objects loaded, on the plane you are on first. Nil when none is loaded.

## Fairyring.open

Definition:
```luau
function Fairyring.open(ring: Loc?, walk: boolean?): (boolean, string?)
```
Opens the dials and the travel log with "Configure" on the nearest ring (or `ring`), walking closer first unless `walk` is false. True when they are open (also if they already were); when it didn't work the second result says why. Errors when the rings can't be used.

## Fairyring.close / Fairyring.is_open

Definition:
```luau
function Fairyring.close(key_probability: number?): boolean
function Fairyring.is_open(): boolean
```
Closes the dials and the travel log (Escape with chance `key_probability`, nil or 0 is the Escape biometric, else the close button; see `Toplevel.close`), and whether they are open.

## Fairyring.last_code / Fairyring.last_option

Definition:
```luau
function Fairyring.last_code(): string?
function Fairyring.last_option(): string?
```
The last code used, which the ring offers as `"Last-destination (CODE)"` while the interface is closed (`last_option` is that text). It is read from varbit 5374, which holds the first dial's position times 16, plus the second's times 4, plus the third's. The game updates it a moment after a teleport lands, so right then it can still read the old value.

## Fairyring.travel_last

Definition:
```luau
function Fairyring.travel_last(ring: Loc?, walk: boolean?): boolean
```
Uses "Last-destination" on the nearest ring (or `ring`), walking closer first unless `walk` is false, and waits for the teleport. Errors when the rings can't be used. False when the interface is open, there is no last code or ring, or nothing happened.

## Fairyring.favourites / Fairyring.is_favourite

Definition:
```luau
function Fairyring.favourites(): { string }
function Fairyring.is_favourite(code: string): boolean
```
The ring's favourite codes (up to four, in slot order), and whether a code is one. Read from the game's variables (each favourite is three dial positions and a flag that says it is set), so nothing is opened.

## Fairyring.travel_favourite

Definition:
```luau
function Fairyring.travel_favourite(code: string, ring: Loc?, walk: boolean?): boolean
```
Uses a favourite from the ring's menu: walks close to the nearest ring (or `ring`) unless `walk` is false, right clicks it, opens its "Favourites" submenu, picks the code, and waits for the teleport. Errors when the rings can't be used. False when the code isn't a favourite, the interface is open, there is no ring or nothing happened.

## Fairyring.travel_zanaris

Definition:
```luau
function Fairyring.travel_zanaris(ring: Loc?, walk: boolean?): boolean
```
Goes to Zanaris with the ring's own "Zanaris" option on the nearest ring (or `ring`), walking closer first unless `walk` is false, and waits for the teleport. Errors when the rings can't be used and when Lost City is not complete (the quest Zanaris needs). False when the interface is open, there is no ring or nothing happened. `Fairyring.travel("zanaris")` does the same.

## Fairyring.travel

Definition:
```luau
export type Method = "dial" | "log" | "last" | "favourite" | "zanaris"
function Fairyring.travel(text: string, method: Method?, ring: Loc?): Method?
```
Teleports to a destination (a code or a part of a place's name) and waits for the teleport. Errors when the rings can't be used and when the text names no single place. Returns the way it was done, or nil when nothing happened. The text `"zanaris"` (or the method `"zanaris"`) uses the ring's "Zanaris" option, `travel_zanaris`.

The way is picked by chance unless `method` says: `"last"` when the destination is the last code used and the interface is closed (the ring's own option), then `"favourite"` when it is one of the ring's favourites (its menu), else the travel log (chance `LOG_CHANCE`, when it lists the place) or the dials. A way that fails is followed by the dials.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

print("went by", Fairyring.travel("mudskipper"))
print("went by", Fairyring.travel("dkr", "dial"))
```

## Fairyring.Dial

The dials (group 398). Their interface pieces:

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
The click areas turn a dial one step; each dial's position is a varbit from 0 to 3 going clockwise.

Functions:
```luau
function Dial.is_open(): boolean
function Dial.wait_open(timeout_ms: number?): boolean
function Dial.positions(): { number }
function Dial.code(): string?
function Dial.turn(dial: number, clockwise: boolean): boolean
function Dial.set(code: string): boolean
function Dial.confirm(): boolean
function Dial.close_button(): Widget?
function Dial.close(key_probability: number?): boolean
```
`positions` and `code` read where the dials are. `turn` turns one dial one step and waits for it to show. `set` turns the dials to a code, each by the shortest way (a half turn goes either way by chance); true when they spell it. `confirm` presses "Confirm", which teleports, and waits for the interface to go; false when it stayed open (a code with no ring).

## Fairyring.Log

The travel log (group 381, the side tab). It lists the codes used before, each with its place; the list is long, so it scrolls.

Definition:
```luau
export type Destination = { code: string, name: string, visible: boolean, row: Widget }
Log.GROUP = 381
Log.TITLE = 6
Log.LIST = 8
Log.TITLE_TEXT = "Travel log"
Log.OPTION = "Use code"
Log.FIRST_COMPONENT = 12
Log.LAST_COMPONENT = 170
Log.MAX_SCROLLS = 40
Log.OPEN_TIMEOUT_MS = 3000
Log.CONFIRM_TIMEOUT_MS = 4000
Log.POLL_MS = 50
```

Functions:
```luau
function Log.is_open(): boolean
function Log.wait_open(timeout_ms: number?): boolean
function Log.destinations(): { Destination }?
function Log.find(text: string): Destination?
function Log.scroll_to(text: string): Destination?
function Log.select(text: string): boolean
```
`destinations` lists the rows top to bottom (`visible` is whether a row is fully inside the scrolled list). `find` takes a code or a part of a place's name. `scroll_to` scrolls until the row is shown. `select` clicks the row ("Use code"), which **turns the dials to its code but does not teleport** (press `Dial.confirm` for that; `Fairyring.travel` does both). False when the log doesn't list it or the dials didn't turn.

Example:
```luau
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

assert(Fairyring.open())
assert(Fairyring.Log.select("zoo"), "the log has no zoo")
assert(Fairyring.Dial.confirm(), "couldn't confirm")
```
