--!strict
local Host = require("../../../host")
local widget = Host.widget
local widget_children = Host.widget_children
local sub_interfaces = Host.sub_interfaces
local sleep = Host.sleep
type Widget = Host.Widget
type MenuEntry = Host.MenuEntry
local Varbits = require("../../varbits")
local Player = require("../../player")
local SidePanels = require("./side_panels")
local Stats = require("./stats")
local Interact = require("../../interact")
local Mouse = require("../../../utils/input/mouse")
local Log = require("../../../utils/log")

local Prayer = {}

Prayer.GROUP = 541

-- The quick prayers: the minimap orb, and the setup panel with its slots (children of 77:4) and Done button.
Prayer.ORB_GROUP = 160
Prayer.ORB = 20
Prayer.QUICK_SELECTED_VARBIT = 4102
Prayer.QUICK_ACTIVE_VARBIT = 4103
Prayer.SETUP_GROUP = 77
Prayer.SETUP_SLOTS = 4
Prayer.SETUP_DONE = 5

local POLL_MS = 50
local TOGGLE_TIMEOUT_MS = 2000

export type Info = {
	key: string,
	name: string,
	-- the prayer's slot, a component of group 541
	child: number,
	-- 1 while the prayer is active
	varbit: number,
	level: number,
	-- Defence level it needs besides the Prayer level
	defence: number?,
	-- 1 once the prayer is unlocked, for the ones that have to be
	unlock: number?,
	-- the varbit of the upgrade that takes this slot, once its scroll is used
	upgrade: number?,
}

export type PrayerRef = string | Info

type Extra = { defence: number?, unlock: number?, upgrade: number? }

local function info(key: string, name: string, child: number, varbit: number, level: number, extra: Extra?): Info
	local e: Extra = extra or {}
	return table.freeze({
		key = key,
		name = name,
		child = child,
		varbit = varbit,
		level = level,
		defence = e.defence,
		unlock = e.unlock,
		upgrade = e.upgrade,
	}) :: Info
end

-- In the order of the prayer tab.
Prayer.PRAYERS = table.freeze({
	info("thick_skin", "Thick Skin", 9, 4104, 1),
	info("burst_of_strength", "Burst of Strength", 10, 4105, 4),
	info("clarity_of_thought", "Clarity of Thought", 11, 4106, 7),
	info("rock_skin", "Rock Skin", 12, 4107, 10),
	info("superhuman_strength", "Superhuman Strength", 13, 4108, 13),
	info("improved_reflexes", "Improved Reflexes", 14, 4109, 16),
	info("rapid_restore", "Rapid Restore", 15, 4110, 19),
	info("rapid_heal", "Rapid Heal", 16, 4111, 22),
	info("protect_item", "Protect Item", 17, 4112, 25),
	info("steel_skin", "Steel Skin", 18, 4113, 28),
	info("ultimate_strength", "Ultimate Strength", 19, 4114, 31),
	info("incredible_reflexes", "Incredible Reflexes", 20, 4115, 34),
	info("protect_from_magic", "Protect from Magic", 21, 4116, 37),
	info("protect_from_missiles", "Protect from Missiles", 22, 4117, 40),
	info("protect_from_melee", "Protect from Melee", 23, 4118, 43),
	info("retribution", "Retribution", 24, 4119, 46),
	info("redemption", "Redemption", 25, 4120, 49),
	info("smite", "Smite", 26, 4121, 52),
	info("sharp_eye", "Sharp Eye", 27, 4122, 8),
	info("hawk_eye", "Hawk Eye", 28, 4124, 26),
	info("eagle_eye", "Eagle Eye", 29, 4126, 44, { upgrade = 16090 }),
	info("mystic_will", "Mystic Will", 30, 4123, 9),
	info("mystic_lore", "Mystic Lore", 31, 4125, 27),
	info("mystic_might", "Mystic Might", 32, 4127, 45, { upgrade = 16091 }),
	info("rigour", "Rigour", 33, 5464, 74, { unlock = 5451, defence = 70 }),
	info("chivalry", "Chivalry", 34, 4128, 60, { defence = 65 }),
	info("piety", "Piety", 35, 4129, 70, { defence = 70 }),
	info("augury", "Augury", 36, 5465, 77, { unlock = 5452, defence = 70 }),
	info("preserve", "Preserve", 37, 5466, 55, { unlock = 5453 }),
}) :: { Info }

