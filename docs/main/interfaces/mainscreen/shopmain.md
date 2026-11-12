# Main.Interfaces.Mainscreen.Shopmain

An NPC shop (group 300) and the inventory shown beside it (group 301). Reads come from the interface, so they work for any shop. Clicks follow the client's entry swaps (see [Minimenu](../minimenu.md#minimenuleft_click_index)): a swapped-in left-click option is left clicked, anything else is picked from the menu.

A `Slot` is `{ slot, id, quantity, name? }`: `slot` counts from 0 in shop order, `quantity` is the stock (0 when sold out). Items are names or ids.

```luau
local Shopmain = require("@lib/main/interfaces/mainscreen/shopmain")
```

## Constants

Definition:
```luau
Shopmain.GROUP = 300
Shopmain.ITEMS_CHILD = 16
Shopmain.INVENTORY_GROUP = 301
Shopmain.QUANTITIES = { 50, 10, 5, 1 }
Shopmain.OPTION = "Trade"
```
The shop group, its stock child, the side inventory group, the buy/sell menu amounts (largest first) and the usual NPC option.

## Shopmain.is_open

Definition:
```luau
function Shopmain.is_open(): boolean
```
Whether the shop is open.

Example:
```luau
print(Shopmain.is_open())
```

## Shopmain.wait_open

Definition:
```luau
function Shopmain.wait_open(timeout_ms: number?): boolean
```
Polls `is_open` every 50 ms up to `timeout_ms` (4000 by default).

Example:
```luau
Shopmain.wait_open()
```

## Shopmain.open

Definition:
```luau
function Shopmain.open(npc: Npc): (boolean, string?)
```
Picks "Trade" (or "Talk-to") on `npc` without walking and waits for the shop. `true` at once if open; otherwise `false` and a reason.

Example:
```luau
local Host = require("@lib/host")
local Npcs = require("@lib/main/entities/npcs")

local npc = Npcs.nearest("Ordan", Host.game_state().position)
if npc and Shopmain.open(npc) then
	print(Shopmain.title())
end
```

## Shopmain.title

Definition:
```luau
function Shopmain.title(): string?
```
The shop's title, `nil` when closed.

Example:
```luau
print(Shopmain.title())
```

## Shopmain.close_button

Definition:
```luau
function Shopmain.close_button(): Widget?
```
The close button, `nil` when closed or hidden.

Example:
```luau
local button = Shopmain.close_button()
```

## Shopmain.close

Definition:
```luau
function Shopmain.close(key_probability: number?, timeout_ms: number?): boolean
```
Closes the shop via `Toplevel.close` (Escape with chance `key_probability`, then the button). `true` at once when closed.

Example:
```luau
Shopmain.close()
```

## Shopmain.slots

Definition:
```luau
function Shopmain.slots(): { Slot }?
```
The stock in order, sold-out items included, without names. `nil` when closed.

Example:
```luau
print(#(Shopmain.slots() or {}))
```

## Shopmain.items

Definition:
```luau
function Shopmain.items(): { Slot }?
```
`slots` with each `name` filled in.

Example:
```luau
for _, s in ipairs(Shopmain.items() or {}) do
	print(s.slot, s.name, s.quantity)
end
```

## Shopmain.index_of

Definition:
```luau
function Shopmain.index_of(items: Item | { Item }): number?
```
The slot of the first matching item, in stock or not.

Example:
```luau
print(Shopmain.index_of("Coal"))
```

## Shopmain.sells

Definition:
```luau
function Shopmain.sells(items: Item | { Item }): boolean
```
Whether the shop lists a matching item, in stock or not.

Example:
```luau
print(Shopmain.sells("Coal"))
```

## Shopmain.stock

Definition:
```luau
function Shopmain.stock(items: Item | { Item }): number?
```
Total stock of matching items (0 when sold out or not listed), `nil` when closed.

Example:
```luau
print(Shopmain.stock("Coal"))
```

## Shopmain.in_stock

Definition:
```luau
function Shopmain.in_stock(items: Item | { Item }): boolean
```
Whether `stock` is above 0.

Example:
```luau
print(Shopmain.in_stock("Coal"))
```

