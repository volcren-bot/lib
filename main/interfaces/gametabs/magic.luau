--!strict
local Host = require("../../../host")
local widget = Host.widget
local widget_children = Host.widget_children
local enum_def = Host.enum_def
local item_params = Host.item_params
local selected_widget = Host.selected_widget
local menu_click = Host.menu_click
local connection = Host.connection
local sleep = Host.sleep
type Widget = Host.Widget
type SelectedWidget = Host.SelectedWidget
type MenuEntry = Host.MenuEntry
local Varbits = require("../../varbits")
local SidePanels = require("./side_panels")
local Stats = require("./stats")
local Interact = require("../../interact")
local Minimenu = require("../minimenu")
local Mouse = require("../../../utils/input/mouse")
local Geometry = require("../../../utils/math/geometry")
local Log = require("../../../utils/log")
type Point = Geometry.Point

local Magic = {}

Magic.GROUP = 218
Magic.INFO = 210
Magic.BOOKS = { [0] = "standard", "ancient", "lunar", "arceuus" }
Magic.BOOKS_ENUM = 1981
Magic.JEWELLERY_ENUM = 5285

Magic.FILTERS_PANEL = 203
Magic.FILTERS_ROWS = 206
Magic.FILTERS_BUTTON = 209
Magic.FILTERING_OFF_VARBIT = 6718
Magic.FILTERS = {
	combat = { varbit = 6605, text = "Combat" },
	teleport = { varbit = 6609, text = "Teleport" },
	utility = { varbit = 6606, text = "Utility" },
	level = { varbit = 6607, text = "Magic level" },
	runes = { varbit = 6608, text = "runes" },
	requirements = { varbit = 12137, text = "requirements" },
}

local P_COMPONENT = 596
local P_CASTABLE = { 597, 599 }
local P_DISABLED = { 598, 600 }
local P_NAME = 601
local P_DESCRIPTION = 602
local P_MEMBERS = 603
local P_LEVEL = 604
local P_KIND = 605
local P_RUNES = { { 365, 366 }, { 367, 368 }, { 369, 370 }, { 606, 607 } }
local KINDS = { [0] = "combat", "utility", "teleport", "menu" }

local POLL_MS = 50
local FILTER_TIMEOUT_MS = 2000
local SHOW_TIMEOUT_MS = 2000
local DESELECT_TIMEOUT_MS = 1200
local INFO_TIMEOUT_MS = 3000

export type Spell = {
	name: string,
	book: string,
	menu: string?,
	item: number,
	child: number,
	id: number,
	level: number,
	members: boolean,
	kind: string,
	description: string,
	runes: { { item: number, amount: number } },
	castable: { number },
	disabled: { number },
}

export type SpellRef = string | Spell

local books: { [string]: { Spell } } = {}

local function key(name: string): string
	return (string.gsub(string.lower(name), "[^%w]", ""))
end

local function int(v: Host.CacheValue?): number?
	return if type(v) == "number" then v else nil
end

local function load_enum(id: number, book: string, menu: string?, into: { Spell }): boolean
	local def = enum_def(id)
	if def == nil then
		return false
	end
	local items: { number } = {}
	for i, entry in ipairs(def.entries) do
		items[i] = int(entry.value) or -1
	end
	local params = item_params(items)
	if params == nil then
		return false
	end
	for i, item in ipairs(items) do
		local p = params[i]
		local component = p and int(p[P_COMPONENT])
		local name = p and p[P_NAME]
		if p and component and type(name) == "string" then
			local runes = {}
			for _, pair in ipairs(P_RUNES) do
				local rune, amount = int(p[pair[1]]), int(p[pair[2]])
				if rune and amount then
					table.insert(runes, { item = rune, amount = amount })
				end
			end
			local description = p[P_DESCRIPTION]
			table.insert(into, {
				name = name,
				book = book,
				menu = menu,
				item = item,
				child = component % 65536,
				id = component,
				level = int(p[P_LEVEL]) or 0,
				members = p[P_MEMBERS] == 1,
				kind = KINDS[int(p[P_KIND]) or 0] or "utility",
				description = if type(description) == "string" then description else "",
				runes = runes,
				castable = { int(p[P_CASTABLE[1]]) or -1, int(p[P_CASTABLE[2]]) or -1 },
				disabled = { int(p[P_DISABLED[1]]) or -1, int(p[P_DISABLED[2]]) or -1 },
			})
		end
	end
	return true