-- The prayers in the order of the quick prayer setup's slots. The selected prayers are a bitmask of them: bit 0 is the first.
Prayer.QUICK_ORDER = table.freeze({
	"thick_skin",
	"burst_of_strength",
	"clarity_of_thought",
	"rock_skin",
	"superhuman_strength",
	"improved_reflexes",
	"rapid_restore",
	"rapid_heal",
	"protect_item",
	"steel_skin",
	"ultimate_strength",
	"incredible_reflexes",
	"protect_from_magic",
	"protect_from_missiles",
	"protect_from_melee",
	"retribution",
	"redemption",
	"smite",
	"sharp_eye",
	"mystic_will",
	"hawk_eye",
	"mystic_lore",
	"eagle_eye",
	"mystic_might",
	"rigour",
	"chivalry",
	"piety",
	"augury",
	"preserve",
}) :: { string }

local by_key: { [string]: Info } = {}

local function key(name: string): string
	return (string.gsub(string.lower(name), "[^%w]", ""))
end

for _, p in ipairs(Prayer.PRAYERS) do
	by_key[key(p.name)] = p
end

function Prayer.prayer(prayer: PrayerRef): Info?
	if type(prayer) == "table" then
		return prayer
	end
	local found = by_key[key(prayer)]
	if found == nil then
		Log.log("Prayer", `unknown prayer "{prayer}"`)
	end
	return found
end

local function resolve_all(prayers: { read PrayerRef }): { Info }?
	local list: { Info } = {}
	for i = 1, #prayers do
		local p = Prayer.prayer(prayers[i])
		if p == nil then
			return nil
		end
		table.insert(list, p)
	end
	return list
end

-- A prayer, a name, or a list of either.
local function many(prayers: PrayerRef | { read PrayerRef }): { Info }?
	if type(prayers) == "string" or (type(prayers) == "table" and (prayers :: any).key ~= nil) then
		return resolve_all({ prayers :: PrayerRef })
	end
	return resolve_all(prayers :: { read PrayerRef })
end

local function wait_until(check: () -> boolean, timeout_ms: number): boolean
	local waited = 0
	while true do
		if check() then
			return true
		end
		if waited >= timeout_ms then
			return false
		end
		sleep(POLL_MS)
		waited += POLL_MS
	end
end

local function varbit_on(id: number): boolean
	return Varbits.get(id) == 1
end

function Prayer.is_open(): boolean
	return SidePanels.is_open(SidePanels.PRAYERBOOK)
end

function Prayer.open(timeout_ms: number?): boolean
	return SidePanels.open(SidePanels.PRAYERBOOK, nil, timeout_ms)
end

-- Prayer points left and the Prayer level (the points at full).
function Prayer.points(): (number?, number?)
	return Player.prayer()
end

function Prayer.widget(prayer: PrayerRef): Widget?
	local p = Prayer.prayer(prayer)
	if p == nil then
		return nil
	end
	return widget(Prayer.GROUP, p.child)
end

-- False while the prayer's slot is hidden, by the tab being closed or by the prayer filters.
function Prayer.is_visible(prayer: PrayerRef): boolean
	local w = Prayer.widget(prayer)
	return w ~= nil and not w.hidden
end

function Prayer.is_unlocked(prayer: PrayerRef): boolean
	local p = Prayer.prayer(prayer)
	if p == nil then
		return false
	end
	return p.unlock == nil or varbit_on(p.unlock)
end

-- Whether the prayer is on. Reads game settings, so the tab doesn't have to be open.
function Prayer.is_on(prayer: PrayerRef): boolean
	local p = Prayer.prayer(prayer)
	if p == nil then
		return false
	end
	return varbit_on(p.varbit) or (p.upgrade ~= nil and varbit_on(p.upgrade))
end

-- True if all the prayers are active.
function Prayer.is_active(prayers: PrayerRef | { read PrayerRef }): boolean
	local list = many(prayers)
	if list == nil then
		return false
	end
	for _, p in ipairs(list) do
		if not Prayer.is_on(p) then
			return false
		end
	end
	return true
end

function Prayer.is_any_active(): boolean
	for _, p in ipairs(Prayer.PRAYERS) do
		if Prayer.is_on(p) then
			return true
		end
	end
	return false
end

function Prayer.active(): { Info }
	local list: { Info } = {}
	for _, p in ipairs(Prayer.PRAYERS) do
		if Prayer.is_on(p) then
			table.insert(list, p)
		end
	end
	return list
