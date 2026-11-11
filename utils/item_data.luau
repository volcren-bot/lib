--!strict
local Host = require("@lib/host")
local Item = require("@lib/utils/item")

export type ItemPrice = Host.ItemPrice

local ItemData = {}

local COINS = 995

local function is_coins(item: Item.Item): boolean
	return item == COINS or (type(item) == "string" and string.lower(item) == "coins")
end

local function average(data: ItemPrice): number?
	local high, low = data.high, data.low
	if high ~= nil and low ~= nil then
		return math.floor((high + low) / 2)
	end
	return high or low
end

function ItemData.price_data(item: Item.Item): (ItemPrice?, string?)
	local found, err = Host.item_prices({ item })
	if found == nil then
		return nil, err
	end
	return found[1], nil
end

function ItemData.tradeable_id(item: Item.Item): (number?, string?)
	local data, err = ItemData.price_data(item)
	return data and data.id, err
end

function ItemData.price(item: Item.Item): (number?, string?)
	if is_coins(item) then
		return 1, nil
	end
	local data, err = ItemData.price_data(item)
	if data == nil then
		return nil, err
	end
	return average(data), nil
end

function ItemData.prices(items: { Item.Item }): ({ number? }?, string?)
	local found, err = Host.item_prices(items)
	if found == nil then
		return nil, err
	end
	local prices: { number? } = {}
	for i, item in ipairs(items) do
		local data = found[i]
		prices[i] = if is_coins(item) then 1 elseif data ~= nil then average(data) else nil
	end
	return prices, nil
end

function ItemData.high_alch(item: Item.Item): (number?, string?)
	local data, err = ItemData.price_data(item)
	return data and data.high_alch, err
end

function ItemData.low_alch(item: Item.Item): (number?, string?)
	local data, err = ItemData.price_data(item)
	return data and data.low_alch, err
end

return ItemData
