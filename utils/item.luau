--!strict
local Host = require("@lib/host")
local item_name = Host.item_name
local item_names = Host.item_names

export type Item = number | string

export type Matcher = {
	ids: { [number]: boolean },
	names: { [string]: boolean },
}

local Item = {}

-- an item's name never changes during a run, so each id is asked of the client once
local known: { [number]: string } = {}

function Item.name(id: number): string?
	local name = known[id]
	if name == nil then
		name = item_name(id)
		if name ~= nil then
			known[id] = name
		end
	end
	return name
end

function Item.names(ids: { number }): { string? }?
	local names: { string? } = {}
	local missing: { number } = {}
	local at: { number } = {}
	for i, id in ipairs(ids) do
		local name = known[id]
		if name ~= nil then
			names[i] = name
		else
			table.insert(missing, id)
			table.insert(at, i)
		end
	end
	if #missing == 0 then
		return names
	end
	local found = item_names(missing)
	if found == nil then
		return nil
	end
	for j, i in ipairs(at) do
		local name = found[j]
		if name ~= nil then
			known[missing[j]] = name
		end
		names[i] = name
	end
	return names
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