end

-- Whether you have what the prayer needs: the Prayer level, the Defence level and the unlock, and prayer points to use it.
function Prayer.can_activate(prayer: PrayerRef): boolean
	local p = Prayer.prayer(prayer)
	if p == nil then
		return false
	end
	local points, level = Prayer.points()
	if points == nil or level == nil or points <= 0 or level < p.level then
		return false
	end
	if p.defence ~= nil then
		local defence = Stats.real_level("Defence")
		if defence == nil or defence < p.defence then
			return false
		end
	end
	return Prayer.is_unlocked(p)
end

local function on(p: Info): (MenuEntry) -> boolean
	local id = Prayer.GROUP * 65536 + p.child
	return function(entry: MenuEntry): boolean
		return entry.id == id
	end
end

function Prayer.hover(prayer: PrayerRef): boolean
	local p = Prayer.prayer(prayer)
	if p == nil or not Prayer.open() then
		return false
	end
	local w = widget(Prayer.GROUP, p.child)
	if w == nil or w.hidden then
		return false
	end
	Mouse.move(w)
	return true
end

-- Switches one prayer on or off and waits for it to change.
function Prayer.set(prayer: PrayerRef, active: boolean): boolean
	local p = Prayer.prayer(prayer)
	if p == nil then
		return false
	end
	if Prayer.is_on(p) == active then
		return true
	end
	if active and not Prayer.can_activate(p) then
		Log.log("Prayer", `can't activate {p.name}`)
		return false
	end
	if not Prayer.open() then
		return false
	end
	local w = widget(Prayer.GROUP, p.child)
	if w == nil or w.hidden then
		Log.log("Prayer", `the {p.name} slot isn't visible, check the prayer filters`)
		return false
	end
	local ok = Interact.with(w, if active then "Activate" else "Deactivate", on(p), false)
	if not ok then
		return false
	end
	if wait_until(function()
		return Prayer.is_on(p) == active
	end, TOGGLE_TIMEOUT_MS) then
		return true
	end
	Log.log("Prayer", `{p.name} didn't turn {if active then "on" else "off"}`)
	return false
end

-- Turns on every prayer given that is off. True if all of them are active in the end.
function Prayer.activate(prayers: PrayerRef | { read PrayerRef }): boolean
	local list = many(prayers)
	if list == nil then
		return false
	end
	local result = true
	for _, p in ipairs(list) do
		if not Prayer.set(p, true) then
			result = false
		end
	end
	return result
end

-- Turns off every prayer given that is on. True if all of them are off in the end.
function Prayer.deactivate(prayers: PrayerRef | { read PrayerRef }): boolean
	local list = many(prayers)
	if list == nil then
		return false
	end
	local result = true
	for _, p in ipairs(list) do
		if not Prayer.set(p, false) then
			result = false
		end
	end
	return result
end

function Prayer.deactivate_all(): boolean
	return Prayer.deactivate(Prayer.active())
end

local function quick_bit(p: Info): number?
	for i, k in ipairs(Prayer.QUICK_ORDER) do
		if k == p.key then
			return i - 1
		end
	end
	return nil
end

-- Whether the prayer is one of the quick prayers.
function Prayer.is_quick_selected(prayer: PrayerRef): boolean
	local p = Prayer.prayer(prayer)
	if p == nil then
		return false
	end
	local mask, bit = Varbits.get(Prayer.QUICK_SELECTED_VARBIT), quick_bit(p)
	if mask == nil or bit == nil then
		return false
	end
	return bit32.band(bit32.rshift(mask, bit), 1) == 1
end

function Prayer.quick_prayers(): { Info }
	local list: { Info } = {}
	for _, p in ipairs(Prayer.PRAYERS) do
		if Prayer.is_quick_selected(p) then
			table.insert(list, p)
		end
	end
	return list
end

-- Whether the quick prayers are on.
function Prayer.is_quick_active(): boolean
	return varbit_on(Prayer.QUICK_ACTIVE_VARBIT)
end

local function orb_option(option: string): boolean
	local w = widget(Prayer.ORB_GROUP, Prayer.ORB)
	if w == nil then
		return false
	end
	local id = Prayer.ORB_GROUP * 65536 + Prayer.ORB
	return (Interact.with(w, option, function(entry: MenuEntry): boolean
		return entry.id == id
	end, false))
end

