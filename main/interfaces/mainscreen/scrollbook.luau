--!strict
local Host = require("@lib/host")
local menu = Host.menu
local widget = Host.widget
local sleep = Host.sleep
type Widget = Host.Widget
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Widgets = require("@lib/main/interfaces/widgets")

local Scrollbook = {}

Scrollbook.GROUP = 597
Scrollbook.LAST_COMPONENT = 100
Scrollbook.CLOSE = 3
Scrollbook.BOOK = 21389
Scrollbook.INVENTORY = 93
Scrollbook.OPTION = "Open"
Scrollbook.ACTIVATE = "Activate"

Scrollbook.OPEN_TIMEOUT_MS = 3000
Scrollbook.HOVER_TIMEOUT_MS = 800
Scrollbook.CONFIRM_TIMEOUT_MS = 4000
Scrollbook.POLL_MS = 50
Scrollbook.SETTLE_MS = 150
Scrollbook.OPEN_SETTLE_MS = { 250, 500 }

export type Name =
	"Nardah"
	| "Digsite"
	| "Feldip Hills"
	| "Lunar Isle"
	| "Mort'ton"
	| "Pest Control"
	| "Piscatoris"
	| "Tai Bwo Wannai"
	| "Iorwerth Camp"
	| "Mos Le' Harmless"
	| "Lumber-yard"
	| "Zul-andra"
	| "Key Master"
	| "Revenant caves"
	| "Watson"
	| "Guthixian Temple"
	| "Spider Cave"
	| "Colossal Wyrm"
	| "Chasm of Fire"
	| "Ardeaglais"

Scrollbook.Name = table.freeze({
	Nardah = "Nardah",
	Digsite = "Digsite",
	FeldipHills = "Feldip Hills",
	LunarIsle = "Lunar Isle",
	Mortton = "Mort'ton",
	PestControl = "Pest Control",
	Piscatoris = "Piscatoris",
	TaiBwoWannai = "Tai Bwo Wannai",
	IorwerthCamp = "Iorwerth Camp",
	MosLeHarmless = "Mos Le' Harmless",
	Lumberyard = "Lumber-yard",
	Zulandra = "Zul-andra",
	KeyMaster = "Key Master",
	RevenantCaves = "Revenant caves",
	Watson = "Watson",
	GuthixianTemple = "Guthixian Temple",
	SpiderCave = "Spider Cave",
	ColossalWyrm = "Colossal Wyrm",
	ChasmOfFire = "Chasm of Fire",
	Ardeaglais = "Ardeaglais",
}) :: {
	Nardah: "Nardah",
	Digsite: "Digsite",
	FeldipHills: "Feldip Hills",
	LunarIsle: "Lunar Isle",
	Mortton: "Mort'ton",
	PestControl: "Pest Control",
	Piscatoris: "Piscatoris",
	TaiBwoWannai: "Tai Bwo Wannai",
	IorwerthCamp: "Iorwerth Camp",
	MosLeHarmless: "Mos Le' Harmless",
	Lumberyard: "Lumber-yard",
	Zulandra: "Zul-andra",
	KeyMaster: "Key Master",
	RevenantCaves: "Revenant caves",
	Watson: "Watson",
	GuthixianTemple: "Guthixian Temple",
	SpiderCave: "Spider Cave",
	ColossalWyrm: "Colossal Wyrm",
	ChasmOfFire: "Chasm of Fire",
	Ardeaglais: "Ardeaglais",
}

export type Scroll = {
	name: string,
	count: number,
	area: Widget,
}

function Scrollbook.is_open(): boolean
	return Toplevel.is_open(Scrollbook.GROUP)
end

function Scrollbook.wait_open(timeout_ms: number?): boolean
	return Widgets.wait_for(Scrollbook.is_open, timeout_ms or Scrollbook.OPEN_TIMEOUT_MS, Scrollbook.POLL_MS)
end

local function plain(text: string): string
	local joined = string.gsub(text, "%-<br>", "")
	joined = string.gsub(joined, "<br>", " ")
	return (string.gsub(joined, "<[^>]+>", ""))
end

local function letters(text: string): string
	return (string.gsub(string.lower(text), "%A", ""))
end

local function inside(w: Widget, cell: Widget): boolean
	return w.x >= cell.x and w.y >= cell.y and w.x < cell.x + cell.width and w.y < cell.y + cell.height
end

