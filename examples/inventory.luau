--!strict
local Inventory = require("../main/interfaces/gametabs/inventory")

for _, item in ipairs(assert(Inventory.items())) do
	print(`{item.id}={item.name or "?"}`)
end
