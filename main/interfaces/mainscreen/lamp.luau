--!strict
-- The experience lamp interface (group 240, `xpreward` in the cache): a grid of the skills and a button, opened by "Rub" on a lamp. Choosing a skill costs nothing, and the button's label then names it. "Confirm" is what spends the lamp.
local Host = require("@lib/host")
local menu = Host.menu
local widget = Host.widget
local widget_children = Host.widget_children
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
local ChatOptions = require("@lib/main/interfaces/chatbox/chat_options")
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Item = require("@lib/utils/item")
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Random = require("@lib/utils/math/random")
local Stats = require("@lib/main/interfaces/gametabs/stats")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
type SkillName = Stats.SkillName

local Lamp = {}

Lamp.GROUP = 240
-- The skills' cells, the title, the button (its label is child 9) and the close button.
Lamp.FIRST_SKILL = 2
Lamp.LAST_SKILL = 25
Lamp.TITLE = 26
Lamp.CONFIRM = 27
Lamp.CONFIRM_LABEL_INDEX = 9
Lamp.CLOSE = 28
-- The inventory's container, the option that opens the interface and the button's option.
Lamp.INVENTORY = 93
Lamp.OPTION = "Rub"
Lamp.CONFIRM_OPTION = "Confirm"
-- The items `open` looks for by default. Other things are called lamps too, like an oil lamp, so these are the names only; `open` can be given any other item.
Lamp.NAMES = {
	"Lamp",
	"Antique lamp",
	"Dusty lamp",
	"Ancient lamp",
	"Champion's lamp",
	"Lamp of knowledge",
	"Lamp of the Gatherer",
	"Event lamp",
	"Magic lamp",
	"Book of Knowledge",
}
-- The items opened by another option than `OPTION`: the Book of Knowledge (from the Surprise Exam) is read.
Lamp.OPTIONS = { ["Book of Knowledge"] = "Read" } :: { [string]: string }

Lamp.OPEN_TIMEOUT_MS = 3000
Lamp.HOVER_TIMEOUT_MS = 800
Lamp.CHOOSE_TIMEOUT_MS = 2400
Lamp.CONFIRM_TIMEOUT_MS = 4000
Lamp.MESSAGE_TIMEOUT_MS = 3000
Lamp.POLL_MS = 50
-- The menu follows the mouse a frame or so late, and would still show the cell before.
Lamp.SETTLE_MS = 150
-- A pause (min, max in ms) after `open` finds the interface, before it returns.
Lamp.OPEN_SETTLE_MS = { 250, 500 }

export type Cell = {
	name: string,
	-- where to hover and click
	area: Widget,
}

function Lamp.is_open(): boolean
	return Toplevel.is_open(Lamp.GROUP)
end

-- Whether the interface is open, polled for up to `timeout_ms` (3 seconds by default).
function Lamp.wait_open(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Lamp.OPEN_TIMEOUT_MS)
	while true do
		if Lamp.is_open() then
			return true
		end
		if time() >= deadline then
			return false
		end
		sleep(Lamp.POLL_MS)
	end
end

-- The skills in the interface's order. Each cell keeps its skill's name as its first menu option, so nothing is hovered. Nil when the interface isn't open.
function Lamp.skills(): { Cell }?
	if not Lamp.is_open() then
		return nil
	end
	local found: { Cell } = {}
	for child = Lamp.FIRST_SKILL, Lamp.LAST_SKILL do
		local w = widget(Lamp.GROUP, child)
		if w ~= nil and not w.hidden and w.action ~= nil and w.action ~= "" then
			table.insert(found, { name = w.action :: string, area = w })
		end
	end
	return found
end

-- The cell of `name`, ignoring case. Nil when the interface isn't open or it has no such skill.
function Lamp.find(name: string): Cell?
	local wanted = string.lower(name)
	for _, cell in ipairs(Lamp.skills() or {}) do
		if string.lower(cell.name) == wanted then
			return cell
		end
	end
	return nil
end

-- The skill chosen now, read from the button's label ("Confirm: Herblore"). Nil when none is, or the interface isn't open.
function Lamp.selected(): SkillName?
	if not Lamp.is_open() then
		return nil
	end
	for _, k in ipairs(widget_children(Lamp.GROUP, Lamp.CONFIRM) or {}) do
		if k.index == Lamp.CONFIRM_LABEL_INDEX and k.text ~= nil then
			return string.match(k.text, "^Confirm:%s*(.+)$") :: any
		end
	end
	return nil
end

-- Whether the menu where the mouse is now offers `option` first, waiting a moment for the game to show it.
local function offers(option: string): boolean
	local deadline = time() + Lamp.HOVER_TIMEOUT_MS
	while true do
		for _, entry in ipairs(menu() or {}) do
			if entry.option ~= "Cancel" then
				if entry.option == option then
					return true
				end
				break
			end
		end
		if time() >= deadline then
			return false
		end
		sleep(Lamp.POLL_MS)
	end
end

