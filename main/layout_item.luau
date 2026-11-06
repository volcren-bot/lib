--!strict
-- The items of equipment and inventory layouts: what counts as one (its ids, or the accepted doses of its family by name) and how much
-- of a stack it wants. A dose or charge item is matched by name, `Prayer potion(4)`, since a family's ids aren't in any order.
local Item = require("@lib/utils/item")

local LayoutItem = {}

-- What both kinds of layout item share; an equipment slot that wants no item has no `id`.
export type Wanted = {
	id: number?,
	ids: { number }?,
	name: string?,
	stackable: boolean?,
	min: number?,
	max: number?,
	doses: { number }?,
}

-- The family of a dose or charge item: its name without the number, `Prayer potion` for `Prayer potion(4)`.
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

-- What counts as the item, in the order the bank takes it: each accepted dose by name, else its ids.
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

-- Whether an item (by id, and name when known) counts as the layout's item.
function LayoutItem.counts_as(item: Wanted, id: number, name: string?): boolean
	local matcher = Item.matcher(LayoutItem.items(item))
	if name == nil and Item.needs_names(matcher) then
		name = Item.name(id)
	end
	return Item.matches(matcher, id, name)
end

-- Whether `have` of a stack is what the item wants: `min` to `max`, or any amount but none when both are 0.
function LayoutItem.in_range(item: Wanted, have: number): boolean
	local min, max = item.min or 0, item.max or 0
	if min == 0 and max == 0 then
		return have > 0
	end
	return have >= min and have <= max
end

-- How many of a stack to take out so it is in range again: up to `max` once below `min`, all of it (0) when both are 0 and there is
-- none, nil when no withdrawal is needed.
function LayoutItem.top_up(item: Wanted, have: number): number?
	local min, max = item.min or 0, item.max or 0
	if min == 0 and max == 0 then
		return if have > 0 then nil else 0
	end
	return if have < min then max - have else nil
end

-- How many of a stack are over its `max`.
function LayoutItem.excess(item: Wanted, have: number): number
	local max = item.max or 0
	return if max > 0 and have > max then have - max else 0
end

return LayoutItem