end

function Magic.spellbook(): string?
	local value = Varbits.get(Varbits.SPELLBOOK)
	if value == nil then
		return nil
	end
	return Magic.BOOKS[value] or tostring(value)
end

function Magic.is_spellbook(book: string): boolean
	local current = Magic.spellbook()
	if current == nil then
		return false
	end
	return current == string.lower(book)
end

function Magic.spells(book: string?): { Spell }?
	local name = if book then string.lower(book) else nil
	if name == nil then
		local current = Magic.spellbook()
		if current == nil then
			return nil
		end
		name = current
	end
	local wanted = name :: string
	if books[wanted] then
		return books[wanted]
	end
	local index: number? = nil
	for i, b in pairs(Magic.BOOKS) do
		if b == wanted then
			index = i
		end
	end
	if index == nil then
		Log.log("Magic", `unknown spellbook "{wanted}"`)
		return nil
	end
	local def = enum_def(Magic.BOOKS_ENUM)
	if def == nil then
		return nil
	end
	local spells: { Spell } = {}
	for _, entry in ipairs(def.entries) do
		if entry.key == index then
			local ok = load_enum(int(entry.value) or -1, wanted, nil, spells)
			if not ok then
				return nil
			end
		end
	end
	if wanted == "standard" then
		local ok = load_enum(Magic.JEWELLERY_ENUM, wanted, "jewellery", spells)
		if not ok then
			return nil
		end
	end
	books[wanted] = spells
	return spells
end

function Magic.spell(spell: SpellRef, book: string?): Spell?
	if type(spell) == "table" then
		return spell
	end
	local spells = Magic.spells(book)
	if spells == nil then
		return nil
	end
	local wanted = key(spell)
	for _, s in ipairs(spells) do
		if key(s.name) == wanted then
			return s
		end
	end
	local current = if #spells > 0 then spells[1].book else book
	for _, other in pairs(Magic.BOOKS) do
		if other ~= current then
			local others = Magic.spells(other)
			for _, s in ipairs(others or {}) do
				if key(s.name) == wanted then
					return nil
				end
			end
		end
	end
	return nil
end

function Magic.spell_count(book: string?): number?
	local spells = Magic.spells(book)
	if spells == nil then
		return nil
	end
	local count = 0
	for _, s in ipairs(spells) do
		if s.kind ~= "menu" then
			count += 1
		end
	end
	return count
end

function Magic.is_open(): boolean
	return SidePanels.is_open(SidePanels.MAGIC_SPELLBOOK)
end

function Magic.open(timeout_ms: number?): boolean
	return SidePanels.open(SidePanels.MAGIC_SPELLBOOK, nil, timeout_ms)
end

function Magic.widget(spell: SpellRef): Widget?
	local s = Magic.spell(spell)
	if s == nil then
		return nil
	end
	local w = widget(Magic.GROUP, s.child)
	if w == nil then
		return nil
	end
	return w
end

function Magic.can_cast(spell: SpellRef): boolean
	local s = Magic.spell(spell)
	if s == nil then
		return false
	end
	local w = Magic.widget(s)
	if w == nil then
		return false
	end
	if w.sprite == -1 then
		return false
	end
	return w.sprite == s.castable[1] or w.sprite == s.castable[2]
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

local function visible(child: number): boolean
	local w = widget(Magic.GROUP, child)
	return w ~= nil and not w.hidden
end

local function on(s: Spell): (MenuEntry) -> boolean
	return function(entry: MenuEntry): boolean
		return entry.id == s.id
	end
