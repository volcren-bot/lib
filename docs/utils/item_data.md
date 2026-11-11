# Utils.ItemData

Grand Exchange prices, alchemy values and tradeable ids of items, from the game wiki's real-time prices API (`prices.runescape.wiki`) through [Host.item_prices](../host.md). The prices are downloaded on the first call and kept for the run, the latest prices for 10 minutes and the item list for a day, so calling these often doesn't reach the API again. The first call blocks while it downloads.

```luau
local ItemData = require("@lib/utils/item_data")
```

An item is its id or its name, in any case. Every function returns `nil` for an item that isn't traded on the Grand Exchange, and `nil` and why when the prices couldn't be downloaded. An id the API doesn't list, like a noted id, counts as the tradeable item with its name.

## ItemData.price_data

Definition:
```luau
function ItemData.price_data(item: Item): (ItemPrice?, string?)
```
Everything known about an item: its tradeable `id`, `name`, `members`, `value`, `high_alch`, `low_alch`, buy `limit`, and the latest instant-buy `high` and instant-sell `low` prices with their Unix times `high_time` and `low_time` (`nil` when it was never seen bought or sold).

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
function ItemData.tradeable_id(item: Item): (number?, string?)
```
The id the Grand Exchange trades an item under. For a name shared by an untradeable version it is the tradeable one, and for a noted id the unnoted one.

Example:
```luau
local ItemData = require("@lib/utils/item_data")

print(ItemData.tradeable_id("Rune scimitar")) -- 1333
```

## ItemData.price

Definition:
```luau
function ItemData.price(item: Item): (number?, string?)
```
An item's price: halfway between the latest instant-buy and instant-sell prices, rounded down, or whichever of the two is known. Coins are worth 1.

Example:
```luau
local ItemData = require("@lib/utils/item_data")

print(ItemData.price("Abyssal whip"))
```

## ItemData.prices

Definition:
```luau
function ItemData.prices(items: { Item }): ({ number? }?, string?)
```
The prices of many items at once, in the order of `items`, each worked out as in `ItemData.price`. One call for all of them, so use it for a whole inventory or a loot pile.

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
function ItemData.high_alch(item: Item): (number?, string?)
```
The coins High Level Alchemy gives for an item.

Example:
```luau
local ItemData = require("@lib/utils/item_data")

print(ItemData.high_alch("Magic longbow"))
```

## ItemData.low_alch

Definition:
```luau
function ItemData.low_alch(item: Item): (number?, string?)
```
The coins Low Level Alchemy gives for an item.

Example:
```luau
local ItemData = require("@lib/utils/item_data")

print(ItemData.low_alch("Magic longbow"))
```
