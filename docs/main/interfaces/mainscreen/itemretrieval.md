# Main.Interfaces.Mainscreen.ItemRetrieval

The item retrieval interface (group 602): items a death left with a keeper, opened by "Collect" on Priestess Zul-Gwenwynig after a Zulrah death (find her by NPC id 2124; she has no name in the NPC list).

```luau
local ItemRetrieval = require("@lib/main/interfaces/mainscreen/itemretrieval")
```

Kept stacks are item container 525, one grid cell per slot. Until the keeper's fee is paid, the Take-All button offers the fee option first (paid from the bank). **"Discard-All" (child 10) deletes the items; nothing here clicks it.** With nothing kept, "Collect" opens nothing. Behaviour with fewer free slots than stacks hasn't been observed.

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
Group and container; frame plus the title and close button's child indices; grid, Take-All button and summary text components; the take option; and wait lengths.

## ItemRetrieval.is_open

Definition:
```luau
function ItemRetrieval.is_open(): boolean
```
Whether the interface is open.

Example:
```luau
print(ItemRetrieval.is_open())
```

## ItemRetrieval.wait_open

Definition:
```luau
function ItemRetrieval.wait_open(timeout_ms: number?): boolean
```
Polls `is_open` for up to `timeout_ms` (default `OPEN_TIMEOUT_MS`).

Example:
```luau
print(ItemRetrieval.wait_open())
```

## ItemRetrieval.title

Definition:
```luau
function ItemRetrieval.title(): string?
```
The title (`Zul-Gwenwynig's Item Retrieval Service`), nil when the interface isn't open.

Example:
```luau
print(ItemRetrieval.title())
```

## ItemRetrieval.items

Definition:
```luau
function ItemRetrieval.items(): { ItemSlot }?
```
The kept stacks (`slot`, `id`, `quantity`), slot 0 first; nil when the interface isn't open.

Example:
```luau
for _, kept in ipairs(ItemRetrieval.items() or {}) do
	print(kept.slot, kept.id, kept.quantity)
end
```

## ItemRetrieval.count

Definition:
```luau
function ItemRetrieval.count(): number?
```
How many stacks are kept; nil when the interface isn't open.

Example:
```luau
print(ItemRetrieval.count())
```

## ItemRetrieval.value

Definition:
```luau
function ItemRetrieval.value(): number?
```
The interface's "Guide value" of the kept items, nil when it isn't open or shows none.

Example:
```luau
print(ItemRetrieval.value())
```

## ItemRetrieval.cell

Definition:
```luau
function ItemRetrieval.cell(slot: number): Widget?
```
The grid cell showing container slot `slot`, nil when it isn't shown.

Example:
```luau
local cell = ItemRetrieval.cell(0)
```

## ItemRetrieval.slot

Definition:
```luau
function ItemRetrieval.slot(item: Item.Item | { Item.Item }): number?
```
The container slot of the first kept stack of `item` (ids or names), nil when none is kept.

Example:
```luau
print(ItemRetrieval.slot("Rune platebody"))
```

## ItemRetrieval.take_all

Definition:
```luau
function ItemRetrieval.take_all(): boolean
```
Clicks the Take-All button. If it offers an option containing "unlock" or "pay", clicks that first (spending coins) and waits for Take-All; any other option is logged and not clicked. True once fewer stacks are kept, or at once when none are.

Example:
```luau
if ItemRetrieval.wait_open() then
	ItemRetrieval.take_all()
end
```

## ItemRetrieval.take

Definition:
```luau
function ItemRetrieval.take(item: Item.Item | { Item.Item }): boolean
```
Clicks "Take-All" on the cell of the first kept stack of `item`. False when none is kept or nothing was taken.

Example:
```luau
ItemRetrieval.take({ "Toxic blowpipe", "Trident of the swamp" })
```

## ItemRetrieval.close_button

Definition:
```luau
function ItemRetrieval.close_button(): Widget?
```
The close button, nil when the interface isn't open.

Example:
```luau
print(ItemRetrieval.close_button() ~= nil)
```

## ItemRetrieval.close

Definition:
```luau
function ItemRetrieval.close(key_probability: number?): boolean
```
Closes the interface, leaving the rest kept, by Escape (chance `key_probability`, nil or 0 uses the biometric default) or the close button; see [Toplevel.close](toplevel.md).

Example:
```luau
ItemRetrieval.close(0.5)
```
