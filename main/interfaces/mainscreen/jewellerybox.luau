--!strict
-- The jewellery box in a player's house (group 590, `poh_jewellery_box` in the cache): panels of teleports by the jewellery they copy, opened by "Teleport Menu" on the box. A bigger box has more panels.
-- Each destination is a line like `<col=ccccff>1:</col> Emir's Arena`, whose letter or digit is also its key; one the account can't use is struck through. The trip is free. The box's "Remove" option takes it out of the house, and nothing here can click it.
local Host = require("@lib/host")
local menu = Host.menu
local widget_children = Host.widget_children
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
type Loc = Host.Loc
local Biometrics = require("@lib/main/antiban/biometrics")
local Keyboard = require("@lib/utils/input/keyboard")
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Objects = require("@lib/main/entities/objects")
local Player = require("@lib/main/player")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")

local Jewellerybox = {}

Jewellerybox.GROUP = 590
-- The frame holds the close button as its child 11, and these components are the panels.
Jewellerybox.FRAME = 1
Jewellerybox.CLOSE_INDEX = 11
Jewellerybox.FIRST_PANEL = 2
Jewellerybox.LAST_PANEL = 7
-- What the box objects are called (any size), and the option that opens the menu.
Jewellerybox.OBJECT = "jewellery box"
Jewellerybox.OPTION = "Teleport Menu"

-- The chance a biometric is rolled around for choosing a destination with its key rather than a click.
Jewellerybox.KEY_CHANCE = 0.5

Jewellerybox.OPEN_TIMEOUT_MS = 3000
Jewellerybox.HOVER_TIMEOUT_MS = 800
Jewellerybox.CONFIRM_TIMEOUT_MS = 4000
Jewellerybox.POLL_MS = 50
-- The menu follows the mouse a frame or so late, and would still show the line before.
Jewellerybox.HOVER_SETTLE_MS = 150
-- A pause (min, max in ms) after `open` finds the menu, before it returns: a key pressed in the first moments after a list appears can be ignored by the game.
Jewellerybox.SETTLE_MS = { 250, 500 }

-- Every destination of the biggest box, as the game names them. Use these rather than typing a name: `Jewellerybox.select(Jewellerybox.Place.GrandExchange)`.
export type Place =
	"Emir's Arena"
	| "Castle Wars"
	| "Ferox Enclave"
	| "Fortis Colosseum"
	| "Burthorpe"
	| "Barbarian Outpost"
	| "Corporeal Beast"
	| "Tears of Guthix"
	| "Wintertodt Camp"
	| "Warriors' Guild"
	| "Champions' Guild"
	| "Monastery"
	| "Ranging Guild"
	| "Fishing Guild"
	| "Mining Guild"
	| "Crafting Guild"
	| "Cooking Guild"
	| "Woodcutting Guild"
	| "Farming Guild"
	| "Miscellania"
	| "Grand Exchange"
	| "Falador Park"
	| "Dondakan's Rock"
	| "Edgeville"
	| "Karamja"
	| "Draynor Village"
	| "Al Kharid"