end

local function default_option(w: Widget, s: Spell): string
	Mouse.move(w)
	local matches = on(s)
	local waited = 0
	while true do
		for _, entry in ipairs(Minimenu.entries() or {}) do
			if matches(entry) then
				return entry.option
			end
		end
		if waited >= Interact.HOVER_TIMEOUT then
			return "Cast"
		end
		sleep(POLL_MS)
		waited += POLL_MS
	end
end

local function press(s: Spell, w: Widget, option: string?): boolean
	local wanted = option or default_option(w, s)
	local ok = Interact.with(w, wanted, on(s), false)
	if not ok then
		return false
	end
	return true
end

function Magic.is_filtering(): boolean
	local off = Varbits.get(Magic.FILTERING_OFF_VARBIT)
	if off == nil then
		return false
	end
	return off == 0
end

function Magic.is_filter_on(filter: string): boolean
	local f = Magic.FILTERS[filter]
	if f == nil then
		Log.log("Magic", `unknown spell filter "{filter}"`)
		return false
	end
	local value = Varbits.get(f.varbit)
	if value == nil then
		return false
	end
	return value == 1
end

function Magic.is_filters_open(): boolean
	local panel = widget(Magic.GROUP, Magic.FILTERS_PANEL)
	if panel == nil then
		return false
	end
	return not panel.hidden
end

local function toggle_filters(open: boolean): boolean
	local current = Magic.is_filters_open()
	if current == nil then
		return false
	end
	if current == open then
		return true
	end
	local tab = widget(Magic.GROUP, 0)
	if tab == nil then
		return false
	end
	local at = Mouse.position()
	if
		at == nil or not (at.x >= tab.x and at.y >= tab.y and at.x < tab.x + tab.width and at.y < tab.y + tab.height)
	then
		Mouse.move(tab)
		sleep(100)
	end
	local button = widget(Magic.GROUP, Magic.FILTERS_BUTTON)
	if button == nil then
		return false
	end
	Mouse.click(button)
	if wait_until(function()
		return Magic.is_filters_open() == open
	end, FILTER_TIMEOUT_MS) then
		return true
	end
	Log.log("Magic", `the spell filters didn't {if open then "open" else "close"}`)
	return false
end

function Magic.open_filters(): boolean
	local opened = Magic.open()
	if not opened then
		return false
	end
	local filtering = Magic.is_filtering()
	if filtering == nil then
		return false
	end
	if not filtering then
		return false
	end
	return toggle_filters(true)
end

function Magic.close_filters(): boolean
	return toggle_filters(false)
end

function Magic.set_filter(filter: string, hide: boolean): boolean
	local f = Magic.FILTERS[filter]
	if f == nil then
		Log.log("Magic", `unknown spell filter "{filter}"`)
		return false
	end
	local on = Magic.is_filter_on(filter)
	if on == nil then
		return false
	end
	if on == hide then
		return true
	end
	local opened = Magic.open_filters()
	if not opened then
		return opened
	end
	local rows = widget_children(Magic.GROUP, Magic.FILTERS_ROWS)
	if rows == nil then
		return false
	end
	local row: Widget? = nil
	for _, label in ipairs(rows) do
		if label.text and string.find(label.text, f.text, 1, true) then
			local cx, cy = label.x + label.width // 2, label.y + label.height // 2
			for _, r in ipairs(rows) do
				if r.kind == 3 and cx >= r.x and cy >= r.y and cx < r.x + r.width and cy < r.y + r.height then
					row = r
				end
			end
		end
	end
	if row == nil then
		return false
	end
	local index = row.index
	local ok = Interact.with(row, "Change", function(entry: MenuEntry): boolean
		return entry.index == index
	end, false)
	if not ok then
		return false
	end
	if wait_until(function()
		return Magic.is_filter_on(filter) == hide
	end, FILTER_TIMEOUT_MS) then
		return true
	end
	Log.log("Magic", `the {filter} filter didn't change`)
	return false
end

