--!strict
local Host = require("@lib/host")
local widget = Host.widget
type MenuEntry = Host.MenuEntry
type Widget = Host.Widget
local Interact = require("@lib/main/interact")
local Log = require("@lib/utils/log")
local Player = require("@lib/main/player")
local Widgets = require("@lib/main/interfaces/widgets")

local SpecialAttack = {}

SpecialAttack.GROUP = 160
SpecialAttack.ORBS = { 36, 35, 34 }
SpecialAttack.OPTION = "Use"
SpecialAttack.TOGGLE_TIMEOUT_MS = 1500

function SpecialAttack.orb(): (Widget?, number?)
	for _, child in ipairs(SpecialAttack.ORBS) do
		local w = widget(SpecialAttack.GROUP, child)
		if w ~= nil and not w.hidden and w.width > 0 then
			return w, child
		end
	end
	return nil, nil
end

function SpecialAttack.available(): boolean
	return (SpecialAttack.orb()) ~= nil
end

function SpecialAttack.energy(): number?
	return Player.special_attack()
end

function SpecialAttack.is_enabled(): boolean
	return Player.special_attack_enabled()
end

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
	if
		Widgets.wait_within(function(): boolean
			return SpecialAttack.is_enabled() == enabled
		end, SpecialAttack.TOGGLE_TIMEOUT_MS, 50)
	then
		return true
	end
	Log.log("SpecialAttack", `the special attack didn't turn {if enabled then "on" else "off"}`)
	return false
end

function SpecialAttack.enable(cost: number?): boolean
	local energy = SpecialAttack.energy()
	if energy == nil or energy < (cost or 50) then
		return false
	end
	return SpecialAttack.set(true)
end

return SpecialAttack
