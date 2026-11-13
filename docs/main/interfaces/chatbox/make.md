# Main.Interfaces.Chatbox.Make

The "What would you like to make?" menu in the chatbox (fletching, cooking on a fire, ...): item options and a row of quantity buttons. An option's item name is read by hovering it and taking the menu's top entry, so reading options moves the mouse but never clicks.

```luau
local Make = require("@lib/main/interfaces/chatbox/make")
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
The interface (same as [Skillmulti](skillmulti.md)), the quantity button components, the chat query "X" opens, and the hover and select timeouts in milliseconds.

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
`Option.verb` is the menu action ("Make", "Cook"), `name` the item, `id` the component id (`group << 16 | child`). `Amount.selected` marks the current quantity.

## Make.is_open

Definition:
```luau
function Make.is_open(): boolean
```
Whether the menu is open.

Example:
```luau
print("make menu open:", Make.is_open())
```

## Make.wait_open

Definition:
```luau
function Make.wait_open(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (default `SELECT_TIMEOUT`) for the menu to open with its quantity buttons filled in, since the client shows the group a moment before them; logs and returns `false` on timeout.

Example:
```luau
print(Make.wait_open(3000))
```

## Make.wait_closed

Definition:
```luau
function Make.wait_closed(timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (default `SELECT_TIMEOUT`) for the menu to close; logs and returns `false` on timeout.

Example:
```luau
print(Make.wait_closed(2000))
```

## Make.amounts

Definition:
```luau
function Make.amounts(): { Amount }?
```
The visible quantity buttons, left to right. Empty when the menu isn't open.

Example:
```luau
for _, amount in ipairs(Make.amounts() or {}) do
	print(amount.label, amount.selected)
end
```

## Make.amount

Definition:
```luau
function Make.amount(): string?
```
The selected quantity's label ("All", "1", or a custom number), or `nil`.

Example:
```luau
print("quantity:", Make.amount())
```

## Make.set_amount

Definition:
```luau
function Make.set_amount(amount: AmountArg): boolean
```
A label (`"1"`, `"5"`, `"10"`, `"All"`) clicks that button; a number clicks `X` and answers the "Enter amount" query. Buttons depend on how many items you have, and `X` only shows from the `All` state, so a number sets `All` first when needed. Waits for the quantity to read as set. `false` when the button is missing or a custom amount is already selected (its entry would cancel).

Example:
```luau
print(Make.set_amount(10))
```

## Make.set_amount_async

Definition:
```luau
function Make.set_amount_async(label: string, force: boolean?): boolean
```
Queues a click on the button `label` as async input and returns at once, without checking the result. Numbers and `"X"` need `set_amount`. `true` when already selected or queued, `false` when missing. `force` clicks even if selected now.

Example:
```luau
print(Make.set_amount_async("All"))
```

## Make.options

Definition:
```luau
function Make.options(): { Option }?
```
The menu's options, left to right, read by hovering each one. Empty when the menu isn't open; `nil` when a hover isn't confirmed.

Example:
```luau
for _, option in ipairs(Make.options() or {}) do
	print(option.name)
end
```

## Make.option

Definition:
```luau
function Make.option(name: string): Option?
```
The option named `name` (case-insensitive), or `nil`. Hovers every option.

Example:
```luau
local option = Make.option("Oak longbow")
print(option and option.box)
```

## Make.make

Definition:
```luau
function Make.make(name: string, amount: AmountArg?): boolean
```
Sets `amount` if given (see `set_amount`), then clicks the option through `Interact.with`, which returns `false` on a misclick. Returns once clicked, not when the items are made.

Example:
```luau
print(Make.make("Oak shortbow", "All"))
```
