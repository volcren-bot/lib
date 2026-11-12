# Utils.Item

Items by id or name, ranges like `"Potion (1..4)"`, and matching. An `Item` is an id (number) or a name (string).

```luau
local Item = require("@lib/utils/item")
```

## Item.name

Definition:
```luau
function Item.name(id: number): string?
```
An item's name.

Example:
```luau
local Item = require("@lib/utils/item")

print(Item.name(995))
```

## Item.names

Definition:
```luau
function Item.names(ids: { number }): { string? }?
```
Names of many items.

Example:
```luau
local Item = require("@lib/utils/item")

for _, name in ipairs(Item.names({ 995, 554, 555 }) or {}) do
	print(name)
end
```

## Item.has_amount

Definition:
```luau
function Item.has_amount(item: string): boolean
```
Whether the name ends in a bracket, like dose or charge items (`"Potion (3)"`).

Example:
```luau
local Item = require("@lib/utils/item")

print(Item.has_amount("Potion (3)")) -- true
```

## Item.spread

Definition:
```luau
function Item.spread(item: Item): { Item }
```
Expands `"Potion (1..4)"` into `"Potion (1)"` to `"Potion (4)"`; anything else becomes a one-item list.

Example:
```luau
local Item = require("@lib/utils/item")

print(table.concat(Item.spread("Potion (1..4)") :: { string }, ", "))
```

## Item.matcher

Definition:
```luau
function Item.matcher(items: Item | { Item }): Matcher
```
Builds a lookup from items (ids, names, ranges) for `Item.matches`.

Example:
```luau
local Item = require("@lib/utils/item")

local wanted = Item.matcher({ 995, "Logs", "Potion (1..4)" })
print(Item.matches(wanted, 995, nil)) -- true
```

## Item.needs_names

Definition:
```luau
function Item.needs_names(matcher: Matcher): boolean
```
Whether the matcher has names; if not, matching needs no name lookups.

Example:
```luau
local Item = require("@lib/utils/item")

print(Item.needs_names(Item.matcher({ "Logs" }))) -- true
```

## Item.matches

Definition:
```luau
function Item.matches(matcher: Matcher, id: number, name: string?): boolean
```
Whether the item (id, optional name) is in the matcher; names are case-insensitive.

Example:
```luau
local Item = require("@lib/utils/item")

local wanted = Item.matcher({ "Logs" })
print(Item.matches(wanted, 1511, "Logs")) -- true
```
