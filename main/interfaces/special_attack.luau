--!strict
local Host = require("@lib/host")
local enum_def = Host.enum_def
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
SpecialAttack.WORN = 94
SpecialAttack.WEAPON_SLOT = 3
SpecialAttack.COST_ENUM = 906
SpecialAttack.COST_SCALE = 10

local listed: { [number]: number }? = nil

function SpecialAttack.weapon(): number?
	for _, item in ipairs(Host.item_container(SpecialAttack.WORN) or {}) do
		if item.slot == SpecialAttack.WEAPON_SLOT and item.id ~= -1 then
			return item.id
		end
	end
	return nil
end

local function costs(): { [number]: number }?
	if listed then
		return listed
	end
	local def = enum_def(SpecialAttack.COST_ENUM)
	if def == nil then
		return nil
	end
	local by_item: { [number]: number } = {}
	for _, entry in ipairs(def.entries) do
		if type(entry.value) == "number" and entry.value >= 0 then
			by_item[entry.key] = entry.value / SpecialAttack.COST_SCALE
		end
	end
	listed = by_item
	return by_item
end

function SpecialAttack.cost(weapon: number?): number?
	local id = weapon or SpecialAttack.weapon()
	local list = costs()
	return if id ~= nil and list ~= nil then list[id] else nil
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
	local energy, need = SpecialAttack.energy(), cost or SpecialAttack.cost()
	if energy == nil or need == nil or energy < need then
		return false
	end
	return SpecialAttack.set(true)
end

return SpecialAttack