Jewellerybox.Place = table.freeze({
	EmirsArena = "Emir's Arena",
	CastleWars = "Castle Wars",
	FeroxEnclave = "Ferox Enclave",
	FortisColosseum = "Fortis Colosseum",
	Burthorpe = "Burthorpe",
	BarbarianOutpost = "Barbarian Outpost",
	CorporealBeast = "Corporeal Beast",
	TearsofGuthix = "Tears of Guthix",
	WintertodtCamp = "Wintertodt Camp",
	WarriorsGuild = "Warriors' Guild",
	ChampionsGuild = "Champions' Guild",
	Monastery = "Monastery",
	RangingGuild = "Ranging Guild",
	FishingGuild = "Fishing Guild",
	MiningGuild = "Mining Guild",
	CraftingGuild = "Crafting Guild",
	CookingGuild = "Cooking Guild",
	WoodcuttingGuild = "Woodcutting Guild",
	FarmingGuild = "Farming Guild",
	Miscellania = "Miscellania",
	GrandExchange = "Grand Exchange",
	FaladorPark = "Falador Park",
	DondakansRock = "Dondakan's Rock",
	Edgeville = "Edgeville",
	Karamja = "Karamja",
	DraynorVillage = "Draynor Village",
	AlKharid = "Al Kharid",
}) :: {
	EmirsArena: "Emir's Arena",
	CastleWars: "Castle Wars",
	FeroxEnclave: "Ferox Enclave",
	FortisColosseum: "Fortis Colosseum",
	Burthorpe: "Burthorpe",
	BarbarianOutpost: "Barbarian Outpost",
	CorporealBeast: "Corporeal Beast",
	TearsofGuthix: "Tears of Guthix",
	WintertodtCamp: "Wintertodt Camp",
	WarriorsGuild: "Warriors' Guild",
	ChampionsGuild: "Champions' Guild",
	Monastery: "Monastery",
	RangingGuild: "Ranging Guild",
	FishingGuild: "Fishing Guild",
	MiningGuild: "Mining Guild",
	CraftingGuild: "Crafting Guild",
	CookingGuild: "Cooking Guild",
	WoodcuttingGuild: "Woodcutting Guild",
	FarmingGuild: "Farming Guild",
	Miscellania: "Miscellania",
	GrandExchange: "Grand Exchange",
	FaladorPark: "Falador Park",
	DondakansRock: "Dondakan's Rock",
	Edgeville: "Edgeville",
	Karamja: "Karamja",
	DraynorVillage: "Draynor Village",
	AlKharid: "Al Kharid",
}

export type Destination = {
	name: string,
	-- the letter or digit before the name, which is also the key that picks it
	key: string,
	-- the jewellery its panel is titled with
	jewellery: string,
	-- false when it is struck through: the account can't use it
	available: boolean,
	-- the line: where to hover and click
	area: Widget,
}

function Jewellerybox.is_open(): boolean
	return Toplevel.is_open(Jewellerybox.GROUP)
end

-- Whether the menu is open, polled for up to `timeout_ms` (3 seconds by default).
function Jewellerybox.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Jewellerybox.OPEN_TIMEOUT_MS)
	while true do
		if Jewellerybox.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Jewellerybox.POLL_MS)
	end
end

-- The destinations in the menu's order, read from the widgets without hovering. Nil when the menu isn't open.
function Jewellerybox.destinations(): { Destination }?
	if not Jewellerybox.is_open() then
		return nil
	end
	local found: { Destination } = {}
	for panel = Jewellerybox.FIRST_PANEL, Jewellerybox.LAST_PANEL do
		local title = ""
		local lines: { Widget } = {}
		for _, w in ipairs(widget_children(Jewellerybox.GROUP, panel) or {}) do
			if w.kind == 4 and not w.hidden and w.text ~= nil then
				if w.action ~= nil and w.action ~= "" then
					table.insert(lines, w)
				else
					title = w.text :: string
				end
			end
		end
		for _, line in ipairs(lines) do
			local text = line.text :: string
			local key = string.match(text, "^<col=%x+>(%w):</col>")
			if key ~= nil then
				table.insert(found, {
					name = line.action :: string,
					key = key,
					jewellery = title,
					available = string.find(text, "<str>", 1, true) == nil,
					area = line,
				})
			end
		end
	end
	return found
end

function Jewellerybox.names(): { string }?
	local all = Jewellerybox.destinations()
	if all == nil then
		return nil
	end
	local names: { string } = {}
	for _, d in ipairs(all) do
		table.insert(names, d.name)
	end
	return names
end

-- The destination called `name`, ignoring case: an exact name, else one name containing the other ("Exchange" in "Grand Exchange") if only one fits.
function Jewellerybox.find(name: string): Destination?
	local all = Jewellerybox.destinations()
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

local function gone(timeout_ms: number): boolean
	local deadline = time() + timeout_ms
	while true do
		if not Jewellerybox.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Jewellerybox.POLL_MS)
	end
end

-- Whether the menu where the mouse is now offers this destination, waiting a moment for the game to show it.
local function offers(name: string): boolean
	local deadline = time() + Jewellerybox.HOVER_TIMEOUT_MS
	while true do
		for _, entry in ipairs(menu() or {}) do
			if entry.option ~= "Cancel" then
				if entry.option == name then
					return true
				end
				break
			end
		end
		if time() >= deadline then
			return false
		end
		sleep(Jewellerybox.POLL_MS)
	end
