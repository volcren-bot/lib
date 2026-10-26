# Main.Interfaces.Chatbox.Make

The "What would you like to make?" menu in the chatbox. It opens when you use a knife on logs (or logs on a knife), or pick "Cook" on a fire with several things to cook. It lists the items you can make, a row of quantity buttons (`1`, `X`, `All`, ...) and a click on an option makes that item.

Options and buttons are read from the client's widgets, and an option's item name is read by hovering it (the menu's top entry is "Make" on that option, with the item as its target), so nothing is clicked to read them.

```luau
local Make = require("../main/interfaces/chatbox/make")
```

## Constants

Definition:
```luau
Make.GROUP = 270
Make.AMOUNT_CHILDREN = { 7, 8, 9, 10, 11, 12 }
Make.QUERY = "Enter amount"
Make.HOVER_TIMEOUT = 600
Make.SELECT_TIMEOUT = 1500
```
- `GROUP`: the interface group (the same as [Skillmulti](skillmulti.md)).
- `AMOUNT_CHILDREN`: the children of the quantity buttons, in the row above the options.
- `QUERY`: the chat query that "X" opens for the amount.
- `HOVER_TIMEOUT`, `SELECT_TIMEOUT`: how long to wait (milliseconds) for the menu to show a hovered option, and for a quantity to take effect.

## Types

Definition:
```luau
export type Option = {
	verb: string,
	name: string,
	id: number,
	child: number,
	box: Box,
}

export type Amount = {
	label: string,
	id: number,
	box: Box,
	selected: boolean,
}

export type AmountArg = string | number
```
An `Option` is one item the menu offers: `verb` is what the menu calls it ("Make", or "Cook" on a fire), `name` is the item ("Oak shortbow"), `id` its component id (`group << 16 | child`) and `box` where to hover or click it. An `Amount` is one quantity button; `selected` is whether it's the current quantity.

## Make.is_open

Definition:
```luau
function Make.is_open(): boolean
```
Whether the menu is open.

Example:
```luau
local Make = require("../main/interfaces/chatbox/make")

print("make menu open:", Make.is_open())
```

## Make.wait_open

Definition:
```luau
function Make.wait_open(timeout_ms: number?): boolean
```
Waits until the menu opens. `false` (and an error) when it doesn't open within `timeout_ms` (default `SELECT_TIMEOUT`).

Example:
```luau
local Make = require("../main/interfaces/chatbox/make")

print(Make.wait_open(3000))
```

## Make.wait_closed

Definition:
```luau
function Make.wait_closed(timeout_ms: number?): boolean
```
Waits until the menu closes (after an option is picked, for example). `false` when it's still open after `timeout_ms`.

Example:
```luau
local Make = require("../main/interfaces/chatbox/make")

print(Make.wait_closed(2000))
```

## Make.amounts

Definition:
```luau
function Make.amounts(): { Amount }?
```
The quantity buttons on the menu, left to right. Empty when the menu isn't open.

Example:
```luau
local Make = require("../main/interfaces/chatbox/make")

for _, amount in ipairs(Make.amounts() or {}) do
	print(amount.label, amount.selected)
end
```

## Make.amount

Definition:
```luau
function Make.amount(): string?
```
The label of the selected quantity button ("All", "1", ...), or `nil` when none is selected or the menu isn't open.

Example:
```luau
local Make = require("../main/interfaces/chatbox/make")

print("quantity:", Make.amount())
```

## Make.set_amount

Definition:
```luau
function Make.set_amount(amount: AmountArg): boolean
```
Sets the quantity. A label (`"1"`, `"5"`, `"10"`, `"All"`) clicks that button. A number goes through `X` and the "Enter amount" query. Which buttons show depends on how much you have: with few items, `5` and `10` (and `X`, outside the `All` state) can be missing. `X` is only shown from the `All` state, so a number first sets `All` when another amount is set. Once answered, the slot reads that number, which is what this waits for. Returns `true` once the quantity reads as set; `false` with an error when there's no such button, or when the amount is already the selected `X` (its menu entry says "Cancel", which must not be clicked).

Example:
```luau
local Make = require("../main/interfaces/chatbox/make")

print(Make.set_amount("All"))
print(Make.set_amount(10))
```

## Make.set_amount_async

Definition:
```luau
function Make.set_amount_async(label: string, force: boolean?): boolean
```
Queues the click on the amount button `label` (`"1"`, `"5"`, `"10"`, `"All"`) as async input and returns at once. It doesn't check the menu or the result, and `"X"` (which needs the amount query) isn't supported: use `Make.set_amount`. Returns `true` if the button is selected or the click was queued, `false` if there's no such button. `force` clicks even when it is selected now, for an amount that an earlier queued click leaves.

Example:
```luau
local Make = require("../main/interfaces/chatbox/make")

print(Make.set_amount_async("All"))
```

## Make.options

Definition:
```luau
function Make.options(): { Option }?
```
The options on the menu, left to right. Each name is read by hovering the option, so this moves the mouse over every option. Empty when the menu isn't open.

Example:
```luau
local Make = require("../main/interfaces/chatbox/make")

for _, option in ipairs(Make.options() or {}) do
	print(option.name)
end
```

## Make.option

Definition:
```luau
function Make.option(name: string): Option?
```
The option whose item is `name` (not case sensitive). `nil` with an error when the menu doesn't offer it.

Example:
```luau
local Make = require("../main/interfaces/chatbox/make")

local option = Make.option("Oak longbow")
print(option and option.box)
```

## Make.make

Definition:
```luau
function Make.make(name: string, amount: AmountArg?): boolean
```
Makes the item `name`: sets the quantity to `amount` first (see `set_amount`), if given, then clicks the option. The click is checked like `Interact.with` does, so a misclick returns `false` with the error. It returns once the click is made; the client takes time to make the items, so wait for them (with the inventory or the chat) afterwards.

Example:
```luau
local Make = require("../main/interfaces/chatbox/make")

print(Make.make("Oak shortbow", "All"))
print(Make.wait_closed(5000))
```
