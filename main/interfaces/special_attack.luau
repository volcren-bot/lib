--!strict
local Host = require("../../host")
local widget = Host.widget
local sleep = Host.sleep
local time = Host.time
type MenuEntry = Host.MenuEntry
type Widget = Host.Widget
local Interact = require("../interact")
local Log = require("../../utils/log")
local Player = require("../player")

local SpecialAttack = {}

-- The special attack orb: its interface and the children that can be the button (hidden without a special attack).
SpecialAttack.GROUP = 160
SpecialAttack.ORBS = { 36, 35, 34 }
SpecialAttack.OPTION = "Use"
SpecialAttack.TOGGLE_TIMEOUT_MS = 1500

-- The orb's button, or nil when it isn't showing (the weapon has no special attack).
function SpecialAttack.orb(): (Widget?, number?)
	for _, child in ipairs(SpecialAttack.ORBS) do
		local w = widget(SpecialAttack.GROUP, child)
		if w ~= nil and not w.hidden and w.width > 0 then
			return w, child
		end
	end
	return nil, nil
end

-- Whether the weapon in your hands has a special attack: its orb is showing.
function SpecialAttack.available(): boolean
	return (SpecialAttack.orb()) ~= nil
end

-- The special attack energy, from 0 to 100.
function SpecialAttack.energy(): number?
	return Player.special_attack()
end

-- Whether the special attack is switched on for the next attack.
function SpecialAttack.is_enabled(): boolean
	return Player.special_attack_enabled()
end

-- Switches the special attack on or off and waits for the change; false when there is none or the orb didn't change.
function SpecialAttack.set(enabled: boolean): boolean
	if SpecialAttack.is_enabled() == enabled then
		return true
	end
	local w, child = SpecialAttack.orb()
	if w == nil or child == nil then
		Log.log("SpecialAttack", "the weapon has no special attack")
		return false
	end
	local id = SpecialAttack.GROUP * 65536 + child
	Interact.with(w, SpecialAttack.OPTION, function(entry: MenuEntry): boolean
		return entry.id == id
	end, false)
	local deadline = time() + SpecialAttack.TOGGLE_TIMEOUT_MS
	while time() < deadline do
		if SpecialAttack.is_enabled() == enabled then
			return true
		end
		sleep(50)
	end
	Log.log("SpecialAttack", `the special attack didn't turn {if enabled then "on" else "off"}`)
	return false
end

-- Switches the special attack on when there is at least `cost` energy (50 by default). Returns true when it is on.
function SpecialAttack.enable(cost: number?): boolean
	local energy = SpecialAttack.energy()
	if energy == nil or energy < (cost or 50) then
		return false
	end
	return SpecialAttack.set(true)
end

return SpecialAttack
