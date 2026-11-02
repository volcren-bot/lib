--!strict
-- The Lovakengj minecart network on Zeah (group 187, the game's generic `menu` list, titled "Minecart rides: Free", or with the fare in place of "Free"): a list of stops, each a row reading
-- `<col=735a28>K</col>: Name`, then a "(Cancel)" row. The list also shows the stop you are at. A row is chosen by clicking it or by pressing its key (1 to 9, then A, B, ...).
-- The carts are the "Minecart" objects, used with "Travel".
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

local Minecart = {}

Minecart.GROUP = 187
-- The component whose children are the title (index 1), and the one whose children are the rows.
Minecart.TITLE = 0
Minecart.TITLE_INDEX = 1
-- The start of the title: it ends with the fare ("Free", or the coins before The Forsaken Tower).
Minecart.TITLE_PREFIX = "Minecart rides"
Minecart.LIST = 3
Minecart.CLOSE = 4
-- The colour tag the game puts around a stop that is locked, and the text of the last row.
Minecart.LOCKED_COLOUR = "5f5f5f"
Minecart.CANCEL = "(Cancel)"
-- The cart objects and the option that opens the list.
Minecart.OBJECT = "Minecart"
Minecart.OPTION = "Travel"

-- The chance a biometric is rolled around for choosing a place with its key rather than a click.
Minecart.KEY_CHANCE = 0.5

Minecart.OPEN_TIMEOUT_MS = 3000
Minecart.CONFIRM_TIMEOUT_MS = 4000
Minecart.POLL_MS = 50
-- A pause (min, max in ms) after `open` finds the list, before it returns: a key pressed in the first moments after the list appears is ignored by the game.
Minecart.SETTLE_MS = { 250, 500 }

-- Every stop of the network, as the list names it. Use these rather than typing a name: `Minecart.select(Minecart.Stop.Lovakengj)`.
export type Stop =
	"Arceuus"
	| "Farming Guild"
	| "Hosidius South"
	| "Hosidius West"
	| "Kingstown"
	| "Kourend Woodland"
	| "Lovakengj"
	| "Mount Quidamortem"
	| "Northern Tundras"
	| "Port Piscarilius"
	| "Shayzien East"
	| "Shayzien West"

Minecart.Stop = table.freeze({
	Arceuus = "Arceuus",
	FarmingGuild = "Farming Guild",
	HosidiusSouth = "Hosidius South",
	HosidiusWest = "Hosidius West",
	Kingstown = "Kingstown",
	KourendWoodland = "Kourend Woodland",
	Lovakengj = "Lovakengj",
	MountQuidamortem = "Mount Quidamortem",
	NorthernTundras = "Northern Tundras",
	PortPiscarilius = "Port Piscarilius",
	ShayzienEast = "Shayzien East",
	ShayzienWest = "Shayzien West",
}) :: {
	Arceuus: "Arceuus",
	FarmingGuild: "Farming Guild",
	HosidiusSouth: "Hosidius South",
	HosidiusWest: "Hosidius West",
	Kingstown: "Kingstown",
	KourendWoodland: "Kourend Woodland",
	Lovakengj: "Lovakengj",
	MountQuidamortem: "Mount Quidamortem",
	NorthernTundras: "Northern Tundras",
	PortPiscarilius: "Port Piscarilius",
	ShayzienEast: "Shayzien East",
	ShayzienWest: "Shayzien West",
}

export type Destination = {
	-- the key before the name ("1", "A"), which is also the key that picks it
	key: string,
	name: string,
	-- false for a stop that is locked
	available: boolean,
	-- the row: where to click
	row: Widget,
}

-- The list is open when the group is and its title says so: the group is shared with other lists.
function Minecart.is_open(): boolean
	if not Toplevel.is_open(Minecart.GROUP) then
		return false
	end
	for _, child in ipairs(widget_children(Minecart.GROUP, Minecart.TITLE) or {}) do
		if child.index == Minecart.TITLE_INDEX then
			return string.sub(child.text or "", 1, #Minecart.TITLE_PREFIX) == Minecart.TITLE_PREFIX
		end
	end
	return false
end

-- Whether the list is open, polled for up to `timeout_ms` (3 seconds by default).
function Minecart.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Minecart.OPEN_TIMEOUT_MS)
	while true do
		if Minecart.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Minecart.POLL_MS)
	end
end

-- "<col=735a28>7</col>: <col=5f5f5f>Lovakengj</col>" is the key "7", the name "Lovakengj", and a stop drawn as locked (none have been seen).
local function split(text: string): (string?, string?, boolean)
	local locked = string.find(text, "<col=" .. Minecart.LOCKED_COLOUR .. ">", 1, true) ~= nil
	local plain = string.gsub(text, "<[^>]*>", "")
	local key, name = string.match(plain, "^%s*(%w):%s*(.-)%s*$")
	return key, name, locked
end

