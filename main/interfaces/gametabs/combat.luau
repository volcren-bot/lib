--!strict
local Host = require("@lib/host")
local enum_def = Host.enum_def
local sleep = Host.sleep
local time = Host.time
local widget = Host.widget
local widget_children = Host.widget_children
type Widget = Host.Widget
local Interact = require("@lib/main/interact")
local Log = require("@lib/utils/log")
local Magic = require("@lib/main/interfaces/gametabs/magic")
local Mouse = require("@lib/utils/input/mouse")
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")
local Varbits = require("@lib/main/varbits")
local Varps = require("@lib/main/varps")

local Combat = {}

export type Style = "melee" | "ranged" | "magic"

Combat.GROUP = 593
Combat.CHOOSE_SPELL = 28
Combat.CHOOSE_DEFENSIVE = 23
Combat.PICKER_GROUP = 201
Combat.PICKER_SPELLS = 1
Combat.PICKER_CANCEL = 0
Combat.AUTOCAST_VARBIT = 276
Combat.DEFENSIVE_VARBIT = 2668
Combat.WEAPON_CATEGORY_VARBIT = 357
Combat.AUTOCAST_CATEGORIES = table.freeze({ 18, 21, 22 })
Combat.AUTOCAST_ENUM = 1986
Combat.BUTTONS_ENUM = 3908
Combat.BUTTON_STYLES = table.freeze({
	[3722] = "melee",
	[3723] = "melee",
	[3724] = "melee",
	[3726] = "ranged",
	[3727] = "ranged",
	[3728] = "magic",
} :: { [number]: Style })
Combat.DEFENSIVE_BUTTON = 3725

local POLL_MS = 50
local PICKER_TIMEOUT_MS = 2000
local SET_TIMEOUT_MS = 2500

function Combat.is_open(): boolean
	return SidePanels.is_open(SidePanels.COMBAT_INTERFACE)
end

function Combat.open(timeout_ms: number?): boolean
	return SidePanels.open(SidePanels.COMBAT_INTERFACE, nil, timeout_ms)
end

function Combat.weapon_category(): number?
	return Varbits.get(Combat.WEAPON_CATEGORY_VARBIT)
end

function Combat.can_autocast(): boolean
	local category = Combat.weapon_category()
	return category ~= nil and table.find(Combat.AUTOCAST_CATEGORIES, category) ~= nil
end

function Combat.autocast_index(): number
	return Varbits.get(Combat.AUTOCAST_VARBIT) or 0
end

function Combat.is_defensive(): boolean
	return Varbits.get(Combat.DEFENSIVE_VARBIT) == 1
end

local buttons_by_category: { [number]: { [number]: number } } = {}

local function category_buttons(category: number): { [number]: number }?
	local cached = buttons_by_category[category]
	if cached then
		return cached
	end
	local categories = enum_def(Combat.BUTTONS_ENUM)
	if categories == nil then
		return nil
	end
	for _, entry in ipairs(categories.entries) do
		if entry.key == category and type(entry.value) == "number" then
			local def = enum_def(entry.value)
			if def == nil then
				return nil
			end
			local buttons: { [number]: number } = {}
			for _, button in ipairs(def.entries) do
				if type(button.value) == "number" then
					buttons[button.key] = button.value
				end
			end
			buttons_by_category[category] = buttons
			return buttons
		end
	end
	return nil
end

local function button_style(buttons: { [number]: number }, index: number): Style?
	local id = buttons[index]
	return if id then Combat.BUTTON_STYLES[id] else nil
end

function Combat.style(): Style?
	if Combat.can_autocast() and Combat.autocast_index() > 0 then
		return "magic"
	end
	local category, index = Combat.weapon_category(), Varps.get(Varps.ATTACK_STYLE)
	if category == nil or index == nil then
		return nil
	end
	local buttons = category_buttons(category)
	if buttons == nil then
		return nil
	end
	if buttons[index] ~= Combat.DEFENSIVE_BUTTON then
		return button_style(buttons, index)
	end
	for other = 0, 3 do
		local style = button_style(buttons, other)
		if style then
			return style
		end
	end
	return nil
