# Utils.Item

Describing items by id or by name, including ranges like `"Potion (1..4)"`, and checking whether an item matches.

```luau
local Item = require("../utils/item")
```

An item is either its id (a number) or its name (a text).

## Item.name

Definition:
```luau
function Item.name(id: number): string?
```
The name of an item from its id.

Example:
```luau
local Item = require("../utils/item")

print(Item.name(995))
```

## Item.names

Definition:
```luau
function Item.names(ids: { number }): { string? }?
```
The names of many items at once.

Example:
```luau
local Item = require("../utils/item")

for _, name in ipairs(Item.names({ 995, 554, 555 }) or {}) do
	print(name)
end
```

## Item.has_amount

Definition:
```luau
function Item.has_amount(item: string): boolean
```
Whether an item name ends with a bracket, like `"Potion (3)"`. Items with doses or charges look like this.

Example:
```luau
local Item = require("../utils/item")

print(Item.has_amount("Potion (3)")) -- true
print(Item.has_amount("Logs")) -- false
```

## Item.spread

Definition:
```luau
function Item.spread(item: Item): { Item }
```
Expands a range such as `"Potion (1..4)"` into `"Potion (1)"`, `"Potion (2)"`, `"Potion (3)"`, `"Potion (4)"`. Anything else comes back as a one-item list.

Example:
```luau
local Item = require("../utils/item")

print(table.concat(Item.spread("Potion (1..4)") :: { string }, ", "))
```

## Item.matcher

Definition:
```luau
function Item.matcher(items: Item | { Item }): Matcher
```
Builds a quick lookup out of one item or a list of items (ids, names and ranges). Use it with `Item.matches`.

Example:
```luau
local Item = require("../utils/item")

local wanted = Item.matcher({ 995, "Logs", "Potion (1..4)" })
print(Item.matches(wanted, 995, nil)) -- true
```

## Item.needs_names

Definition:
```luau
function Item.needs_names(matcher: Matcher): boolean
```
Whether the matcher contains any names. If not, you can match using ids only and skip looking names up.

Example:
```luau
local Item = require("../utils/item")

print(Item.needs_names(Item.matcher({ 995 }))) -- false
print(Item.needs_names(Item.matcher({ "Logs" }))) -- true
```

## Item.matches

Definition:
```luau
function Item.matches(matcher: Matcher, id: number, name: string?): boolean
```
Whether an item (given by id and, if known, name) is one of the items in the matcher. Names are compared ignoring upper/lower case.

Example:
```luau
local Item = require("../utils/item")

local wanted = Item.matcher({ "Logs" })
print(Item.matches(wanted, 1511, "Logs")) -- true
print(Item.matches(wanted, 995, "Coins")) -- false
```
