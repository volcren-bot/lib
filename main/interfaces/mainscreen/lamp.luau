--!strict
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
local Widgets = require("@lib/main/interfaces/widgets")
type SkillName = Stats.SkillName

local Lamp = {}

Lamp.GROUP = 240
Lamp.FIRST_SKILL = 2
Lamp.LAST_SKILL = 25
Lamp.TITLE = 26
Lamp.CONFIRM = 27
Lamp.CONFIRM_LABEL_INDEX = 9
Lamp.CLOSE = 28
Lamp.INVENTORY = 93
Lamp.OPTION = "Rub"
Lamp.CONFIRM_OPTION = "Confirm"
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
Lamp.OPTIONS = { ["Book of Knowledge"] = "Read" } :: { [string]: string }

Lamp.OPEN_TIMEOUT_MS = 3000
Lamp.HOVER_TIMEOUT_MS = 800
Lamp.CHOOSE_TIMEOUT_MS = 2400
Lamp.CONFIRM_TIMEOUT_MS = 4000
Lamp.MESSAGE_TIMEOUT_MS = 3000
Lamp.POLL_MS = 50
Lamp.SETTLE_MS = 150
Lamp.OPEN_SETTLE_MS = { 250, 500 }

export type Cell = {
	name: string,
	area: Widget,
}

function Lamp.is_open(): boolean
	return Toplevel.is_open(Lamp.GROUP)
end

function Lamp.wait_open(timeout_ms: number?): boolean
	return Widgets.wait_for(Lamp.is_open, timeout_ms or Lamp.OPEN_TIMEOUT_MS, Lamp.POLL_MS)
end

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

function Lamp.find(name: string): Cell?
	local wanted = string.lower(name)
	for _, cell in ipairs(Lamp.skills() or {}) do
		if string.lower(cell.name) == wanted then
			return cell
		end
	end
	return nil
end

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

local function offers(option: string): boolean
	return Widgets.wait_for(function(): boolean
		for _, entry in ipairs(menu() or {}) do
			if entry.option ~= "Cancel" then
				return entry.option == option
			end
		end
		return false
	end, Lamp.HOVER_TIMEOUT_MS, Lamp.POLL_MS)
end

local function press(area: Widget, option: string): boolean
	Mouse.move(area)
	sleep(Lamp.SETTLE_MS)
	if not offers(option) then
		Log.log("Lamp", `the menu didn't offer {option}`)
		return false
	end
	Mouse.click()
	return true
end

function Lamp.choose(skill: SkillName): boolean
	local name: string = skill
	local cell = Lamp.find(name)
	if cell == nil then
		return false
	end
	if Lamp.selected() == cell.name then
		return true
	end
	if not press(cell.area, cell.name) then
		return false
	end
	if
		Widgets.wait_within(function(): boolean
			return Lamp.selected() == cell.name
		end, Lamp.CHOOSE_TIMEOUT_MS, Lamp.POLL_MS)
	then
		return true
	end
	Log.log("Lamp", `clicking {cell.name} didn't choose it`)
	return false
end

function Lamp.close_message(key_probability: number?, timeout_ms: number?): boolean
	if not Widgets.wait_for(ChatOptions.contains_continue, timeout_ms or Lamp.MESSAGE_TIMEOUT_MS, Lamp.POLL_MS) then
		return false
	end
	if ChatOptions.continue_chat(key_probability) then
		return true
	end
	return ChatOptions.contains_continue() and ChatOptions.continue_chat(0)
end

function Lamp.confirm(): boolean
	if Lamp.selected() == nil then
		Log.log("Lamp", "no skill is chosen")
		return false
	end
	local button = widget(Lamp.GROUP, Lamp.CONFIRM)
	if button == nil or button.hidden then
		return false
	end
	if not press(button, Lamp.CONFIRM_OPTION) then
		return false
	end
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

function Lamp.close_button(): Widget?
	local w = widget(Lamp.GROUP, Lamp.CLOSE)
	if w == nil or w.hidden or not Lamp.is_open() then
		return nil
	end
	return w
end

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
