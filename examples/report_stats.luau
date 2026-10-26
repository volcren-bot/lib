--!strict
-- Reports the experience the player gains to Volcren every 15 seconds and prints what was sent.
-- In the editor the numbers are dropped, in a store run they end up in the script's totals.
local Host = require("../host")
local StatsReport = require("../utils/stats_report")

local tracker = StatsReport.new(15000)
local sent = 0
while true do
	local state = Host.game_state()
	local before = tracker.xp
	if StatsReport.update(tracker, state.skills) then
		sent += 1
		print(`report {sent}: {before} xp`)
	end
	Host.sleep(600)
end
