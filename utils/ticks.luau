--!strict
local Host = require("../host")
local Log = require("./log")
local game_state = Host.game_state
local sleep = Host.sleep
local Ticks = {}

Ticks.MS = 600
Ticks.POLL_MS = 50

function Ticks.current(): number?
	local state = game_state()
	return state.tick_count
end

function Ticks.wait(count: number?, timeout_ms: number?): number?
	local wanted = count or 1
	local start = Ticks.current()
	if start == nil then
		return nil
	end
	local timeout = timeout_ms or (wanted * Ticks.MS * 2)
	local waited = 0
	while waited < timeout do
		sleep(Ticks.POLL_MS)
		waited += Ticks.POLL_MS
		local now = Ticks.current()
		if now == nil then
			return nil
		end
		if now - start >= wanted or now < start then
			return now
		end
	end
	Log.log("Ticks", "no new tick within " .. tostring(timeout) .. " ms (logged out?)")
	return nil
end

return Ticks