function Magic.set_filtering(on: boolean): boolean
	local current = Magic.is_filtering()
	if current == nil then
		return false
	end
	if current == on then
		return true
	end
	local stone = SidePanels.button(SidePanels.MAGIC_SPELLBOOK)
	if stone == nil then
		return false
	end
	local ok = Interact.with(stone, if on then "Enable spell filtering" else "Disable spell filtering", nil, false)
	if not ok then
		return false
	end
	if wait_until(function()
		return Magic.is_filtering() == on
	end, FILTER_TIMEOUT_MS) then
		return true
	end
	Log.log("Magic", `spell filtering didn't turn {if on then "on" else "off"}`)
	return false
end

local function unfilter(s: Spell): boolean
	local filtering = Magic.is_filtering()
	if filtering == nil then
		return false
	end
	if not filtering then
		return false
	end
	local stages: { { string } } = { {}, {} }
	if Magic.FILTERS[s.kind] then
		table.insert(stages[1], s.kind)
	end
	local level = Stats.level("Magic")
	if level and level < s.level then
		table.insert(stages[1], "level")
	end
	if Magic.can_cast(s) == false then
		table.insert(stages[2], "runes")
		table.insert(stages[2], "requirements")
	end
	for _, stage in ipairs(stages) do
		local changed = false
		for _, filter in ipairs(stage) do
			if Magic.is_filter_on(filter) then
				local ok = Magic.set_filter(filter, false)
				if not ok then
					return ok
				end
				changed = true
			end
		end
		if changed then
			local closed = Magic.close_filters()
			if not closed then
				return closed
			end
			if wait_until(function()
				return visible(s.child)
			end, FILTER_TIMEOUT_MS) then
				return true
			end
		end
	end
	local ok = Magic.set_filtering(false)
	if not ok then
		return ok
	end
	if wait_until(function()
		return visible(s.child)
	end, FILTER_TIMEOUT_MS) then
		return true
	end
	return false
end

function Magic.find(spell: SpellRef): Widget?
	local s = Magic.spell(spell)
	if s == nil then
		return nil
	end
	local opened = Magic.open()
	if not opened then
		return nil
	end
	local closed = Magic.close_filters()
	if not closed then
		return nil
	end
	if visible(s.child) then
		return widget(Magic.GROUP, s.child)
	end
	if s.book == "standard" then
		local back = Magic.spell("Back", "standard")
		local in_menu = back ~= nil and visible(back.child)
		local wants_menu = s.menu == "jewellery"
		if back and in_menu ~= wants_menu then
			local button = if wants_menu then Magic.spell("Jewellery Enchantments", "standard") else back
			if button == nil then
				return nil
			end
			local w = Magic.find(button)
			if w == nil then
				return nil
			end
			local ok = press(button, w, nil)
			if not ok then
				return nil
			end
			wait_until(function()
				return visible(s.child) or visible(back.child) == wants_menu
			end, SHOW_TIMEOUT_MS)
			if visible(s.child) then
				return widget(Magic.GROUP, s.child)
			end
		end
	end
	local shown = unfilter(s)
	if not shown then
		return nil
	end
	return widget(Magic.GROUP, s.child)
end

function Magic.contains(spell: SpellRef): boolean
	local w = Magic.find(spell)
	if w == nil then
		return false
	end
	return true
end

function Magic.info_box(): Widget?
	local children = widget_children(Magic.GROUP, Magic.INFO)
	if children == nil then
		return nil
	end
	for _, child in ipairs(children) do
		if not child.hidden then
			return child
		end
	end
	return nil
end

function Magic.is_info_open(): boolean
	local box = Magic.info_box()
	return box ~= nil
end

