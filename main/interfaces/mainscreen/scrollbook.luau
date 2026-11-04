--!strict
-- The master scroll book (group 597, `bookofscrolls` in the cache): a grid of the teleport scrolls it can hold, opened by "Open" on the book. Each cell has the scroll's name and how many are held.
-- A cell's first option, "Activate", reads the scroll and teleports at once, spending one. Its other options are "Set as default" and "Remove" (which takes the scrolls out), and nothing here clicks those.
local Host = require("@lib/host")
local menu = Host.menu
local widget = Host.widget
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")

local Scrollbook = {}

Scrollbook.GROUP = 597
-- The components searched for cells and their labels, and the close button.
Scrollbook.LAST_COMPONENT = 100
Scrollbook.CLOSE = 3
-- The book, the inventory's container, the book's option that opens it, and a cell's option that teleports.
Scrollbook.BOOK = 21389
Scrollbook.INVENTORY = 93
Scrollbook.OPTION = "Open"
Scrollbook.ACTIVATE = "Activate"

Scrollbook.OPEN_TIMEOUT_MS = 3000
Scrollbook.HOVER_TIMEOUT_MS = 800
Scrollbook.CONFIRM_TIMEOUT_MS = 4000
Scrollbook.POLL_MS = 50
-- The menu follows the mouse a frame or so late, and would still show the cell before.
Scrollbook.SETTLE_MS = 150
-- A pause (min, max in ms) after `open` finds the book, before it returns.
Scrollbook.OPEN_SETTLE_MS = { 250, 500 }

-- Every scroll, as the book names it. Use these rather than typing a name: `Scrollbook.select(Scrollbook.Name.Watson)`.
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
	-- how many the book holds
	count: number,
	-- the cell: where to hover and click
	area: Widget,
}

function Scrollbook.is_open(): boolean
	return Toplevel.is_open(Scrollbook.GROUP)
end

-- Whether the book is open, polled for up to `timeout_ms` (3 seconds by default).
function Scrollbook.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Scrollbook.OPEN_TIMEOUT_MS)
	while true do
		if Scrollbook.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Scrollbook.POLL_MS)
	end
end

-- A cell's text as one line: "Arde-<br>aglais" is "Ardeaglais".
local function plain(text: string): string
	local joined = string.gsub(text, "%-<br>", "")
	joined = string.gsub(joined, "<br>", " ")
	return (string.gsub(joined, "<[^>]+>", ""))
end

-- Letters only, in lowercase, so that the data's "Lumberyard" fits the book's "Lumber-yard".
local function letters(text: string): string
	return (string.gsub(string.lower(text), "%A", ""))
end

local function inside(w: Widget, cell: Widget): boolean
	return w.x >= cell.x and w.y >= cell.y and w.x < cell.x + cell.width and w.y < cell.y + cell.height
end

-- The scrolls in the book, in reading order, including those with none held. Nil when it isn't open. The components aren't in a regular order, so a cell's labels are the ones inside it.
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

-- The scroll called `name`, ignoring case and punctuation, with or without "teleport" and "scroll" after it: an exact name, else one name containing the other if only one scroll fits.
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

-- Whether the menu where the mouse is now would activate this scroll on a left click, waiting a moment for the game to offer it. The entry's id is the cell's, because some scrolls have no target text.
local function offers(scroll: Scroll): boolean
	local deadline = time() + Scrollbook.HOVER_TIMEOUT_MS
	while true do
		for _, entry in ipairs(menu() or {}) do
			if entry.option ~= "Cancel" then
				if entry.option == Scrollbook.ACTIVATE and entry.id == scroll.area.id then
					return true
				end
				break
			end
		end
		if time() >= deadline then
			return false
		end
		sleep(Scrollbook.POLL_MS)
	end
end

local function gone(timeout_ms: number): boolean
	local deadline = time() + timeout_ms
	while true do
		if not Scrollbook.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Scrollbook.POLL_MS)
	end
end

-- Activates the scroll, which teleports and spends one, and waits for the book to go. False when no scroll has that name, none is held, the menu under the mouse didn't offer it, or the book stayed open.
-- The click only happens once the menu offers "Activate" on that scroll, so a wrong spot costs nothing. The teleport is not waited for.
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
	if gone(Scrollbook.CONFIRM_TIMEOUT_MS) then
		return true
	end
	Log.log("Scrollbook", `clicking {scroll.name} left the book open`)
	return false
end

-- The close button, nil when the book isn't open.
function Scrollbook.close_button(): Widget?
	local w = widget(Scrollbook.GROUP, Scrollbook.CLOSE)
	if w == nil or w.hidden or not Scrollbook.is_open() then
		return nil
	end
	return w
end

-- Closes the book: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.
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

-- The inventory slot of the book, nil when it isn't held.
function Scrollbook.book_slot(): number?
	for _, item in ipairs(Host.item_container(Scrollbook.INVENTORY) or {}) do
		if item.id == Scrollbook.BOOK then
			return item.slot
		end
	end
	return nil
end

-- Opens the book from the inventory and waits for it; true when it is open (also if it already was). When it didn't work the second result says why.
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