end

-- Chooses a destination by name and returns how it was done: "key" (its key; chance `key_probability`, nil or 0 is a biometric around KEY_CHANCE) or "click" on its line.
-- A key that leaves the menu open for CONFIRM_TIMEOUT_MS is followed by the click, which only happens once the menu under the mouse offers that destination. Nil when no destination has that name, it is struck through, or nothing worked. The trip itself is not waited for.
function Jewellerybox.select(place: Place, key_probability: number?): string?
	local name: string = place
	local d = Jewellerybox.find(name)
	if d == nil then
		return nil
	end
	if not d.available then
		Log.log("Jewellerybox", `{d.name} is struck through`)
		return nil
	end
	local probability = if key_probability ~= nil and key_probability > 0
		then key_probability
		else Biometrics.random_double(Jewellerybox.KEY_CHANCE)
	if Random.chance(probability) then
		Keyboard.key_press(string.byte(string.upper(d.key)) :: number)
		if gone(Jewellerybox.CONFIRM_TIMEOUT_MS) then
			return "key"
		end
		Log.log("Jewellerybox", `key {d.key} to {d.name} left the menu open`)
		d = Jewellerybox.find(name)
		if d == nil then
			return nil
		end
	end
	Mouse.move(d.area)
	sleep(Jewellerybox.HOVER_SETTLE_MS)
	if not offers(d.name) then
		Log.log("Jewellerybox", `the menu didn't offer {d.name}`)
		return nil
	end
	Mouse.click()
	if gone(Jewellerybox.CONFIRM_TIMEOUT_MS) then
		return "click"
	end
	Log.log("Jewellerybox", `clicking {d.name} left the menu open`)
	return nil
end

-- The close button, nil when the menu isn't open.
function Jewellerybox.close_button(): Widget?
	for _, k in ipairs(widget_children(Jewellerybox.GROUP, Jewellerybox.FRAME) or {}) do
		if k.index == Jewellerybox.CLOSE_INDEX and not k.hidden then
			return k
		end
	end
	return nil
end

-- Closes the menu: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.
function Jewellerybox.close(key_probability: number?): boolean
	if not Jewellerybox.is_open() then
		return true
	end
	return Toplevel.close(
		Jewellerybox.GROUP,
		Jewellerybox.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

-- The nearest jewellery box of any size, nil when there is none.
function Jewellerybox.nearest(): Loc?
	local me = Player.position()
	if me == nil then
		return nil
	end
	local best: Loc? = nil
	local best_distance = math.huge
	for _, loc in ipairs(Objects.find() or {}) do
		if loc.name ~= nil and string.find(string.lower(loc.name), Jewellerybox.OBJECT, 1, true) then
			local d = Objects.distance(loc, me)
			if d < best_distance then
				best, best_distance = loc, d
			end
		end
	end
	return best
end

-- Opens the menu from the nearest box (or `box`), walking closer first unless `walk` is false, and waits for it; true when it is open (also if it already was). When it didn't work the second result says why.
function Jewellerybox.open(box: Loc?, walk: boolean?): (boolean, string?)
	if Jewellerybox.is_open() then
		return true, nil
	end
	if not Toplevel.escape_clear() then
		return false, "another interface is open"
	end
	local target = box or Jewellerybox.nearest()
	if target == nil then
		Log.log("Jewellerybox", "no jewellery box around")
		return false, "no jewellery box around"
	end
	local picked: boolean
	if walk ~= false then
		picked = Objects.approach(target, Jewellerybox.OPTION)
	else
		picked = Objects.interact(target, Jewellerybox.OPTION)
	end
	if not picked then
		return false, `couldn't use {Jewellerybox.OPTION} on the box`
	end
	if not Jewellerybox.wait_open() then
		return false, "the menu didn't open"
	end
	Random.sleep(Jewellerybox.SETTLE_MS[1], Jewellerybox.SETTLE_MS[2])
	return true, nil
end

return Jewellerybox
