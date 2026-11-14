--!strict
local Host = require("@lib/host")
local sleep = Host.sleep
local time = Host.time
local Login = require("@lib/main/interfaces/login/login")
local Player = require("@lib/main/player")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")

local Handoff = {}

Handoff.COMBAT_TIMEOUT_MS = 30000

function Handoff.finishing(): boolean
	return Host.finish_requested()
end

function Handoff.done(reason: string?)
	Host.report_exit("done", reason)
end

function Handoff.blocked(reason: string)
	Host.report_exit("blocked", reason)
end

function Handoff.settle(timeout_ms: number?): (boolean, string?)
	Host.input_cancel()
	if not Player.is_logged_in() and not Login.sign_in() then
		return false, "couldn't log in"
	end
	if Toplevel.has_interface() and not Toplevel.escape_clear() then
		return false, "an interface stayed open"
	end
	local deadline = time() + (timeout_ms or Handoff.COMBAT_TIMEOUT_MS)
	while Player.in_combat() do
		if time() > deadline then
			return false, "still in combat"
		end
		sleep(600)
	end
	return true
end

return Handoff