-- Chooses a skill (one of `Stats.Skill`), which spends nothing, and waits for the button to name it. True at once when it is chosen already. False when the interface has no such skill or the choice didn't take.
function Lamp.choose(skill: SkillName): boolean
	local name: string = skill
	local cell = Lamp.find(name)
	if cell == nil then
		return false
	end
	if Lamp.selected() == cell.name then
		return true
	end
	Mouse.move(cell.area)
	sleep(Lamp.SETTLE_MS)
	if not offers(cell.name) then
		Log.log("Lamp", `the menu didn't offer {cell.name}`)
		return false
	end
	Mouse.click()
	local deadline = time() + Lamp.CHOOSE_TIMEOUT_MS
	while time() < deadline do
		if Lamp.selected() == cell.name then
			return true
		end
		sleep(Lamp.POLL_MS)
	end
	Log.log("Lamp", `clicking {cell.name} didn't choose it`)
	return false
end

-- Dismisses the message box the game shows after "Confirm" ("Your wish has been granted!"), waiting up to `timeout_ms` for it (`MESSAGE_TIMEOUT_MS` by default). By key or click (`key_probability`; nil is the biometric), by click if the key doesn't take. True when one was dismissed.
function Lamp.close_message(key_probability: number?, timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Lamp.MESSAGE_TIMEOUT_MS)
	while not ChatOptions.contains_continue() do
		if time() >= deadline then
			return false
		end
		sleep(Lamp.POLL_MS)
	end
	if ChatOptions.continue_chat(key_probability) then
		return true
	end
	return ChatOptions.contains_continue() and ChatOptions.continue_chat(0)
end

-- Clicks "Confirm", which SPENDS THE LAMP on the chosen skill, waits for the interface to go and dismisses the message that follows. False, with no click, when no skill is chosen.
-- True once the lamp is spent, even if the message couldn't be dismissed, which is logged.
function Lamp.confirm(): boolean
	if Lamp.selected() == nil then
		Log.log("Lamp", "no skill is chosen")
		return false
	end
	local button = widget(Lamp.GROUP, Lamp.CONFIRM)
	if button == nil or button.hidden then
		return false
	end
	Mouse.move(button)
	sleep(Lamp.SETTLE_MS)
	if not offers(Lamp.CONFIRM_OPTION) then
		Log.log("Lamp", `the menu didn't offer {Lamp.CONFIRM_OPTION}`)
		return false
	end
	Mouse.click()
	local deadline = time() + Lamp.CONFIRM_TIMEOUT_MS
	while time() < deadline do
		if not Lamp.is_open() then
			if not Lamp.close_message() then
				Log.log("Lamp", "no message to dismiss after Confirm")
			end
			return true
		end
		sleep(Lamp.POLL_MS)
	end
	Log.log("Lamp", "clicking Confirm left the interface open")
	return false
end

-- The close button, nil when the interface isn't open.
function Lamp.close_button(): Widget?
	local w = widget(Lamp.GROUP, Lamp.CLOSE)
	if w == nil or w.hidden or not Lamp.is_open() then
		return nil
	end
	return w
end

-- Closes the interface, keeping the lamp: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.
function Lamp.close(key_probability: number?): boolean
	if not Lamp.is_open() then
		return true
	end
	return Toplevel.close(
		Lamp.GROUP,
		Lamp.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

-- The inventory slot of `item` (an id or a name), or by default of the first item called one of `NAMES`. Nil when none is held.
function Lamp.slot(item: (number | string)?): number?
	local held = Host.item_container(Lamp.INVENTORY) or {}
	if type(item) == "number" then
		for _, h in ipairs(held) do
			if h.id == item then
				return h.slot
			end
		end
		return nil
	end
	local ids: { number } = {}
	for i, h in ipairs(held) do
		ids[i] = h.id
	end
	local names = if #ids > 0 then Item.names(ids) or {} else {}
	local wanted = if item ~= nil then string.lower(item) else nil
	for i, h in ipairs(held) do
		local name = names[i]
		if name ~= nil then
			if wanted ~= nil then
				if string.lower(name) == wanted then
					return h.slot
				end
			elseif table.find(Lamp.NAMES, name) ~= nil then
				return h.slot
			end
		end
	end
	return nil
end

-- Opens the interface by rubbing a lamp in the inventory (`item`, an id or a name; by default the first of `NAMES`), which spends nothing yet, and waits for it. True when it is open, also if it already was. When it didn't work the second result says why.
function Lamp.open(item: (number | string)?): (boolean, string?)
	if Lamp.is_open() then
		return true, nil
	end
	local slot = Lamp.slot(item)
	if slot == nil then
		return false, "no lamp held"
	end
	if not Toplevel.escape_clear() then
		return false, "another interface is open"
	end
	local name: string? = nil
	for _, h in ipairs(Host.item_container(Lamp.INVENTORY) or {}) do
		if h.slot == slot then
			name = Item.name(h.id)
		end
	end
	local option = name and Lamp.OPTIONS[name] or Lamp.OPTION
	if not Inventory.interact_slot(slot, option) then
		return false, `couldn't {option} the {name or "lamp"}`
	end
	if not Lamp.wait_open() then
		return false, "the interface didn't open"
	end
	Random.sleep(Lamp.OPEN_SETTLE_MS[1], Lamp.OPEN_SETTLE_MS[2])
	return true, nil
end

-- Opens the interface if needed, chooses `skill` and confirms, SPENDING THE LAMP. When it didn't work the second result says why.
function Lamp.use(skill: SkillName, item: (number | string)?): (boolean, string?)
	local opened, why = Lamp.open(item)
	if not opened then
		return false, why
	end
	if not Lamp.choose(skill) then
		return false, `couldn't choose {skill}`
	end
	if not Lamp.confirm() then
		return false, "couldn't confirm"
	end
	return true, nil
end

return Lamp
