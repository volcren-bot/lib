--!strict
local Host = require("../host")
local sleep = Host.sleep
local Mouse = require("../utils/input/mouse")
local Minimenu = require("./interfaces/minimenu")
local Player = require("./player")
local Log = require("../utils/log")
type Target = Mouse.Target
type MenuClick = Host.MenuClick

local Interact = {}

Interact.HOVER_TIMEOUT = 600
-- While walking the scene slides under the mouse, so an option that isn't there soon won't come.
Interact.WALK_HOVER_TIMEOUT = 100

function Interact.wait_option(option: string, target: Minimenu.Target?, timeout_ms: number?): number?
	local timeout = timeout_ms or Interact.HOVER_TIMEOUT
	local waited = 0
	while true do
		local index, entries = Minimenu.find(option, target)
		if entries == nil then
			return nil
		end
		if index then
			return index
		end
		if waited >= timeout then
			Log.log("Interact", `"{option}" never showed up in the menu`)
			return nil
		end
		sleep(50)
		waited += 50
	end
end

function Interact.with(
	at: Target,
	option: string,
	target: Minimenu.Target?,
	walk_timeout_ms: (number | false)?
): (boolean, MenuClick?)
	Mouse.move(at)
	local walking = Player.destination() ~= nil
	local index = Interact.wait_option(option, target, if walking then Interact.WALK_HOVER_TIMEOUT else nil)
	if index == nil then
		return false, nil
	end
	local before = Minimenu.clicked()
	if index == 1 then
		Mouse.click()
	else
		local ok = Minimenu.select(option, target)
		if not ok then
			return ok, nil
		end
	end
	if before ~= nil then
		local clicked = Minimenu.wait_click(before)
		if clicked == nil then
			return false, nil
		end
		if not Minimenu.matches(clicked.entry, option, target) then
			Log.log("Interact", `misclicked: the client did "{Minimenu.text(clicked.entry)}" instead of "{option}"`)
			return false, clicked
		end
	end
	if walk_timeout_ms == false then
		return true, nil
	end
	return Player.wait_walk(if walk_timeout_ms then walk_timeout_ms else nil), nil
end

-- Handles a minimenu left open before an interaction: clicks a row matching `options` for `target` (returns true and whether it went through), otherwise closes it.
function Interact.open_menu(
	options: { string },
	target: Minimenu.Target?,
	walk_timeout_ms: (number | false)?
): (boolean, boolean?)
	if not Minimenu.is_open() then
		return false, nil
	end
	for _, option in ipairs(options) do
		local index = Minimenu.find(option, target)
		local row = if index then Minimenu.row(index) else nil
		if row then
			local before = Minimenu.clicked()
			Mouse.click(row)
			if before ~= nil then
				local clicked = Minimenu.wait_click(before)
				if clicked == nil or not Minimenu.matches(clicked.entry, option, target) then
					Log.log("Interact", `the open menu click didn't do "{option}"`)
					return true, false
				end
			end
			if walk_timeout_ms == false then
				return true, true
			end
			return true, Player.wait_walk(if walk_timeout_ms then walk_timeout_ms else nil)
		end
	end
	if not Minimenu.close() then
		Log.log("Interact", "couldn't close the open menu")
	end
	return false, nil
end

return Interact
