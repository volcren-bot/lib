--!strict
-- The combat options tab: the weapon's category and its autocast, chosen through the tab's spell picker.
-- Autocast is a number the game keeps (the spell's place in its autocast list); the picker shows the spells the wielded weapon offers.
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

local Combat = {}

Combat.GROUP = 593
-- The two "Choose spell" buttons: autocast (the lower one), and defensive autocast (the upper one).
Combat.CHOOSE_SPELL = 28
Combat.CHOOSE_DEFENSIVE = 23
-- The spell picker that opens over the tab: a layer whose dynamic children are the spells, one per autocast number, and 0 the Cancel button.
Combat.PICKER_GROUP = 201
Combat.PICKER_SPELLS = 1
Combat.PICKER_CANCEL = 0
-- The settings: the autocast number (0 for none), whether it is defensive, and the wielded weapon's category.
Combat.AUTOCAST_VARBIT = 276
Combat.DEFENSIVE_VARBIT = 2668
Combat.WEAPON_CATEGORY_VARBIT = 357
-- The categories whose tab offers autocast: staves, powered staves and the staves that cast their own spell.
Combat.AUTOCAST_CATEGORIES = table.freeze({ 18, 21, 22 })
-- The game's autocast list: a number for each spell a weapon can autocast.
Combat.AUTOCAST_ENUM = 1986

local POLL_MS = 50
local PICKER_TIMEOUT_MS = 2000
local SET_TIMEOUT_MS = 2500

function Combat.is_open(): boolean
	return SidePanels.is_open(SidePanels.COMBAT_INTERFACE)
end

function Combat.open(timeout_ms: number?): boolean
	return SidePanels.open(SidePanels.COMBAT_INTERFACE, nil, timeout_ms)
end

-- The wielded weapon's category, the number the combat tab lays its buttons out by.
function Combat.weapon_category(): number?
	return Varbits.get(Combat.WEAPON_CATEGORY_VARBIT)
end

-- Whether the wielded weapon's tab offers autocast.
function Combat.can_autocast(): boolean
	local category = Combat.weapon_category()
	return category ~= nil and table.find(Combat.AUTOCAST_CATEGORIES, category) ~= nil
end

-- The autocast number set now, 0 for none.
function Combat.autocast_index(): number
	return Varbits.get(Combat.AUTOCAST_VARBIT) or 0
end

function Combat.is_defensive(): boolean
	return Varbits.get(Combat.DEFENSIVE_VARBIT) == 1
end

local numbers: { [number]: number }? = nil

-- The autocast list by item: each spell's number.
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

-- A spell by name in any of the books (`Magic.spell` looks in the current one), or the spell given.
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

-- The spell's autocast number, nil for one no weapon autocasts.
function Combat.autocast_number(spell: Magic.SpellRef): number?
	local s = Combat.spell(spell)
	local list = autocast_numbers()
	if s == nil or list == nil then
		return nil
	end
	return list[s.item]
end

-- The spell autocast now, nil for none.
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

-- Opens the spell picker with the autocast button, or the defensive one. False when the weapon has no autocast.
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

-- Closes the spell picker with its Cancel, leaving the autocast as it was.
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

-- Sets the spell to autocast (defensively with `defensive`): opens the picker and picks it. True once the game shows it set.
-- False for a spell no weapon autocasts, one the wielded weapon's picker doesn't offer, or a weapon without autocast.
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
	-- a picker that was already open may be the other mode's: then the pick lands in the wrong mode and is done again from the right button
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
