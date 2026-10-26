--!strict
local Host = require("../host")
local item_name = Host.item_name
local item_names = Host.item_names

export type Item = number | string

export type Matcher = {
	ids: { [number]: boolean },
	names: { [string]: boolean },
}

local Item = {}

function Item.name(id: number): string?
	return item_name(id)
end

function Item.names(ids: { number }): { string? }?
	return item_names(ids)
end

function Item.has_amount(item: string): boolean
	return string.sub(item, -1) == ")"
end

function Item.spread(item: Item): { Item }
	if type(item) ~= "string" then
		return { item }
	end
	local name, first, last = string.match(item, "^(.*%()(%d+)%.%.(%d+)%)$")
	if name == nil or first == nil or last == nil then
		return { item }
	end
	local from, to = tonumber(first) :: number, tonumber(last) :: number
	local items: { Item } = {}
	for i = from, to, if from <= to then 1 else -1 do
		table.insert(items, `{name}{i})`)
	end
	return items
end

function Item.matcher(items: Item | { Item }): Matcher
	local list: { Item } = if type(items) == "table" then items else { items }
	local matcher: Matcher = { ids = {}, names = {} }
	for _, item in ipairs(list) do
		for _, one in ipairs(Item.spread(item)) do
			local id = tonumber(one)
			if id then
				matcher.ids[id] = true
			else
				matcher.names[string.lower(one :: string)] = true
			end
		end
	end
	return matcher
end

function Item.needs_names(matcher: Matcher): boolean
	return next(matcher.names) ~= nil
end

function Item.matches(matcher: Matcher, id: number, name: string?): boolean
	return matcher.ids[id] == true or (name ~= nil and matcher.names[string.lower(name)] == true)
end

return Item
