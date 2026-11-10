--!strict
local Host = require("@lib/host")
local widget = Host.widget
type MenuEntry = Host.MenuEntry
type Widget = Host.Widget
local Biometrics = require("@lib/main/antiban/biometrics")
local Combat = require("@lib/main/interfaces/gametabs/combat")
local Interact = require("@lib/main/interact")
local Log = require("@lib/utils/log")
local Player = require("@lib/main/player")
local Widgets = require("@lib/main/interfaces/widgets")

local SpecialAttack = {}

SpecialAttack.GROUP = 160
SpecialAttack.ORBS = { 36, 35, 34 }
SpecialAttack.OPTION = "Use"
SpecialAttack.TOGGLE_TIMEOUT_MS = 1500
SpecialAttack.BAR_GROUP = 593
SpecialAttack.BAR = 41
SpecialAttack.BAR_OPTION = "Use Special Attack"
SpecialAttack.BAR_CHANCE = 0.5
SpecialAttack.FULL = 100
SpecialAttack.USE_TIMEOUT_MS = 3000
SpecialAttack.WORN = 94
SpecialAttack.WEAPON_SLOT = 3

local costs: { [number]: number } = {}
local pending: { weapon: number, energy: number }? = nil

local function watch()
	local weapon, energy = SpecialAttack.weapon(), SpecialAttack.energy()
	pending = if weapon ~= nil and energy ~= nil then { weapon = weapon, energy = energy } else nil
end

function SpecialAttack.weapon(): number?
	for _, item in ipairs(Host.item_container(SpecialAttack.WORN) or {}) do
		if item.slot == SpecialAttack.WEAPON_SLOT and item.id ~= -1 then
			return item.id
		end
	end
	return nil
end

function SpecialAttack.cost(weapon: number?): number
	local id = weapon or SpecialAttack.weapon()
	return if id ~= nil then costs[id] or SpecialAttack.FULL else SpecialAttack.FULL
end

function SpecialAttack.known(weapon: number?): boolean
	local id = weapon or SpecialAttack.weapon()
	return id ~= nil and costs[id] ~= nil
end

function SpecialAttack.orb(): (Widget?, number?)
	for _, child in ipairs(SpecialAttack.ORBS) do
		local w = widget(SpecialAttack.GROUP, child)
		if w ~= nil and not w.hidden and w.width > 0 then
			return w, child
		end
	end
	return nil, nil
end

function SpecialAttack.bar(): Widget?
	local w = widget(SpecialAttack.BAR_GROUP, SpecialAttack.BAR)
	return if w ~= nil and not w.hidden and w.width > 0 then w else nil
end

function SpecialAttack.available(): boolean
	return (SpecialAttack.orb()) ~= nil or SpecialAttack.bar() ~= nil
end

function SpecialAttack.energy(): number?
	return Player.special_attack()
end

function SpecialAttack.is_enabled(): boolean
	return Player.special_attack_enabled()
end

local function click(w: Widget, option: string, id: number)
	Interact.with(w, option, function(entry: MenuEntry): boolean
		return entry.id == id
	end, false)
end

local function click_orb(): boolean
	local w, child = SpecialAttack.orb()
	if w == nil or child == nil then
		return false
	end
	click(w, SpecialAttack.OPTION, SpecialAttack.GROUP * 65536 + child)
	return true
end

local function click_bar(): boolean
	if not Combat.open() then
		return false
	end
	local w = SpecialAttack.bar()
	if w == nil then
		return false
	end
	click(w, SpecialAttack.BAR_OPTION, SpecialAttack.BAR_GROUP * 65536 + SpecialAttack.BAR)
	return true
end

function SpecialAttack.set(enabled: boolean): boolean
	if SpecialAttack.is_enabled() == enabled then
		return true
	end
	local first, second = click_orb, click_bar
	if Biometrics.random_boolean(SpecialAttack.BAR_CHANCE) then
		first, second = click_bar, click_orb
	end
	if not first() and not second() then
		Log.log("SpecialAttack", "the weapon has no special attack")
		return false
	end
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
	if energy == nil or energy < (cost or SpecialAttack.cost()) then
		return false
	end
	if not SpecialAttack.set(true) then
		return false
	end
	watch()
	return true
end

function SpecialAttack.update(): boolean
	local p = pending
	local energy = SpecialAttack.energy()
	if p == nil or energy == nil or SpecialAttack.weapon() ~= p.weapon then
		return false
	end
	if energy > p.energy then
		p.energy = energy
		return false
	end
	if energy == p.energy then
		return false
	end
	pending = nil
	local drained = math.floor(p.energy - energy + 0.5)
	if costs[p.weapon] ~= drained then
		costs[p.weapon] = drained
		Log.log("SpecialAttack", `weapon {p.weapon}'s special attack costs {drained}%`)
	end
	return true
end

function SpecialAttack.wait_used(timeout_ms: number?): boolean
	if pending == nil then
		watch()
	end
	if pending == nil then
		return false
	end
	if Widgets.wait_within(SpecialAttack.update, timeout_ms or SpecialAttack.USE_TIMEOUT_MS, 50) then
		return true
	end
	Log.log("SpecialAttack", "the special attack wasn't used")
	return false
end

return SpecialAttack