function Scrollbook.scrolls(): { Scroll }?
	if not Scrollbook.is_open() then
		return nil
	end
	local cells: { Widget } = {}
	local labels: { Widget } = {}
	for child = 0, Scrollbook.LAST_COMPONENT do
		local w = widget(Scrollbook.GROUP, child)
		if w ~= nil and not w.hidden then
			if w.action == Scrollbook.ACTIVATE then
				table.insert(cells, w)
			elseif w.kind == 4 and w.text ~= nil then
				table.insert(labels, w)
			end
		end
	end
	local found: { Scroll } = {}
	for _, cell in ipairs(cells) do
		local name: string? = nil
		local count: number? = nil
		for _, label in ipairs(labels) do
			if inside(label, cell) then
				local text = plain(label.text :: string)
				local number = tonumber(text)
				if number ~= nil then
					count = number
				else
					name = text
				end
			end
		end
		if name ~= nil then
			table.insert(found, { name = name, count = count or 0, area = cell })
		end
	end
	table.sort(found, function(a: Scroll, b: Scroll)
		return if a.area.y ~= b.area.y then a.area.y < b.area.y else a.area.x < b.area.x
	end)
	return found
end

function Scrollbook.find(name: string): Scroll?
	local all = Scrollbook.scrolls()
	if all == nil then
		return nil
	end
	local wanted = letters(name)
	wanted = string.gsub(wanted, "scroll$", "")
	wanted = string.gsub(wanted, "teleport$", "")
	local loose: Scroll? = nil
	local loose_count = 0
	for _, s in ipairs(all) do
		local have = letters(s.name)
		if have == wanted then
			return s
		elseif wanted ~= "" and (string.find(have, wanted, 1, true) or string.find(wanted, have, 1, true)) then
			loose = s
			loose_count += 1
		end
	end
	return if loose_count == 1 then loose else nil
end

local function offers(scroll: Scroll): boolean
	return Widgets.wait_for(function(): boolean
		for _, entry in ipairs(menu() or {}) do
			if entry.option ~= "Cancel" then
				return entry.option == Scrollbook.ACTIVATE and entry.id == scroll.area.id
			end
		end
		return false
	end, Scrollbook.HOVER_TIMEOUT_MS, Scrollbook.POLL_MS)
end

local function gone(): boolean
	return Widgets.wait_for(function()
		return not Scrollbook.is_open()
	end, Scrollbook.CONFIRM_TIMEOUT_MS, Scrollbook.POLL_MS)
end

function Scrollbook.select(name: Name): boolean
	local scroll = Scrollbook.find(name)
	if scroll == nil then
		return false
	end
	if scroll.count <= 0 then
		Log.log("Scrollbook", `no {scroll.name} scrolls in the book`)
		return false
	end
	Mouse.move(scroll.area)
	sleep(Scrollbook.SETTLE_MS)
	if not offers(scroll) then
		Log.log("Scrollbook", `the menu didn't offer {scroll.name}`)
		return false
	end
	Mouse.click()
	if gone() then
		return true
	end
	Log.log("Scrollbook", `clicking {scroll.name} left the book open`)
	return false
end

function Scrollbook.close_button(): Widget?
	local w = widget(Scrollbook.GROUP, Scrollbook.CLOSE)
	if w == nil or w.hidden or not Scrollbook.is_open() then
		return nil
	end
	return w
end

function Scrollbook.close(key_probability: number?): boolean
	if not Scrollbook.is_open() then
		return true
	end
	return Toplevel.close(
		Scrollbook.GROUP,
		Scrollbook.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

function Scrollbook.book_slot(): number?
	for _, item in ipairs(Host.item_container(Scrollbook.INVENTORY) or {}) do
		if item.id == Scrollbook.BOOK then
			return item.slot
		end
	end
	return nil
end

function Scrollbook.open(): (boolean, string?)
	if Scrollbook.is_open() then
		return true, nil
	end
	local slot = Scrollbook.book_slot()
	if slot == nil then
		return false, "no master scroll book held"
	end
	if not Toplevel.escape_clear() then
		return false, "another interface is open"
	end
	if not Inventory.interact_slot(slot, Scrollbook.OPTION) then
		return false, `couldn't {Scrollbook.OPTION} the book`
	end
	if not Scrollbook.wait_open() then
		return false, "the book didn't open"
	end
	Random.sleep(Scrollbook.OPEN_SETTLE_MS[1], Scrollbook.OPEN_SETTLE_MS[2])
	return true, nil
end

return Scrollbook
