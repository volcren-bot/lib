# Main.Interfaces.Mainscreen.ItemRetrieval

The item retrieval interface: what a death left behind with a keeper, opened by "Collect" on Priestess Zul-Gwenwynig after a death at Zulrah (group 602, `gravestone_retrieval` in the cache).

```luau
local ItemRetrieval = require("@lib/main/interfaces/mainscreen/itemretrieval")
```

The kept stacks are item container 525, shown in a grid (child 3), one cell per container slot. Each cell offers "Take-All <item>", "Value" and "Examine". Below the grid, the Take-All button (child 6) takes everything, a text (child 14) says `Stack count: 21` and `Guide value: 123,271,428 (approximately)`, and **"Discard-All" (child 10) deletes the items for good: nothing in this module clicks it**.

The keeper charges a fee, and until it is paid the items are locked: the button offers the fee's option first (clicking it pays, the game taking the coins from the bank), and Take-All only after. A first death's items came unlocked. Seen with 21 stacks and 27 free inventory slots: Take-All put the worn items back on and the rest in the inventory, and closed the interface once it was empty. With nothing kept, "Collect" opens nothing. What Take-All does with less room than stacks hasn't been seen; `take_all` is true once fewer stacks are kept.

Priestess Zul-Gwenwynig changes form, and the NPC list has no name for her (`Npcs` finds her by id, 2124).

## Constants

Definition:
```luau
ItemRetrieval.GROUP = 602
ItemRetrieval.CONTAINER = 525
ItemRetrieval.FRAME = 1
ItemRetrieval.TITLE_INDEX = 1
ItemRetrieval.CLOSE_INDEX = 11
ItemRetrieval.GRID = 3
ItemRetrieval.TAKE_ALL = 6
ItemRetrieval.SUMMARY = 14
ItemRetrieval.TAKE_OPTION = "Take-All"
ItemRetrieval.OPEN_TIMEOUT_MS = 3000
ItemRetrieval.HOVER_TIMEOUT_MS = 800
ItemRetrieval.TAKE_TIMEOUT_MS = 4000
ItemRetrieval.UNLOCK_TIMEOUT_MS = 4000
ItemRetrieval.POLL_MS = 50
ItemRetrieval.SETTLE_MS = 150
```
The interface and its container; the frame and the indices of the title and the close button among its children; the grid, the Take-All button and the summary text; the option that takes; and the waits: for `wait_open`, for a hover to show the menu, for a click to take something, for the fee's click to unlock Take-All, between looks, and for the menu to follow the mouse.

## ItemRetrieval.is_open

Definition:
```luau
function ItemRetrieval.is_open(): boolean
```
Whether the interface is open.

## ItemRetrieval.wait_open

Definition:
```luau
function ItemRetrieval.wait_open(timeout_ms: number?): boolean
```
Whether the interface is open, polled for up to `timeout_ms` (3 seconds by default).

## ItemRetrieval.title

Definition:
```luau
function ItemRetrieval.title(): string?
```
The title (`Zul-Gwenwynig's Item Retrieval Service`), nil when the interface isn't open.

## ItemRetrieval.items

Definition:
```luau
function ItemRetrieval.items(): { ItemSlot }?
```
The kept stacks (`slot`, `id`, `quantity`), slot 0 first; nil when the interface isn't open.

## ItemRetrieval.count

Definition:
```luau
function ItemRetrieval.count(): number?
```
How many stacks are kept; nil when the interface isn't open.

## ItemRetrieval.value

Definition:
```luau
function ItemRetrieval.value(): number?
```
The interface's "Guide value" of the kept items, nil when it isn't open or shows none.

## ItemRetrieval.cell

Definition:
```luau
function ItemRetrieval.cell(slot: number): Widget?
```
The grid cell showing container slot `slot`, nil when it isn't shown.

## ItemRetrieval.slot

Definition:
```luau
function ItemRetrieval.slot(item: Item.Item | { Item.Item }): number?
```
The container slot of the first kept stack of `item` (ids or names), nil when none is kept.

## ItemRetrieval.take_all

Definition:
```luau
function ItemRetrieval.take_all(): boolean
```
Clicks the Take-All button, after checking the menu offers it. While the items are locked the button offers the fee first: an option naming unlocking or paying is clicked, and Take-All once the button offers it (any other option is logged and not clicked). True once fewer stacks are kept, and at once when none is.

## ItemRetrieval.take

Definition:
```luau
function ItemRetrieval.take(item: Item.Item | { Item.Item }): boolean
```
Takes the first kept stack of `item` from its cell ("Take-All" on the cell). False when none is kept or nothing was taken.

## ItemRetrieval.close_button

Definition:
```luau
function ItemRetrieval.close_button(): Widget?
```
The close button, nil when the interface isn't open.

## ItemRetrieval.close

Definition:
```luau
function ItemRetrieval.close(key_probability: number?): boolean
```
Closes the interface, leaving what is still kept: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.