-- The stops in the list, top to bottom (the Cancel row is not one). Nil when it isn't open.
function Minecart.destinations(): { Destination }?
	if not Minecart.is_open() then
		return nil
	end
	local rows = widget_children(Minecart.GROUP, Minecart.LIST)
	if rows == nil then
		return nil
	end
	local found: { Destination } = {}
	for _, row in ipairs(rows) do
		if row.kind == 4 and not row.hidden and row.text ~= nil then
			local key, name, locked = split(row.text)
			if key ~= nil and name ~= nil and name ~= "" and name ~= Minecart.CANCEL then
				table.insert(found, { key = key, name = name, available = not locked, row = row })
			end
		end
	end
	table.sort(found, function(a: Destination, b: Destination)
		return a.row.y < b.row.y
	end)
	return found
end

-- The names of the stops (`available_only` leaves out any drawn as locked).
function Minecart.names(available_only: boolean?): { string }?
	local all = Minecart.destinations()
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

-- The stop called `name`, ignoring case: an exact name, else one name containing the other ("Grand" in "Grand Exchange") if only one fits. The key is never matched.
function Minecart.find(name: string): Destination?
	local all = Minecart.destinations()
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
function Minecart.key_code(d: Destination): number?
	local code = string.byte(string.upper(d.key))
	if code ~= nil and ((code >= 48 and code <= 57) or (code >= 65 and code <= 90)) then
		return code
	end
	return nil
end

local function gone(timeout_ms: number): boolean
	local deadline = time() + timeout_ms
	while true do
		if not Minecart.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Minecart.POLL_MS)
	end
end

-- Chooses a stop by name and returns how it was done: "key" (its key; chance `key_probability`, nil or 0 is a biometric around KEY_CHANCE) or "click" on its row.
-- A key that leaves the list open for CONFIRM_TIMEOUT_MS is followed by the click. Nil when no stop has that name, it is locked, or nothing worked. The trip is not waited for.
function Minecart.select(stop: Stop, key_probability: number?): string?
	local name: string = stop
	local d = Minecart.find(name)
	if d == nil then
		return nil
	end
	if not d.available then
		Log.log("Minecart", `{d.name} is locked`)
		return nil
	end
	local probability = if key_probability ~= nil and key_probability > 0
		then key_probability
		else Biometrics.random_double(Minecart.KEY_CHANCE)
	local code = Minecart.key_code(d)
	if code ~= nil and Random.chance(probability) then
		Keyboard.key_press(code)
		if gone(Minecart.CONFIRM_TIMEOUT_MS) then
			return "key"
		end
		Log.log("Minecart", `key {d.key} to {d.name} left the list open`)
		if not Minecart.is_open() then
			return "key"
		end
		d = Minecart.find(name)
		if d == nil then
			return nil
		end
	end
	Mouse.click(d.row)
	if gone(Minecart.CONFIRM_TIMEOUT_MS) then
		return "click"
	end
	Log.log("Minecart", `clicking {d.name} left the list open`)
	return nil
end

-- The close button, nil when the list isn't open.
function Minecart.close_button(): Widget?
	local w = widget(Minecart.GROUP, Minecart.CLOSE)
	if w == nil or w.hidden or not Minecart.is_open() then
		return nil
	end
	return w
end

-- Closes the list: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.
function Minecart.close(key_probability: number?): boolean
	if not Minecart.is_open() then
		return true
	end
	return Toplevel.close(
		Minecart.GROUP,
		Minecart.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

-- The nearest minecart among the objects loaded, by straight distance, with the plane you are on first. Nil when none is loaded.
function Minecart.nearest(): Loc?
	local me = Walker.position()
	if me == nil then
		return nil
	end
	local best: Loc? = nil
	local best_rank = math.huge
	for _, loc in ipairs(Objects.find(Minecart.OBJECT) or {}) do
		local rank = Objects.distance(loc, me) + (if loc.plane == me.plane then 0 else 1000)
		if rank < best_rank then
			best, best_rank = loc, rank
		end
	end
	return best
end

-- Opens the list from the nearest minecart (or `cart`), walking closer first unless `walk` is false, and waits for it; true when it is open (also if it already was).
function Minecart.open(cart: Loc?, walk: boolean?): boolean
	if Minecart.is_open() then
		return true
	end
	if not Toplevel.escape_clear() then
		return false
	end
	local target = cart or Minecart.nearest()
	if target == nil then
		Log.log("Minecart", "no minecart around")
		return false
	end
	local picked: boolean
	if walk ~= false then
		picked = Objects.approach(target, Minecart.OPTION)
	else
		picked = Objects.interact(target, Minecart.OPTION)
	end
	if not picked then
		-- the menu was open on something else, or the click missed: take the option if what's hovered is a minecart
		local uptext = Minimenu.uptext()
		if uptext == nil or not string.find(string.lower(uptext), "minecart", 1, true) then
			return false
		end
		if not Minimenu.select(Minecart.OPTION) then
			return false
		end
	end
	if not Minecart.wait_open() then
		return false
	end
	Random.sleep(Minecart.SETTLE_MS[1], Minecart.SETTLE_MS[2])
	return true
end

return Minecart
