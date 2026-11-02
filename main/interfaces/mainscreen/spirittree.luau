--!strict
-- The spirit tree network (group 187, the game's generic `menu` list, titled "Spirit Tree Locations"): a list of places, each a row reading `<col=735a28>K</col>: Name`, then a "Cancel" row.
-- Places you haven't unlocked are drawn grey (`<col=5f5f5f>Name</col>`) but still offer "Continue", so the colour is the only way to tell them apart.
-- A row is chosen by clicking it or by pressing its key (1 to 9, then A, B, ...). The trees are the "Spirit tree" objects, used with "Travel".
local Host = require("@lib/host")
local widget = Host.widget
local widget_children = Host.widget_children
local sleep = Host.sleep
local time = Host.time
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

local Spirittree = {}

Spirittree.GROUP = 187
-- The component whose children are the title (index 1), and the one whose children are the rows.
Spirittree.TITLE = 0
Spirittree.TITLE_INDEX = 1
Spirittree.TITLE_TEXT = "Spirit Tree Locations"
Spirittree.LIST = 3
Spirittree.CLOSE = 4
-- The colour tag the game puts around a place you haven't unlocked, and the text of the last row.
Spirittree.LOCKED_COLOUR = "5f5f5f"
Spirittree.CANCEL = "Cancel"
-- The tree objects and the option that opens the list.
Spirittree.OBJECT = "Spirit tree"
Spirittree.OPTION = "Travel"

-- The chance a biometric is rolled around for choosing a place with its key rather than a click.
Spirittree.KEY_CHANCE = 0.5

Spirittree.OPEN_TIMEOUT_MS = 3000
Spirittree.CONFIRM_TIMEOUT_MS = 4000
Spirittree.POLL_MS = 50
-- A pause (min, max in ms) after `open` finds the list, before it returns: a key pressed in the first moments after the list appears is ignored by the game.
Spirittree.SETTLE_MS = { 250, 500 }

-- Every place of the network, as the list names it. Use these rather than typing a name: `Spirittree.select(Spirittree.Place.GnomeStronghold)`.
-- `YourHouse` is named after where your house is (Rimmington here); with the house elsewhere the list reads differently, and `find` still matches it loosely by "Your house".
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
	-- the key before the name ("1", "A"), which is also the key that picks it
	key: string,
	name: string,
	-- false for a place you haven't unlocked
	available: boolean,
	-- the row: where to click
	row: Widget,
}

-- The list is open when the group is and its title says so: the group is shared with other lists.
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

-- Whether the list is open, polled for up to `timeout_ms` (3 seconds by default).
function Spirittree.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Spirittree.OPEN_TIMEOUT_MS)
	while true do
		if Spirittree.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Spirittree.POLL_MS)
	end
end

-- "<col=735a28>7</col>: <col=5f5f5f>Port Sarim</col>" is the key "7", the name "Port Sarim", and a place not unlocked.
local function split(text: string): (string?, string?, boolean)
	local locked = string.find(text, "<col=" .. Spirittree.LOCKED_COLOUR .. ">", 1, true) ~= nil
	local plain = string.gsub(text, "<[^>]*>", "")
	local key, name = string.match(plain, "^%s*(%w):%s*(.-)%s*$")
	return key, name, locked
end

-- The places in the list, top to bottom (the Cancel row is not one). Nil when it isn't open.
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

-- The names of the places, with `available_only` only those you have unlocked.
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

-- The place called `name`, ignoring case: an exact name, else one name containing the other ("Grand" in "Grand Exchange") if only one fits. The key is never matched.
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

-- The key code of a destination's key (digits and capital letters are their own codes).
function Spirittree.key_code(d: Destination): number?
	local code = string.byte(string.upper(d.key))
	if code ~= nil and ((code >= 48 and code <= 57) or (code >= 65 and code <= 90)) then
		return code
	end
	return nil
end

local function gone(timeout_ms: number): boolean
	local deadline = time() + timeout_ms
	while true do
		if not Spirittree.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Spirittree.POLL_MS)
	end
end

-- Chooses a place by name and returns how it was done: "key" (its key; chance `key_probability`, nil or 0 is a biometric around KEY_CHANCE) or "click" on its row.
-- A key that leaves the list open for CONFIRM_TIMEOUT_MS is followed by the click. Nil when no place has that name, it isn't unlocked, or nothing worked. The trip is not waited for.
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
		if gone(Spirittree.CONFIRM_TIMEOUT_MS) then
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
	if gone(Spirittree.CONFIRM_TIMEOUT_MS) then
		return "click"
	end
	Log.log("Spirittree", `clicking {d.name} left the list open`)
	return nil
end

-- The close button, nil when the list isn't open.
function Spirittree.close_button(): Widget?
	local w = widget(Spirittree.GROUP, Spirittree.CLOSE)
	if w == nil or w.hidden or not Spirittree.is_open() then
		return nil
	end
	return w
end

-- Closes the list: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.
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

-- The nearest spirit tree among the objects loaded, by straight distance, with the plane you are on first. Nil when none is loaded.
function Spirittree.nearest(): Loc?
	local me = Walker.position()
	if me == nil then
		return nil
	end
	local best: Loc? = nil
	local best_rank = math.huge
	for _, loc in ipairs(Objects.find(Spirittree.OBJECT) or {}) do
		local rank = Objects.distance(loc, me) + (if loc.plane == me.plane then 0 else 1000)
		if rank < best_rank then
			best, best_rank = loc, rank
		end
	end
	return best
end

-- Opens the list from the nearest spirit tree (or `tree`), walking closer first unless `walk` is false, and waits for it; true when it is open (also if it already was).
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
	local picked: boolean
	if walk ~= false then
		picked = Objects.approach(target, Spirittree.OPTION)
	else
		picked = Objects.interact(target, Spirittree.OPTION)
	end
	if not picked then
		-- the menu was open on something else, or the click missed: take the option if what's hovered is a spirit tree
		local uptext = Minimenu.uptext()
		if uptext == nil or not string.find(string.lower(uptext), "spirit tree", 1, true) then
			return false
		end
		if not Minimenu.select(Spirittree.OPTION) then
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
