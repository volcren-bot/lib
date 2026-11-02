--!strict
-- The magic mushtree network on Fossil Island (group 608, `fossil_mushtrees` in the cache): a list of the four trees, each a panel reading `<col=8f8f8f>1.</col> House on the Hill`.
-- Picking a tree is a click on its panel ("Continue") or its number key. The trees themselves are the "Magic Mushtree" objects, used with "Use".
local Host = require("@lib/host")
local widget = Host.widget
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
type Loc = Host.Loc
type Tile = { x: number, y: number, plane: number? }
local Biometrics = require("@lib/main/antiban/biometrics")
local Keyboard = require("@lib/utils/input/keyboard")
local Log = require("@lib/utils/log")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Mouse = require("@lib/utils/input/mouse")
local Objects = require("@lib/main/entities/objects")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Walker = require("@lib/main/walker")

local Mushtree = {}

Mushtree.GROUP = 608
-- The frame holds the title and, as its child 13, the close button.
Mushtree.FRAME = 1
Mushtree.CLOSE_INDEX = 13
-- The tree objects and the option that opens the list.
Mushtree.OBJECT = "Magic Mushtree"
Mushtree.OPTION = "Use"
-- A panel's menu option, and the highest number a tree has (the numbers are the keys 1 to 4).
Mushtree.CONTINUE = "Continue"
Mushtree.MAX_TREES = 4

-- The chance a biometric is rolled around for choosing a tree with its number key rather than a click.
Mushtree.KEY_CHANCE = 0.5

Mushtree.OPEN_TIMEOUT_MS = 3000
Mushtree.CONFIRM_TIMEOUT_MS = 4000
Mushtree.POLL_MS = 50
-- A pause (min, max in ms) after `open` finds the list, before it returns: a key pressed in the first moments after the list appears is ignored by the game.
Mushtree.SETTLE_MS = { 250, 500 }

-- Every tree of the network, as the list names it. Use these rather than typing a name: `Mushtree.select(Mushtree.Tree.VerdantValley)`.
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
	-- the number before the name, which is also the key that picks it
	number: number,
	name: string,
	-- the whole panel: where to click
	panel: Widget,
}

function Mushtree.is_open(): boolean
	return Toplevel.is_open(Mushtree.GROUP)
end

-- Whether the list is open, polled for up to `timeout_ms` (3 seconds by default).
function Mushtree.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Mushtree.OPEN_TIMEOUT_MS)
	while true do
		if Mushtree.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Mushtree.POLL_MS)
	end
end

-- "<col=8f8f8f>1.</col> House on the Hill" is the number 1 and the name "House on the Hill".
local function split(text: string): (number?, string?)
	local plain = string.gsub(text, "<[^>]*>", "")
	local number, name = string.match(plain, "^%s*(%d+)%.%s*(.-)%s*$")
	return if number then tonumber(number) else nil, name
end

-- The trees in the list, in order. Nil when it isn't open.
function Mushtree.destinations(): { Destination }?
	if not Mushtree.is_open() then
		return nil
	end
	local found: { Destination } = {}
	-- each panel is a layer (the click area), then its frame, its text (the name) and a model; the text is the second child after the layer
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

-- The tree called `name`, ignoring case: an exact name, else one name containing the other ("Hill" in "House on the Hill") if only one fits.
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

local function gone(timeout_ms: number): boolean
	local deadline = time() + timeout_ms
	while true do
		if not Mushtree.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Mushtree.POLL_MS)
	end
end

-- Chooses a tree by name and returns how it was done: "key" (its number key; chance `key_probability`, nil or 0 is a biometric around KEY_CHANCE) or "click" on its panel.
-- A key that leaves the list open for CONFIRM_TIMEOUT_MS is followed by the click. Nil when no tree has that name or nothing worked. The trip itself is not waited for.
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
		if gone(Mushtree.CONFIRM_TIMEOUT_MS) then
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
	if gone(Mushtree.CONFIRM_TIMEOUT_MS) then
		return "click"
	end
	Log.log("Mushtree", `clicking {d.name} left the list open`)
	return nil
end

-- The close button, nil when the list isn't open.
function Mushtree.close_button(): Widget?
	for _, k in ipairs(Host.widget_children(Mushtree.GROUP, Mushtree.FRAME) or {}) do
		if k.index == Mushtree.CLOSE_INDEX and not k.hidden then
			return k
		end
	end
	return nil
end

-- Closes the list: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.
function Mushtree.close(key_probability: number?): boolean
	return Toplevel.close(
		Mushtree.GROUP,
		Mushtree.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

-- The nearest magic mushtree among the objects loaded, by straight distance on the plane you are on first. Nil when none is loaded.
function Mushtree.nearest(): Loc?
	local me = Walker.position()
	if me == nil then
		return nil
	end
	local best: Loc? = nil
	local best_rank = math.huge
	for _, loc in ipairs(Objects.find(Mushtree.OBJECT) or {}) do
		-- another plane is never nearer than one on yours
		local rank = Objects.distance(loc, me) + (if loc.plane == me.plane then 0 else 1000)
		if rank < best_rank then
			best, best_rank = loc, rank
		end
	end
	return best
end

-- Opens the list from the nearest magic mushtree (or `tree`), walking closer first unless `walk` is false, and waits for it; true when it is open (also if it already was).
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
		-- the menu was open on something else, or the click missed: take the option if what's hovered is a mushtree
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
