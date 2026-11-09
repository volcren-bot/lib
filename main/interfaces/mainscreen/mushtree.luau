--!strict
local Host = require("@lib/host")
local widget = Host.widget
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

local Mushtree = {}

Mushtree.GROUP = 608
Mushtree.FRAME = 1
Mushtree.CLOSE_INDEX = 13
Mushtree.OBJECT = "Magic Mushtree"
Mushtree.OPTION = "Use"
Mushtree.CONTINUE = "Continue"
Mushtree.MAX_TREES = 4

Mushtree.KEY_CHANCE = 0.5

Mushtree.OPEN_TIMEOUT_MS = 3000
Mushtree.CONFIRM_TIMEOUT_MS = 4000
Mushtree.POLL_MS = 50
Mushtree.SETTLE_MS = { 250, 500 }

export type Tree = "House on the Hill" | "Verdant Valley" | "Sticky Swamp" | "Mushroom Meadow"

Mushtree.Tree = table.freeze({
	HouseOnTheHill = "House on the Hill",
	VerdantValley = "Verdant Valley",
	StickySwamp = "Sticky Swamp",
	MushroomMeadow = "Mushroom Meadow",
}) :: {
	HouseOnTheHill: "House on the Hill",
	VerdantValley: "Verdant Valley",
	StickySwamp: "Sticky Swamp",
	MushroomMeadow: "Mushroom Meadow",
}

export type Destination = {
	number: number,
	name: string,
	panel: Widget,
}

function Mushtree.is_open(): boolean
	return Toplevel.is_open(Mushtree.GROUP)
end

function Mushtree.wait_open(timeout_ms: number?): boolean
	return Widgets.wait_for(Mushtree.is_open, timeout_ms or Mushtree.OPEN_TIMEOUT_MS, Mushtree.POLL_MS)
end

local function split(text: string): (number?, string?)
	local plain = string.gsub(text, "<[^>]*>", "")
	local number, name = string.match(plain, "^%s*(%d+)%.%s*(.-)%s*$")
	return if number then tonumber(number) else nil, name
end

function Mushtree.destinations(): { Destination }?
	if not Mushtree.is_open() then
		return nil
	end
	local found: { Destination } = {}
	for child = 0, 120 do
		local text = widget(Mushtree.GROUP, child)
		if text ~= nil and text.kind == 4 and not text.hidden and text.text ~= nil then
			local number, name = split(text.text)
			local panel = widget(Mushtree.GROUP, child - 2)
			if number ~= nil and name ~= nil and name ~= "" and panel ~= nil and not panel.hidden then
				table.insert(found, { number = number, name = name, panel = panel })
			end
		end
	end
	table.sort(found, function(a: Destination, b: Destination)
		return a.number < b.number
	end)
	return found
end

function Mushtree.names(): { string }?
	local all = Mushtree.destinations()
	if all == nil then
		return nil
	end
	local names: { string } = {}
	for _, d in ipairs(all) do
		table.insert(names, d.name)
	end
	return names
end

function Mushtree.find(name: string): Destination?
	local all = Mushtree.destinations()
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
		return not Mushtree.is_open()
	end, Mushtree.CONFIRM_TIMEOUT_MS, Mushtree.POLL_MS)
end

function Mushtree.select(tree: Tree, key_probability: number?): string?
	local name: string = tree
	local d = Mushtree.find(name)
	if d == nil then
		return nil
	end
	local probability = if key_probability ~= nil and key_probability > 0
		then key_probability
		else Biometrics.random_double(Mushtree.KEY_CHANCE)
	if d.number >= 1 and d.number <= Mushtree.MAX_TREES and Random.chance(probability) then
		Keyboard.key_press(Keyboard.keys.NUM_0 + d.number)
		if gone() then
			return "key"
		end
		Log.log("Mushtree", `key {d.number} to {d.name} left the list open`)
		if not Mushtree.is_open() then
			return "key"
		end
		d = Mushtree.find(name)
		if d == nil then
			return nil
		end
	end
	Mouse.click(d.panel)
	if gone() then
		return "click"
	end
	Log.log("Mushtree", `clicking {d.name} left the list open`)
	return nil
end

function Mushtree.close_button(): Widget?
	for _, k in ipairs(Host.widget_children(Mushtree.GROUP, Mushtree.FRAME) or {}) do
		if k.index == Mushtree.CLOSE_INDEX and not k.hidden then
			return k
		end
	end
	return nil
end

function Mushtree.close(key_probability: number?): boolean
	return Toplevel.close(
		Mushtree.GROUP,
		Mushtree.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

function Mushtree.nearest(): Loc?
	local me = Walker.position()
	if me == nil then
		return nil
	end
	local best: Loc? = nil
	local best_rank = math.huge
	for _, loc in ipairs(Objects.find(Mushtree.OBJECT) or {}) do
		local rank = Objects.distance(loc, me) + (if loc.plane == me.plane then 0 else 1000)
		if rank < best_rank then
			best, best_rank = loc, rank
		end
	end
	return best
end

function Mushtree.open(tree: Loc?, walk: boolean?): boolean
	if Mushtree.is_open() then
		return true
	end
	if not Toplevel.escape_clear() then
		return false
	end
	local target = tree or Mushtree.nearest()
	if target == nil then
		Log.log("Mushtree", "no magic mushtree around")
		return false
	end
	local picked: boolean
	if walk ~= false then
		picked = Objects.approach(target, Mushtree.OPTION)
	else
		picked = Objects.interact(target, Mushtree.OPTION)
	end
	if not picked then
		local uptext = Minimenu.uptext()
		if uptext == nil or not string.find(string.lower(uptext), "mushtree", 1, true) then
			return false
		end
		if not Minimenu.select(Mushtree.OPTION) then
			return false
		end
	end
	if not Mushtree.wait_open() then
		return false
	end
	Random.sleep(Mushtree.SETTLE_MS[1], Mushtree.SETTLE_MS[2])
	return true
end

return Mushtree