## Shopmain.is_slot_shown

Definition:
```luau
function Shopmain.is_slot_shown(slot: number): boolean
```
Whether at least half of the slot is inside the scrolling stock grid.

Example:
```luau
print(Shopmain.is_slot_shown(30))
```

## Shopmain.show_slot

Definition:
```luau
function Shopmain.show_slot(slot: number): boolean
```
Scrolls the wheel over the grid 1-3 notches at a time (up to 12 tries) until the slot is shown. Untested on shops longer than one screen.

Example:
```luau
Shopmain.show_slot(30)
```

## Shopmain.box

Definition:
```luau
function Shopmain.box(slot: number): Widget?
```
The slot's widget clipped to the grid, `nil` when not shown.

Example:
```luau
local w = Shopmain.box(0)
```

## Shopmain.hover_slot

Definition:
```luau
function Shopmain.hover_slot(slot: number): boolean
```
Scrolls to the slot and hovers it.

Example:
```luau
Shopmain.hover_slot(0)
```

## Shopmain.interact_slot

Definition:
```luau
function Shopmain.interact_slot(slot: number, option: string): boolean
```
Scrolls to the slot and picks `option` ("Value", "Buy 1", "Buy 5", "Buy 10", "Buy 50", "Examine").

Example:
```luau
Shopmain.interact_slot(0, "Examine")
```

## Shopmain.buy_slot

Definition:
```luau
function Shopmain.buy_slot(slot: number, quantity: number): boolean
```
Picks "Buy `quantity`" (one of `QUANTITIES`) on a slot; `true` if the click went through.

Example:
```luau
Shopmain.buy_slot(0, 10)
```

## Shopmain.buy

Definition:
```luau
function Shopmain.buy(item: Item, amount: number?, overshoot: boolean?): number
```
Buys `amount` (default 1), each click the largest of `QUANTITIES` that fits what is left and in stock (`overshoot` always uses 50, possibly buying more), waiting up to 2400 ms for the inventory after each. Stops when sold out, the inventory is full (unless adding to a held stack) or a click gains nothing. Returns how many were bought.

Example:
```luau
print(Shopmain.buy("Coal", 50))
```

## Shopmain.inventory_slots

Definition:
```luau
function Shopmain.inventory_slots(): { Slot }?
```
The filled inventory slots (container 93), without names.

Example:
```luau
print(#(Shopmain.inventory_slots() or {}))
```

## Shopmain.inventory_box

Definition:
```luau
function Shopmain.inventory_box(slot: number): Widget?
```
The widget of an inventory slot in the shop's side panel, `nil` when closed or hidden.

Example:
```luau
local w = Shopmain.inventory_box(0)
```

## Shopmain.interact_inventory_slot

Definition:
```luau
function Shopmain.interact_inventory_slot(slot: number, option: string): boolean
```
Picks `option` on an inventory slot in the side panel.

Example:
```luau
Shopmain.interact_inventory_slot(0, "Sell 1")
```

## Shopmain.sell_slot

Definition:
```luau
function Shopmain.sell_slot(slot: number, quantity: number): boolean
```
Picks "Sell `quantity`" on an inventory slot.

Example:
```luau
Shopmain.sell_slot(0, 5)
```

## Shopmain.sell

Definition:
```luau
function Shopmain.sell(item: Item, amount: number?): number
```
Sells `amount` (default 1) of the first matching carried item, choosing click sizes like `buy`. Returns how many were sold; 0 when the shop refuses the item ("You can't sell this item to a shop.").

Example:
```luau
print(Shopmain.sell("Iron ore", 10))
```

## Shopmain.value_slot

Definition:
```luau
function Shopmain.value_slot(slot: number): boolean
```
Picks "Value" on a stock slot; the price arrives as a game message (see `Host.chat_messages`).

Example:
```luau
Shopmain.value_slot(0)
```

## Shopmain.value_inventory_slot

Definition:
```luau
function Shopmain.value_inventory_slot(slot: number): boolean
```
Picks "Value" on an inventory slot; the price arrives as a game message.

Example:
```luau
Shopmain.value_inventory_slot(0)
```
