--!strict
local Host = require("@lib/host")

local settings = Host.settings()
print(
	`spot {settings.spot}, bank {settings.bank}, hours {settings.hours}, breaks {settings.breaks}, note "{settings.note}"`
)
