--!strict
local Item = require("@lib/utils/item")

local LayoutItem = {}

export type Wanted = {
	id: number?,
	ids: { number }?,
	name: string?,
	stackable: boolean?,
	min: number?,
	max: number?,
	doses: { number }?,
}

function LayoutItem.base(item: Wanted): string?
	local name = item.name
	if (name == nil or name == "") and item.id then
		name = Item.name(item.id :: number)
	end
	if name == nil then
		return nil
	end
	return string.match(name, "^(.+)%(%d+%)$")
end

function LayoutItem.items(item: Wanted): { Item.Item }
	local doses = item.doses
	local base = if doses and #doses > 0 then LayoutItem.base(item) else nil
	local list: { Item.Item } = {}
	if base and doses then
		for _, dose in ipairs(doses) do
			table.insert(list, `{base}({dose})`)
		end
		return list
	end
	for _, id in ipairs(item.ids or {}) do
		table.insert(list, id)
	end
	if #list == 0 and item.id then
		table.insert(list, item.id :: number)
	end
	return list
end

function LayoutItem.counts_as(item: Wanted, id: number, name: string?): boolean
	local matcher = Item.matcher(LayoutItem.items(item))
	if name == nil and Item.needs_names(matcher) then
		name = Item.name(id)
	end
	return Item.matches(matcher, id, name)
end

function LayoutItem.in_range(item: Wanted, have: number): boolean
	local min, max = item.min or 0, item.max or 0
	if min == 0 and max == 0 then
		return have > 0
	end
	return have >= min and have <= max
end

function LayoutItem.top_up(item: Wanted, have: number): number?
	local min, max = item.min or 0, item.max or 0
	if min == 0 and max == 0 then
		return if have > 0 then nil else 0
	end
	return if have < min then max - have else nil
end

function LayoutItem.excess(item: Wanted, have: number): number
	local max = item.max or 0
	return if max > 0 and have > max then have - max else 0
end

return LayoutItem
