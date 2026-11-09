--!strict
local Host = require("@lib/host")
local widget = Host.widget
local widget_children = Host.widget_children
local sub_interfaces = Host.sub_interfaces
type Widget = Host.Widget
type MenuEntry = Host.MenuEntry
local Interact = require("@lib/main/interact")
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Player = require("@lib/main/player")
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")
local Varbits = require("@lib/main/varbits")
local Widgets = require("@lib/main/interfaces/widgets")

local Prayer = {}

Prayer.GROUP = 541

Prayer.ORB_GROUP = 160
Prayer.ORB = 20
Prayer.QUICK_SELECTED_VARBIT = 4102
Prayer.QUICK_ACTIVE_VARBIT = 4103
Prayer.SETUP_GROUP = 77
Prayer.SETUP_SLOTS = 4
Prayer.SETUP_DONE = 5

local TOGGLE_TIMEOUT_MS = 2000

export type Info = {
	key: string,
	name: string,
	child: number,
	varbit: number,
	level: number,
	defence: number?,
	unlock: number?,
	upgrade: number?,
	replaces: string?,
	attack: number?,
	strength: number?,
}

export type PrayerRef = string | Info

type Extra = {
	defence: number?,
	unlock: number?,
	upgrade: number?,
	replaces: string?,
	attack: number?,
	strength: number?,
}

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
		replaces = e.replaces,
		attack = e.attack,
		strength = e.strength,
	}) :: Info
end

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
	info("piety", "Piety", 35, 4129, 70, { defence = 70, upgrade = 16577 }),
	info("augury", "Augury", 36, 5465, 77, { unlock = 5452, defence = 70 }),
	info("preserve", "Preserve", 37, 5466, 55, { unlock = 5453 }),
	info("deadeye", "Deadeye", 29, 16090, 62, { unlock = 16097, replaces = "eagle_eye" }),
	info("mystic_vigour", "Mystic Vigour", 32, 16091, 63, { unlock = 16098, replaces = "mystic_might" }),
	info("zeal", "Zeal", 35, 16577, 84, { unlock = 16578, replaces = "piety", attack = 75, strength = 75 }),
}) :: { Info }

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

local function many(prayers: PrayerRef | { read PrayerRef }): { Info }?
	if type(prayers) == "string" or (type(prayers) == "table" and (prayers :: any).key ~= nil) then
		return resolve_all({ prayers :: PrayerRef })
	end
	return resolve_all(prayers :: { read PrayerRef })
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

function Prayer.is_on(prayer: PrayerRef): boolean
	local p = Prayer.prayer(prayer)
	if p == nil then
		return false
	end
	return varbit_on(p.varbit) or (p.upgrade ~= nil and varbit_on(p.upgrade))
end

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

function Prayer.can_activate(prayer: PrayerRef): boolean
	local p = Prayer.prayer(prayer)
	if p == nil then
		return false
	end
	local skills: { [string]: Host.Skill } = {}
	for _, skill in ipairs(game_state().skills or {}) do
		skills[skill.name] = skill
	end
	local points = skills.Prayer
	if points == nil or points.level <= 0 or points.real_level < p.level then
		return false
	end
	for skill, needed in pairs({ Defence = p.defence, Attack = p.attack, Strength = p.strength }) do
		local have = skills[skill]
		if have == nil or have.real_level < needed then
			return false
		end
	end
	return Prayer.is_unlocked(p)
end

local function on_component(group: number, child: number): (MenuEntry) -> boolean
	local id = group * 65536 + child
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
	if
		not Interact.with(w, if active then "Activate" else "Deactivate", on_component(Prayer.GROUP, p.child), false)
	then
		return false
	end
	if Widgets.wait_until(function()
		return Prayer.is_on(p) == active
	end, TOGGLE_TIMEOUT_MS) then
		return true
	end
	Log.log("Prayer", `{p.name} didn't turn {if active then "on" else "off"}`)
	return false
end

local function set_all(prayers: PrayerRef | { read PrayerRef }, active: boolean): boolean
	local list = many(prayers)
	if list == nil then
		return false
	end
	local result = true
	for _, p in ipairs(list) do
		if not Prayer.set(p, active) then
			result = false
		end
	end
	return result
end

function Prayer.activate(prayers: PrayerRef | { read PrayerRef }): boolean
	return set_all(prayers, true)
end

function Prayer.deactivate(prayers: PrayerRef | { read PrayerRef }): boolean
	return set_all(prayers, false)
end

function Prayer.deactivate_all(): boolean
	return Prayer.deactivate(Prayer.active())
end

local function quick_bit(p: Info): number?
	local key = p.replaces or p.key
	for i, k in ipairs(Prayer.QUICK_ORDER) do
		if k == key then
			return i - 1
		end
	end
	return nil
end

local function quick_selected_in(mask: number?, p: Info): boolean
	local bit = quick_bit(p)
	if mask == nil or bit == nil then
		return false
	end
	return bit32.band(bit32.rshift(mask, bit), 1) == 1
end

function Prayer.is_quick_selected(prayer: PrayerRef): boolean
	local p = Prayer.prayer(prayer)
	if p == nil then
		return false
	end
	return quick_selected_in(Varbits.get(Prayer.QUICK_SELECTED_VARBIT), p)
end

function Prayer.quick_prayers(): { Info }
	local mask = Varbits.get(Prayer.QUICK_SELECTED_VARBIT)
	local list: { Info } = {}
	for _, p in ipairs(Prayer.PRAYERS) do
		if quick_selected_in(mask, p) then
			table.insert(list, p)
		end
	end
	return list
end

function Prayer.is_quick_active(): boolean
	return varbit_on(Prayer.QUICK_ACTIVE_VARBIT)
end

local function orb_option(option: string): boolean
	local w = widget(Prayer.ORB_GROUP, Prayer.ORB)
	if w == nil then
		return false
	end
	return (Interact.with(w, option, on_component(Prayer.ORB_GROUP, Prayer.ORB), false))
end

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
	if Widgets.wait_until(function()
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
	if Widgets.wait_until(Prayer.is_quick_setup_open, TOGGLE_TIMEOUT_MS) then
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
	if not Interact.with(done, "Done", on_component(Prayer.SETUP_GROUP, Prayer.SETUP_DONE), false) then
		return false
	end
	return Widgets.wait_until(function()
		return not Prayer.is_quick_setup_open()
	end, TOGGLE_TIMEOUT_MS)
end

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
	if
		not Interact.with(w, "Toggle", function(entry: MenuEntry): boolean
			return entry.id == id and entry.index == index
		end, false)
	then
		return false
	end
	if Widgets.wait_until(function()
		return Prayer.is_quick_selected(p) == selected
	end, TOGGLE_TIMEOUT_MS) then
		return true
	end
	Log.log("Prayer", `{p.name} didn't {if selected then "join" else "leave"} the quick prayers`)
	return false
end

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
	local mask = Varbits.get(Prayer.QUICK_SELECTED_VARBIT)
	for _, p in ipairs(Prayer.PRAYERS) do
		if quick_selected_in(mask, p) ~= (wanted[p.key] == true) then
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
	for _, selected in ipairs({ false, true }) do
		for _, p in ipairs(Prayer.PRAYERS) do
			if (wanted[p.key] == true) == selected and not toggle_quick(p, selected) then
				result = false
			end
		end
	end
	local after = Varbits.get(Prayer.QUICK_SELECTED_VARBIT)
	for _, p in ipairs(list) do
		if not quick_selected_in(after, p) then
			result = false
		end
	end
	return Prayer.close_quick_setup() and result
end

return Prayer