end

local numbers: { [number]: number }? = nil

local function autocast_numbers(): { [number]: number }?
	if numbers then
		return numbers
	end
	local def = enum_def(Combat.AUTOCAST_ENUM)
	if def == nil then
		return nil
	end
	local by_item: { [number]: number } = {}
	for _, entry in ipairs(def.entries) do
		if type(entry.value) == "number" then
			by_item[entry.value] = entry.key
		end
	end
	numbers = by_item
	return by_item
end

function Combat.spell(spell: Magic.SpellRef): Magic.Spell?
	if type(spell) == "table" then
		return spell
	end
	for _, book in pairs(Magic.BOOKS) do
		local s = Magic.spell(spell, book)
		if s then
			return s
		end
	end
	return nil
end

function Combat.autocast_number(spell: Magic.SpellRef): number?
	local s = Combat.spell(spell)
	local list = autocast_numbers()
	if s == nil or list == nil then
		return nil
	end
	return list[s.item]
end

function Combat.autocast_spell(): Magic.Spell?
	local index = Combat.autocast_index()
	if index == 0 then
		return nil
	end
	local list = autocast_numbers()
	if list == nil then
		return nil
	end
	for item, number in pairs(list) do
		if number == index then
			for _, book in pairs(Magic.BOOKS) do
				for _, s in ipairs(Magic.spells(book) or {}) do
					if s.item == item then
						return s
					end
				end
			end
		end
	end
	return nil
end

function Combat.is_picker_open(): boolean
	local w = widget(Combat.PICKER_GROUP, Combat.PICKER_SPELLS)
	return w ~= nil and not w.hidden
end

local function wait_until(check: () -> boolean, timeout_ms: number): boolean
	local deadline = time() + timeout_ms
	while time() < deadline do
		if check() then
			return true
		end
		sleep(POLL_MS)
	end
	return check()
end

function Combat.open_picker(defensive: boolean?): boolean
	if Combat.is_picker_open() then
		return true
	end
	if not Combat.open() then
		return false
	end
	local button = widget(Combat.GROUP, if defensive then Combat.CHOOSE_DEFENSIVE else Combat.CHOOSE_SPELL)
	if button == nil or button.hidden then
		Log.log("Combat", "the weapon's tab has no autocast")
		return false
	end
	Mouse.click(button)
	return wait_until(Combat.is_picker_open, PICKER_TIMEOUT_MS)
end

local function picker_child(index: number): Widget?
	for _, child in ipairs(widget_children(Combat.PICKER_GROUP, Combat.PICKER_SPELLS) or {}) do
		if child.index == index and not child.hidden then
			return child
		end
	end
	return nil
end

function Combat.cancel_picker(): boolean
	if not Combat.is_picker_open() then
		return true
	end
	local cancel = picker_child(Combat.PICKER_CANCEL)
	if cancel == nil then
		return false
	end
	Mouse.click(cancel)
	return wait_until(function()
		return not Combat.is_picker_open()
	end, PICKER_TIMEOUT_MS)
end

function Combat.set_autocast(spell: Magic.SpellRef, defensive: boolean?): boolean
	local s = Combat.spell(spell)
	local number = Combat.autocast_number(spell)
	if s == nil or number == nil then
		Log.log("Combat", "set_autocast: not a spell a weapon autocasts")
		return false
	end
	local wanted_defensive = defensive == true
	local function set(): boolean
		return Combat.autocast_index() == number and Combat.is_defensive() == wanted_defensive
	end
	for _ = 1, 2 do
		if set() then
			return true
		end
		if not Combat.open_picker(wanted_defensive) then
			return false
		end
		local child = picker_child(number)
		if child == nil then
			Log.log("Combat", `set_autocast: this weapon's picker doesn't offer {s.name}`)
			Combat.cancel_picker()
			return false
		end
		if not Interact.with(child, s.name, nil, false) then
			Combat.cancel_picker()
			return false
		end
		wait_until(function()
			return Combat.autocast_index() == number
		end, SET_TIMEOUT_MS)
	end
	return set()
end

return Combat
