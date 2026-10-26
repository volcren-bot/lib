--!strict
local Host = require("../host")

local settings = Host.form({
	title = "Fisher",
	submit = "Start",
	fields = {
		{ kind = "label", text = "Where should we fish?" },
		{ id = "spot", kind = "choice", label = "Spot", options = { "Harpoon", "Cage", "Big net" } },
		{ id = "bank", kind = "check", label = "Bank the fish", default = true },
		{ id = "hours", kind = "number", label = "Run for (hours)", default = 2, min = 0.5, max = 12, step = 0.5 },
		{ id = "breaks", kind = "number", label = "Breaks", default = 3, min = 0, max = 10, integer = true },
		{ id = "note", kind = "text", label = "Note" },
	},
})
if settings == nil then
	print("form cancelled")
	return
end
print(
	`spot {settings.spot}, bank {settings.bank}, hours {settings.hours}, breaks {settings.breaks}, note "{settings.note}"`
)
