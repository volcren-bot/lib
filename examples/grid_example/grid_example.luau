--!strict
local Host = require("@lib/host")

local settings = Host.settings()

local function print_grid(name: string, picks: { [string]: string })
	local by_column: { [string]: { string } } = {}
	for item, column in picks do
		local items = by_column[column] or {}
		table.insert(items, item)
		by_column[column] = items
	end
	for column, items in by_column do
		table.sort(items)
		print(`{name} {column}: {table.concat(items, ", ")}`)
	end
end

print_grid("tasks", settings.tasks)
print_grid("loot", settings.loot)
