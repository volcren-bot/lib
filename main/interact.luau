--!strict
local Host = require("@lib/host")
local sleep = Host.sleep
local Log = require("@lib/utils/log")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Mouse = require("@lib/utils/input/mouse")
local Player = require("@lib/main/player")
local Random = require("@lib/utils/math/random")
type Target = Mouse.Target
type MenuClick = Host.MenuClick

local Interact = {}

Interact.HOVER_TIMEOUT = 600
Interact.WALK_HOVER_TIMEOUT = 100

Interact.SPAM_MAX = 3

function Interact.spam_click(chance: number?, still: () -> boolean, button: Mouse.Button?)
	if chance == nil or not Random.chance(chance) then
		return
	end
	for _ = 1, Random.trunc(Random.left(1, Interact.SPAM_MAX + 0.999)) do
		Random.sleep(30, 150, "left")
		if Player.is_animating() or not still() then
			return
		end
		Mouse.click(nil, button)
	end
end

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

local function arrive(walk_timeout_ms: (number | false)?): boolean
	if walk_timeout_ms == false then
		return true
	end
	return Player.wait_walk(if walk_timeout_ms then walk_timeout_ms else nil)
end

function Interact.with(
	at: Target,
	option: string,
	target: Minimenu.Target?,
	walk_timeout_ms: (number | false)?,
	spam: number?,
	scene: boolean?,
	menu: boolean?
): (boolean, MenuClick?)
	Mouse.move(at)
	local walking = scene == true and Player.destination() ~= nil
	local index = Interact.wait_option(option, target, if walking then Interact.WALK_HOVER_TIMEOUT else nil)
	if index == nil then
		return false, nil
	end
	local before = Minimenu.clicked()
	if index == 1 and not menu then
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
	if index == 1 and not menu then
		Interact.spam_click(spam, function(): boolean
			return Minimenu.find(option, target) == 1
		end)
	end
	return arrive(walk_timeout_ms), nil
end

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
			return true, arrive(walk_timeout_ms)
		end
	end
	if not Minimenu.close() then
		Log.log("Interact", "couldn't close the open menu")
	end
	return false, nil
end

return Interact
