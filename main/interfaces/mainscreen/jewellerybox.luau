--!strict
local Host = require("@lib/host")
local menu = Host.menu
local widget_children = Host.widget_children
local sleep = Host.sleep
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
local Widgets = require("@lib/main/interfaces/widgets")

local Jewellerybox = {}

Jewellerybox.GROUP = 590
Jewellerybox.FRAME = 1
Jewellerybox.CLOSE_INDEX = 11
Jewellerybox.FIRST_PANEL = 2
Jewellerybox.LAST_PANEL = 7
Jewellerybox.OBJECT = "jewellery box"
Jewellerybox.OPTION = "Teleport Menu"

Jewellerybox.KEY_CHANCE = 0.5

Jewellerybox.OPEN_TIMEOUT_MS = 3000
Jewellerybox.HOVER_TIMEOUT_MS = 800
Jewellerybox.CONFIRM_TIMEOUT_MS = 4000
Jewellerybox.POLL_MS = 50
Jewellerybox.HOVER_SETTLE_MS = 150
Jewellerybox.SETTLE_MS = { 250, 500 }

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
	key: string,
	jewellery: string,
	available: boolean,
	area: Widget,
}

function Jewellerybox.is_open(): boolean
	return Toplevel.is_open(Jewellerybox.GROUP)
end

function Jewellerybox.wait_open(timeout_ms: number?): boolean
	return Widgets.wait_for(Jewellerybox.is_open, timeout_ms or Jewellerybox.OPEN_TIMEOUT_MS, Jewellerybox.POLL_MS)
end

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

local function gone(): boolean
	return Widgets.wait_for(function()
		return not Jewellerybox.is_open()
	end, Jewellerybox.CONFIRM_TIMEOUT_MS, Jewellerybox.POLL_MS)
end

local function offers(name: string): boolean
	return Widgets.wait_for(function(): boolean
		for _, entry in ipairs(menu() or {}) do
			if entry.option ~= "Cancel" then
				return entry.option == name
			end
		end
		return false
	end, Jewellerybox.HOVER_TIMEOUT_MS, Jewellerybox.POLL_MS)
end

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
		if gone() then
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
	if gone() then
		return "click"
	end
	Log.log("Jewellerybox", `clicking {d.name} left the menu open`)
	return nil
end

function Jewellerybox.close_button(): Widget?
	for _, k in ipairs(widget_children(Jewellerybox.GROUP, Jewellerybox.FRAME) or {}) do
		if k.index == Jewellerybox.CLOSE_INDEX and not k.hidden then
			return k
		end
	end
	return nil
end

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