-- Turns the quick prayers on or off from the minimap orb and waits for it to change. Turning them on needs prayer points and at least one quick prayer.
function Prayer.set_quick_active(active: boolean): boolean
	if Prayer.is_quick_active() == active then
		return true
	end
	if active then
		local points = Prayer.points()
		if points == nil or points <= 0 then
			Log.log("Prayer", "no prayer points to turn the quick prayers on")
			return false
		end
		if #Prayer.quick_prayers() == 0 then
			Log.log("Prayer", "no quick prayers are selected")
			return false
		end
	end
	if not orb_option(if active then "Activate" else "Deactivate") then
		return false
	end
	if wait_until(function()
		return Prayer.is_quick_active() == active
	end, TOGGLE_TIMEOUT_MS) then
		return true
	end
	Log.log("Prayer", `the quick prayers didn't turn {if active then "on" else "off"}`)
	return false
end

function Prayer.is_quick_setup_open(): boolean
	for _, s in ipairs(sub_interfaces() or {}) do
		if s.group == Prayer.SETUP_GROUP then
			return true
		end
	end
	return false
end

function Prayer.open_quick_setup(): boolean
	if Prayer.is_quick_setup_open() then
		return true
	end
	if not orb_option("Setup") then
		return false
	end
	if wait_until(Prayer.is_quick_setup_open, TOGGLE_TIMEOUT_MS) then
		return true
	end
	Log.log("Prayer", "the quick prayer setup didn't open")
	return false
end

function Prayer.close_quick_setup(): boolean
	if not Prayer.is_quick_setup_open() then
		return true
	end
	local done = widget(Prayer.SETUP_GROUP, Prayer.SETUP_DONE)
	if done == nil then
		return false
	end
	local id = Prayer.SETUP_GROUP * 65536 + Prayer.SETUP_DONE
	local ok = Interact.with(done, "Done", function(entry: MenuEntry): boolean
		return entry.id == id
	end, false)
	if not ok then
		return false
	end
	return wait_until(function()
		return not Prayer.is_quick_setup_open()
	end, TOGGLE_TIMEOUT_MS)
end

-- Adds or removes one prayer from the quick prayers through the open setup.
local function toggle_quick(p: Info, selected: boolean): boolean
	if Prayer.is_quick_selected(p) == selected then
		return true
	end
	local bit = quick_bit(p)
	local slots = widget_children(Prayer.SETUP_GROUP, Prayer.SETUP_SLOTS)
	local w = if slots and bit then slots[bit + 1] else nil
	if w == nil then
		return false
	end
	local id = Prayer.SETUP_GROUP * 65536 + Prayer.SETUP_SLOTS
	local index = w.index
	local ok = Interact.with(w, "Toggle", function(entry: MenuEntry): boolean
		return entry.id == id and entry.index == index
	end, false)
	if not ok then
		return false
	end
	if wait_until(function()
		return Prayer.is_quick_selected(p) == selected
	end, TOGGLE_TIMEOUT_MS) then
		return true
	end
	Log.log("Prayer", `{p.name} didn't {if selected then "join" else "leave"} the quick prayers`)
	return false
end

-- Makes these the quick prayers: deselects the others and selects the ones missing through the setup panel, then closes it. Prayers you can't use yet can't be selected, and neither can ones that exclude each other (Thick Skin and Rock Skin, say), so this returns false for those.
function Prayer.set_quick_prayers(prayers: PrayerRef | { read PrayerRef }): boolean
	local list = many(prayers)
	if list == nil then
		return false
	end
	local wanted: { [string]: boolean } = {}
	for _, p in ipairs(list) do
		wanted[p.key] = true
	end
	local changes = false
	for _, p in ipairs(Prayer.PRAYERS) do
		if Prayer.is_quick_selected(p) ~= (wanted[p.key] == true) then
			changes = true
		end
	end
	if not changes then
		return true
	end
	if not Prayer.open_quick_setup() then
		return false
	end
	local result = true
	-- deselect first, since selecting a prayer deselects the ones it can't be used with
	for _, selected in ipairs({ false, true }) do
		for _, p in ipairs(Prayer.PRAYERS) do
			if (wanted[p.key] == true) == selected and not toggle_quick(p, selected) then
				result = false
			end
		end
	end
	for _, p in ipairs(list) do
		if not Prayer.is_quick_selected(p) then
			result = false
		end
	end
	return Prayer.close_quick_setup() and result
end

return Prayer
