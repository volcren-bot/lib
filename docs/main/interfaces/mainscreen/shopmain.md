# Main.Interfaces.Mainscreen.Shopmain

An NPC's shop: the window with its stock, and the inventory the game shows beside it. Reads come from the interface itself, so they work for any shop. Clicks follow the client's entry swaps (see [Minimenu](../minimenu.md#minimenuleft_click_index)): an option the account swapped to the left click is left clicked, any other is picked from the right-click menu.

```luau
local Shopmain = require("@lib/main/interfaces/mainscreen/shopmain")
```

A `Slot` is `{ slot: number, id: number, quantity: number, name: string? }`. `slot` counts from 0 in the shop's order; `quantity` is the stock, 0 when the shop has sold out. Items are given by name or id, like the rest of the lib.

## Constants

Definition:
```luau
Shopmain.GROUP = 300
Shopmain.ITEMS_CHILD = 16
Shopmain.INVENTORY_GROUP = 301
Shopmain.QUANTITIES = { 50, 10, 5, 1 }
Shopmain.OPTION = "Trade"
```
The shop's interface group, the child that holds its stock, the group of the inventory beside it, the amounts the shop's menu sells and buys (largest first) and the NPC option that opens it.

## Shopmain.is_open

Definition:
```luau
function Shopmain.is_open(): boolean
```
Whether the shop window is open.

Example:
```luau
local Shopmain = require("@lib/main/interfaces/mainscreen/shopmain")

print("shop open:", Shopmain.is_open())
```

## Shopmain.wait_open

Definition:
```luau
function Shopmain.wait_open(timeout_ms: number?): boolean
```
Polls `is_open` every 50 ms for up to `timeout_ms` (4 seconds by default).

## Shopmain.open

Definition:
```luau
function Shopmain.open(npc: Npc): (boolean, string?)
```
Trades with the NPC and waits for the shop. `true` at once if it is open already; otherwise `false` and what went wrong.

Example:
```luau
local Host = require("@lib/host")
local Npcs = require("@lib/main/entities/npcs")
local Shopmain = require("@lib/main/interfaces/mainscreen/shopmain")

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
The shop's title, or `nil` when it is closed.

## Shopmain.close_button / Shopmain.close

Definition:
```luau
function Shopmain.close_button(): Widget?
function Shopmain.close(key_probability: number?, timeout_ms: number?): boolean
```
The close button, or `nil` when the shop is closed. `close` closes the shop like `Bankmain.close`: Escape with the chance `key_probability`, then the button, up to 3 times (see `Toplevel.close`). `true` at once when it is closed.

## Shopmain.slots / Shopmain.items

Definition:
```luau
function Shopmain.slots(): { Slot }?
function Shopmain.items(): { Slot }?
```
The shop's stock, in order, sold-out items included. `items` also fills in each `name`. `nil` when the shop is closed.

Example:
```luau
local Shopmain = require("@lib/main/interfaces/mainscreen/shopmain")

for _, s in ipairs(Shopmain.items() or {}) do
	print(s.slot, s.name, s.quantity)
end
```

## Shopmain.index_of / Shopmain.sells

Definition:
```luau
function Shopmain.index_of(items: Item | { Item }): number?
function Shopmain.sells(items: Item | { Item }): boolean
```
The slot of the first matching item, and whether the shop lists one at all (in stock or not).

## Shopmain.stock / Shopmain.in_stock

Definition:
```luau
function Shopmain.stock(items: Item | { Item }): number?
function Shopmain.in_stock(items: Item | { Item }): boolean
```
How many of the matching items the shop holds (0 when it has sold out or doesn't list them; `nil` when it is closed), and whether that is above 0.

Example:
```luau
local Shopmain = require("@lib/main/interfaces/mainscreen/shopmain")

if Shopmain.in_stock("Coal") then
	print("coal left:", Shopmain.stock("Coal"))
end
```

## Shopmain.is_slot_shown / Shopmain.show_slot / Shopmain.box

Definition:
```luau
function Shopmain.is_slot_shown(slot: number): boolean
function Shopmain.show_slot(slot: number): boolean
function Shopmain.box(slot: number): Widget?
```
The stock grid scrolls when the shop sells more than it shows. `is_slot_shown` says whether at least half of the slot is inside the grid, `show_slot` scrolls the mouse wheel over the grid, a few notches at a time, until it is, and `box` is the slot's place clipped to the grid (`nil` when it isn't shown). The scrolling has not been run against a shop longer than one screen.

## Shopmain.hover_slot / Shopmain.interact_slot

Definition:
```luau
function Shopmain.hover_slot(slot: number): boolean
function Shopmain.interact_slot(slot: number, option: string): boolean
```
Scroll to the slot and hover it, or pick one of its menu options (`"Value"`, `"Buy 1"`, `"Buy 5"`, `"Buy 10"`, `"Buy 50"`, `"Examine"`).

## Shopmain.buy_slot / Shopmain.buy

Definition:
```luau
function Shopmain.buy_slot(slot: number, quantity: number): boolean
function Shopmain.buy(item: Item, amount: number?, overshoot: boolean?): number
```
`buy_slot` picks "Buy `quantity`" (one of `QUANTITIES`) on a slot and returns whether the click went through. `buy` buys `amount` (1 by default) of the first matching item, clicking the largest amount that still fits what is left and what the shop holds (with `overshoot` it always clicks the largest, so it may buy more than `amount`, as many as the last click gives), and waits for the inventory to change after each click. It stops when the shop has none left, the inventory has no room (a stack already held still takes more), or a click brings nothing. Returns how many it got.

Example:
```luau
local Shopmain = require("@lib/main/interfaces/mainscreen/shopmain")

local got = Shopmain.buy("Coal", 50)
print("bought", got)
```

## Shopmain.inventory_slots / Shopmain.inventory_box

Definition:
```luau
function Shopmain.inventory_slots(): { Slot }?
function Shopmain.inventory_box(slot: number): Widget?
```
What you carry (the filled slots of container 93), and the widget of an inventory slot in the shop's side panel. `inventory_box` is `nil` when the shop is closed.

## Shopmain.interact_inventory_slot / Shopmain.sell_slot / Shopmain.sell

Definition:
```luau
function Shopmain.interact_inventory_slot(slot: number, option: string): boolean
function Shopmain.sell_slot(slot: number, quantity: number): boolean
function Shopmain.sell(item: Item, amount: number?): number
```
`interact_inventory_slot` picks a menu option on an inventory slot. `sell_slot` picks "Sell `quantity`". `sell` sells `amount` (1 by default) of the first matching carried item the same way `buy` buys, and returns how many it sold. A shop that doesn't take the item answers "You can't sell this item to a shop." and `sell` returns 0.

## Shopmain.value_slot / Shopmain.value_inventory_slot

Definition:
```luau
function Shopmain.value_slot(slot: number): boolean
function Shopmain.value_inventory_slot(slot: number): boolean
```
Pick "Value" on a stock slot or an inventory slot. The price comes back as a game message ("Coal: currently costs 67 coins."), which `Host.chat_messages` lists.

## Shopmain.close_button

Definition:
```luau
function Shopmain.close_button(): Widget?
```
TODO...

Example:
```luau

```

## Shopmain.close

Definition:
```luau
function Shopmain.close(key_probability: number?, timeout_ms: number?): boolean
```
TODO...

Example:
```luau

```

## Shopmain.slots

Definition:
```luau
function Shopmain.slots(): { Slot }?
```
TODO...

Example:
```luau

```

## Shopmain.items

Definition:
```luau
function Shopmain.items(): { Slot }?
```
TODO...

Example:
```luau

```

## Shopmain.index_of

Definition:
```luau
function Shopmain.index_of(items: Item | { Item }): number?
```
TODO...

Example:
```luau

```

## Shopmain.sells

Definition:
```luau
function Shopmain.sells(items: Item | { Item }): boolean
```
TODO...

Example:
```luau

```

## Shopmain.stock

Definition:
```luau
function Shopmain.stock(items: Item | { Item }): number?
```
TODO...

Example:
```luau

```

## Shopmain.in_stock

Definition:
```luau
function Shopmain.in_stock(items: Item | { Item }): boolean
```
TODO...

Example:
```luau

```

## Shopmain.is_slot_shown

Definition:
```luau
function Shopmain.is_slot_shown(slot: number): boolean
```
TODO...

Example:
```luau

```

## Shopmain.show_slot

Definition:
```luau
function Shopmain.show_slot(slot: number): boolean
```
TODO...

Example:
```luau

```

## Shopmain.box

Definition:
```luau
function Shopmain.box(slot: number): Widget?
```
TODO...

Example:
```luau

```

## Shopmain.hover_slot

Definition:
```luau
function Shopmain.hover_slot(slot: number): boolean
```
TODO...

Example:
```luau

```

## Shopmain.interact_slot

Definition:
```luau
function Shopmain.interact_slot(slot: number, option: string): boolean
```
TODO...

Example:
```luau

```

## Shopmain.buy_slot

Definition:
```luau
function Shopmain.buy_slot(slot: number, quantity: number): boolean
```
TODO...

Example:
```luau

```

## Shopmain.buy

Definition:
```luau
function Shopmain.buy(item: Item, amount: number?, overshoot: boolean?): number
```
TODO...

Example:
```luau

```

## Shopmain.inventory_slots

Definition:
```luau
function Shopmain.inventory_slots(): { Slot }?
```
TODO...

Example:
```luau

```

## Shopmain.inventory_box

Definition:
```luau
function Shopmain.inventory_box(slot: number): Widget?
```
TODO...

Example:
```luau

```

## Shopmain.interact_inventory_slot

Definition:
```luau
function Shopmain.interact_inventory_slot(slot: number, option: string): boolean
```
TODO...

Example:
```luau

```

## Shopmain.sell_slot

Definition:
```luau
function Shopmain.sell_slot(slot: number, quantity: number): boolean
```
TODO...

Example:
```luau

```

## Shopmain.sell

Definition:
```luau
function Shopmain.sell(item: Item, amount: number?): number
```
TODO...

Example:
```luau

```

## Shopmain.value_slot

Definition:
```luau
function Shopmain.value_slot(slot: number): boolean
```
TODO...

Example:
```luau

```

## Shopmain.value_inventory_slot

Definition:
```luau
function Shopmain.value_inventory_slot(slot: number): boolean
```
TODO...

Example:
```luau

```