function Magic.close_info(spell: SpellRef?): boolean
	local open = Magic.is_info_open()
	if open == nil then
		return false
	end
	if not open then
		return true
	end
	if spell then
		local w = Magic.widget(spell)
		if w == nil then
			return false
		end
		Mouse.move(w)
		return true
	end
	local tab = widget(Magic.GROUP, 0)
	if tab == nil then
		return false
	end
	local at = Mouse.position()
	local conn = connection()
	if at then
		local x1, y1, x2, y2 = tab.x - 10, tab.y - 10, tab.x + tab.width + 10, tab.y + tab.height + 10
		local options: { Point } = {
			{ x = x1, y = at.y },
			{ x = x2, y = at.y },
			{ x = at.x, y = y1 },
			{ x = at.x, y = y2 },
		}
		local best: Point? = nil
		for _, p in ipairs(options) do
			if p.x >= 0 and p.y >= 0 and p.x < conn.width and p.y < conn.height then
				if best == nil or Geometry.Point.distance(at, p) < Geometry.Point.distance(at, best) then
					best = p
				end
			end
		end
		if best then
			Mouse.move(best)
		end
	end
	if wait_until(function()
		return Magic.is_info_open() == false
	end, INFO_TIMEOUT_MS) then
		return true
	end
	Log.log("Magic", "the spell's info box didn't close")
	return false
end

function Magic.selected(): SelectedWidget?
	return selected_widget()
end

function Magic.selected_spell(): Spell?
	local current = selected_widget()
	if current == nil or current.group ~= Magic.GROUP then
		return nil
	end
	local spells = Magic.spells()
	if spells == nil then
		return nil
	end
	for _, s in ipairs(spells) do
		if s.id == current.id then
			return s
		end
	end
	return nil
end

function Magic.has_selected(): boolean
	local current = selected_widget()
	return current ~= nil
end

function Magic.is_selected(spell: SpellRef): boolean
	local s = Magic.spell(spell)
	if s == nil then
		return false
	end
	local current = selected_widget()
	return current ~= nil and current.id == s.id
end

function Magic.deselect(): boolean
	local current = selected_widget()
	if current == nil then
		return true
	end
	local at: Mouse.Target? = nil
	if current.group == Magic.GROUP and Magic.is_open() and visible(current.child) then
		at = widget(Magic.GROUP, current.child)
	end
	if at == nil then
		at = Mouse.position()
	end
	if at == nil then
		return false
	end
	local ok = Interact.with(at, "Cancel", nil, false)
	if not ok then
		return false
	end
	if wait_until(function()
		return selected_widget() == nil
	end, DESELECT_TIMEOUT_MS) then
		return true
	end
	Log.log("Magic", `{current.name} is still selected`)
	return false
end

function Magic.hover(spell: SpellRef): boolean
	local w = Magic.find(spell)
	if w == nil then
		return false
	end
	Mouse.move(w)
	return true
end

function Magic.click(spell: SpellRef, button: Mouse.Button?): boolean
	local w = Magic.find(spell)
	if w == nil then
		return false
	end
	Mouse.click(w, button)
	return true
end

function Magic.interact(spell: SpellRef, option: string?): boolean
	local s = Magic.spell(spell)
	if s == nil then
		return false
	end
	local w = Magic.find(s)
	if w == nil then
		return false
	end
	return press(s, w, option)
end

function Magic.was_cast(spell: SpellRef): boolean
	local s = Magic.spell(spell)
	if s == nil then
		return false
	end
	local current = selected_widget()
	if current then
		return current.id == s.id
	end
	local clicked = menu_click()
	return clicked ~= nil
		and clicked.entry.option == "Cast"
		and string.lower(clicked.entry.target) == string.lower(s.name)
end

function Magic.cast(spell: SpellRef, option: string?): boolean
	local s = Magic.spell(spell)
	if s == nil then
		return false
	end
	local current = selected_widget()
	if current and current.id == s.id then
		return true
	end
	local castable = Magic.can_cast(s)
	if castable == nil then
		return false
	end
	if not castable then
		return false
	end
	if current then
		local ok = Magic.deselect()
		if not ok then
			return false
		end
	end
	local ok = Magic.interact(s, option or "Cast")
	if not ok then
		return false
	end
	return Magic.was_cast(s)
end

return Magic
