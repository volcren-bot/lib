--!strict
local Host = require("@lib/host")
local widget = Host.widget
local widget_children = Host.widget_children
type Widget = Host.Widget
type Loc = Host.Loc
local Biometrics = require("@lib/main/antiban/biometrics")
local Keyboard = require("@lib/utils/input/keyboard")
local Log = require("@lib/utils/log")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Mouse = require("@lib/utils/input/mouse")
local Objects = require("@lib/main/entities/objects")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Walker = require("@lib/main/walker")
local Widgets = require("@lib/main/interfaces/widgets")

local Spirittree = {}

Spirittree.GROUP = 187
Spirittree.TITLE = 0
Spirittree.TITLE_INDEX = 1
Spirittree.TITLE_TEXT = "Spirit Tree Locations"
Spirittree.LIST = 3
Spirittree.CLOSE = 4
Spirittree.LOCKED_COLOUR = "5f5f5f"
Spirittree.CANCEL = "Cancel"
Spirittree.OBJECT = "Spirit tree"
Spirittree.OPTION = "Travel"
Spirittree.SPIRITUAL = "Spiritual Fairy Tree"
Spirittree.SPIRITUAL_OPTION = "Tree"

Spirittree.KEY_CHANCE = 0.5

Spirittree.OPEN_TIMEOUT_MS = 3000
Spirittree.CONFIRM_TIMEOUT_MS = 4000
Spirittree.POLL_MS = 50
Spirittree.SETTLE_MS = { 250, 500 }

export type Place =
	"Tree Gnome Village"
	| "Gnome Stronghold"
	| "Battlefield of Khazard"
	| "Grand Exchange"
	| "Feldip Hills"
	| "Prifddinas"
	| "Port Sarim"
	| "Etceteria"
	| "Brimhaven"
	| "Hosidius"
	| "Farming Guild"
	| "Your house (Rimmington)"
	| "Poison Waste"
	| "Laguna Aurorae"

Spirittree.Place = table.freeze({
	TreeGnomeVillage = "Tree Gnome Village",
	GnomeStronghold = "Gnome Stronghold",
	BattlefieldOfKhazard = "Battlefield of Khazard",
	GrandExchange = "Grand Exchange",
	FeldipHills = "Feldip Hills",
	Prifddinas = "Prifddinas",
	PortSarim = "Port Sarim",
	Etceteria = "Etceteria",
	Brimhaven = "Brimhaven",
	Hosidius = "Hosidius",
	FarmingGuild = "Farming Guild",
	YourHouse = "Your house (Rimmington)",
	PoisonWaste = "Poison Waste",
	LagunaAurorae = "Laguna Aurorae",
}) :: {
	TreeGnomeVillage: "Tree Gnome Village",
	GnomeStronghold: "Gnome Stronghold",
	BattlefieldOfKhazard: "Battlefield of Khazard",
	GrandExchange: "Grand Exchange",
	FeldipHills: "Feldip Hills",
	Prifddinas: "Prifddinas",
	PortSarim: "Port Sarim",
	Etceteria: "Etceteria",
	Brimhaven: "Brimhaven",
	Hosidius: "Hosidius",
	FarmingGuild: "Farming Guild",
	YourHouse: "Your house (Rimmington)",
	PoisonWaste: "Poison Waste",
	LagunaAurorae: "Laguna Aurorae",
}

export type Destination = {
	key: string,
	name: string,
	available: boolean,
	row: Widget,
}

function Spirittree.is_open(): boolean
	if not Toplevel.is_open(Spirittree.GROUP) then
		return false
	end
	for _, child in ipairs(widget_children(Spirittree.GROUP, Spirittree.TITLE) or {}) do
		if child.index == Spirittree.TITLE_INDEX then
			return child.text == Spirittree.TITLE_TEXT
		end
	end
	return false
end

function Spirittree.wait_open(timeout_ms: number?): boolean
	return Widgets.wait_for(Spirittree.is_open, timeout_ms or Spirittree.OPEN_TIMEOUT_MS, Spirittree.POLL_MS)
end

local function split(text: string): (string?, string?, boolean)
	local locked = string.find(text, "<col=" .. Spirittree.LOCKED_COLOUR .. ">", 1, true) ~= nil
	local plain = string.gsub(text, "<[^>]*>", "")
	local key, name = string.match(plain, "^%s*(%w):%s*(.-)%s*$")
	return key, name, locked
end

