# Utils.ItemData

Grand Exchange prices, alchemy values and tradeable ids via [Host.item_prices](../host.md), which caches per run, so frequent calls are cheap; the first blocks on the download.

```luau
local ItemData = require("@lib/utils/item_data")
```

An item is an id or a case-insensitive name; unlisted ids (noted) count as the tradeable item of that name. Every function returns nil for untraded items, and nil plus a reason when the download failed.

## ItemData.price_data

Definition:
```luau
function ItemData.price_data(item: Item.Item): (ItemPrice?, string?)
```
The full `Host.ItemPrice` record (`high`/`low` nil when never traded).

Example:
```luau
local ItemData = require("@lib/utils/item_data")

local data = ItemData.price_data("Abyssal whip")
if data then
	print(`high {data.high} low {data.low} limit {data.limit}`)
end
```

## ItemData.tradeable_id

Definition:
```luau
function ItemData.tradeable_id(item: Item.Item): (number?, string?)
```
The id the Grand Exchange trades the item under (unnoted, tradeable variant).

Example:
```luau
local ItemData = require("@lib/utils/item_data")

print(ItemData.tradeable_id("Rune scimitar")) -- 1333
```

## ItemData.price

Definition:
```luau
function ItemData.price(item: Item.Item): (number?, string?)
```
Floor of the mean of latest `high` and `low`, or whichever is known. Coins are 1.

Example:
```luau
local ItemData = require("@lib/utils/item_data")

print(ItemData.price("Abyssal whip"))
```

## ItemData.prices

Definition:
```luau
function ItemData.prices(items: { Item.Item }): ({ number? }?, string?)
```
`ItemData.price` for many items in one call, in order.

Example:
```luau
local ItemData = require("@lib/utils/item_data")

local total = 0
for _, price in ipairs(ItemData.prices({ 995, "Abyssal whip", 1333 }) or {}) do
	total += price or 0
end
print(total)
```

## ItemData.high_alch

Definition:
```luau
function ItemData.high_alch(item: Item.Item): (number?, string?)
```
High Level Alchemy value.

Example:
```luau
local ItemData = require("@lib/utils/item_data")

print(ItemData.high_alch("Magic longbow"))
```

## ItemData.low_alch

Definition:
```luau
function ItemData.low_alch(item: Item.Item): (number?, string?)
```
Low Level Alchemy value.

Example:
```luau
local ItemData = require("@lib/utils/item_data")

print(ItemData.low_alch("Magic longbow"))
```