function Spirittree.destinations(): { Destination }?
	if not Spirittree.is_open() then
		return nil
	end
	local rows = widget_children(Spirittree.GROUP, Spirittree.LIST)
	if rows == nil then
		return nil
	end
	local found: { Destination } = {}
	for _, row in ipairs(rows) do
		if row.kind == 4 and not row.hidden and row.text ~= nil then
			local key, name, locked = split(row.text)
			if key ~= nil and name ~= nil and name ~= "" and name ~= Spirittree.CANCEL then
				table.insert(found, { key = key, name = name, available = not locked, row = row })
			end
		end
	end
	table.sort(found, function(a: Destination, b: Destination)
		return a.row.y < b.row.y
	end)
	return found
end

function Spirittree.names(available_only: boolean?): { string }?
	local all = Spirittree.destinations()
	if all == nil then
		return nil
	end
	local names: { string } = {}
	for _, d in ipairs(all) do
		if d.available or not available_only then
			table.insert(names, d.name)
		end
	end
	return names
end

function Spirittree.find(name: string): Destination?
	local all = Spirittree.destinations()
	if all == nil then
		return nil
	end
	local wanted = string.lower(name)
	local loose: Destination? = nil
	local loose_count = 0
	for _, d in ipairs(all) do
		local have = string.lower(d.name)
		if have == wanted then
			return d
		elseif string.find(have, wanted, 1, true) or string.find(wanted, have, 1, true) then
			loose = d
			loose_count += 1
		end
	end
	return if loose_count == 1 then loose else nil
end

function Spirittree.key_code(d: Destination): number?
	local code = string.byte(string.upper(d.key))
	if code ~= nil and ((code >= 48 and code <= 57) or (code >= 65 and code <= 90)) then
		return code
	end
	return nil
end

local function gone(): boolean
	return Widgets.wait_for(function()
		return not Spirittree.is_open()
	end, Spirittree.CONFIRM_TIMEOUT_MS, Spirittree.POLL_MS)
end

function Spirittree.select(place: Place, key_probability: number?): string?
	local name: string = place
	local d = Spirittree.find(name)
	if d == nil then
		return nil
	end
	if not d.available then
		Log.log("Spirittree", `{d.name} isn't unlocked`)
		return nil
	end
	local probability = if key_probability ~= nil and key_probability > 0
		then key_probability
		else Biometrics.random_double(Spirittree.KEY_CHANCE)
	local code = Spirittree.key_code(d)
	if code ~= nil and Random.chance(probability) then
		Keyboard.key_press(code)
		if gone() then
			return "key"
		end
		Log.log("Spirittree", `key {d.key} to {d.name} left the list open`)
		if not Spirittree.is_open() then
			return "key"
		end
		d = Spirittree.find(name)
		if d == nil then
			return nil
		end
	end
	Mouse.click(d.row)
	if gone() then
		return "click"
	end
	Log.log("Spirittree", `clicking {d.name} left the list open`)
	return nil
end

function Spirittree.close_button(): Widget?
	local w = widget(Spirittree.GROUP, Spirittree.CLOSE)
	if w == nil or w.hidden or not Spirittree.is_open() then
		return nil
	end
	return w
end

function Spirittree.close(key_probability: number?): boolean
	if not Spirittree.is_open() then
		return true
	end
	return Toplevel.close(
		Spirittree.GROUP,
		Spirittree.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

function Spirittree.nearest(): Loc?
	local me = Walker.position()
	if me == nil then
		return nil
	end
	local best: Loc? = nil
	local best_rank = math.huge
	for _, name in { Spirittree.OBJECT, Spirittree.SPIRITUAL } do
		for _, loc in ipairs(Objects.find(name) or {}) do
			local rank = Objects.distance(loc, me) + (if loc.plane == me.plane then 0 else 1000)
			if rank < best_rank then
				best, best_rank = loc, rank
			end
		end
	end
	return best
end

function Spirittree.open(tree: Loc?, walk: boolean?): boolean
	if Spirittree.is_open() then
		return true
	end
	if not Toplevel.escape_clear() then
		return false
	end
	local target = tree or Spirittree.nearest()
	if target == nil then
		Log.log("Spirittree", "no spirit tree around")
		return false
	end
	local option = if target.name == Spirittree.SPIRITUAL then Spirittree.SPIRITUAL_OPTION else Spirittree.OPTION
	local picked: boolean
	if walk ~= false then
		picked = Objects.approach(target, option)
	else
		picked = Objects.interact(target, option)
	end
	if not picked then
		local uptext = Minimenu.uptext()
		if uptext == nil or not string.find(string.lower(uptext), "spirit", 1, true) then
			return false
		end
		if not Minimenu.select(option) then
			return false
		end
	end
	if not Spirittree.wait_open() then
		return false
	end
	Random.sleep(Spirittree.SETTLE_MS[1], Spirittree.SETTLE_MS[2])
	return true
end

return Spirittree
