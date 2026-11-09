--!strict
local Host = require("@lib/host")
local menu = Host.menu
local widget = Host.widget
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
type Npc = Host.Npc
local ChatOptions = require("@lib/main/interfaces/chatbox/chat_options")
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Npcs = require("@lib/main/entities/npcs")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Widgets = require("@lib/main/interfaces/widgets")

local Certer = {}

Certer.GROUP = 184
Certer.PICTURE = 7
Certer.CLOSE = 11
Certer.ANSWER_TEXTS = { 1, 2, 3 }
Certer.ANSWER_BUTTONS = { 8, 9, 10 }
Certer.LETTERS = { "A", "B", "C" }
Certer.OPTION = "Talk-to"
Certer.SELECT_OPTION = "Select option"

Certer.OPEN_TIMEOUT_MS = 4000
Certer.HOVER_TIMEOUT_MS = 800
Certer.CONFIRM_TIMEOUT_MS = 4000
Certer.CHAT_TIMEOUT_MS = 8000
Certer.POLL_MS = 50
Certer.SETTLE_MS = 150
Certer.READ_MS = { 1200, 3200 }

export type Category = "food" | "weapon" | "armour" | "tool" | "jewel"

Certer.MODELS = {
	[8829] = "food",
	[8830] = "food",
	[8836] = "weapon",
	[8828] = "weapon",
	[8833] = "armour",
	[8832] = "armour",
	[8835] = "tool",
	[8837] = "tool",
	[8834] = "jewel",
	[8831] = "jewel",
} :: { [number]: Category }

Certer.WORDS = {
	food = { "fish", "food", "bread", "pie", "cake", "meat", "cheese" },
	weapon = { "sword", "dagger", "scimitar", "mace", "weapon", "battleaxe" },
	armour = { "helmet", "helm", "shield", "armour", "platebody", "platelegs" },
	tool = { "spade", "shears", "hammer", "tool", "pickaxe", "chisel", "tinderbox" },
	jewel = { "ring", "necklace", "amulet", "bracelet", "jewel", "gem" },
} :: { [Category]: { string } }

export type Answer = {
	letter: string,
	text: string,
	button: Widget,
}

function Certer.is_open(): boolean
	return Toplevel.is_open(Certer.GROUP)
end

function Certer.wait_open(timeout_ms: number?): boolean
	return Widgets.wait_for(Certer.is_open, timeout_ms or Certer.OPEN_TIMEOUT_MS, Certer.POLL_MS)
end

function Certer.model(): number?
	if not Certer.is_open() then
		return nil
	end
	local model = Host.widget_model(Certer.GROUP, Certer.PICTURE)
	return if model ~= nil then model.id else nil
end

function Certer.category(): Category?
	local model = Certer.model()
	return if model ~= nil then Certer.MODELS[model] else nil
end

function Certer.answers(): { Answer }?
	if not Certer.is_open() then
		return nil
	end
	local found: { Answer } = {}
	for i, letter in ipairs(Certer.LETTERS) do
		local text = widget(Certer.GROUP, Certer.ANSWER_TEXTS[i])
		local button = widget(Certer.GROUP, Certer.ANSWER_BUTTONS[i])
		if text ~= nil and text.text ~= nil and button ~= nil and not button.hidden then
			table.insert(found, { letter = letter, text = text.text :: string, button = button })
		end
	end
	return found
end

local function fits(text: string, category: Category): boolean
	local lower = string.lower(text)
	for _, word in ipairs(Certer.WORDS[category]) do
		if string.find(lower, `%f[%a]{word}%f[%A]`) ~= nil then
			return true
		end
	end
	return false
end

function Certer.correct(): Answer?
	local model = Certer.model()
	local category = if model ~= nil then Certer.MODELS[model] else nil
	if category == nil then
		Log.log("Certer", `the picture's model {model or "?"} isn't a known quiz item`)
		return nil
	end
	local found: Answer? = nil
	local shown: { string } = {}
	for _, answer in ipairs(Certer.answers() or {}) do
		table.insert(shown, answer.text)
		if fits(answer.text, category) then
			if found ~= nil then
				Log.log("Certer", `several answers fit {category}: {table.concat(shown, " ")}`)
				return nil
			end
			found = answer
		end
	end
	if found == nil then
		Log.log("Certer", `no answer fits {category}: {table.concat(shown, " ")}`)
	end
	return found
end

local function offers(answer: Answer): boolean
	local option = `{Certer.SELECT_OPTION} {answer.letter}`
	return Widgets.wait_for(function(): boolean
		for _, entry in ipairs(menu() or {}) do
			if entry.option ~= "Cancel" then
				return entry.option == option
			end
		end
		return false
	end, Certer.HOVER_TIMEOUT_MS, Certer.POLL_MS)
end

function Certer.select(answer: Answer): boolean
	Mouse.move(answer.button)
	sleep(Certer.SETTLE_MS)
	if not offers(answer) then
		Log.log("Certer", `the menu didn't offer answer {answer.letter}`)
		return false
	end
	Mouse.click()
	if
		Widgets.wait_within(function(): boolean
			return not Certer.is_open()
		end, Certer.CONFIRM_TIMEOUT_MS, Certer.POLL_MS)
	then
		return true
	end
	Log.log("Certer", `clicking answer {answer.letter} left the quiz open`)
	return false
end

function Certer.finish_chat(timeout_ms: number?): boolean
	local deadline = time() + (timeout_ms or Certer.CHAT_TIMEOUT_MS)
	local continued = false
	while time() < deadline do
		if ChatOptions.contains_continue() then
			if not ChatOptions.continue_chat() and ChatOptions.contains_continue() then
				ChatOptions.continue_chat(0)
			end
			continued = true
		elseif continued then
			return true
		end
		sleep(Certer.POLL_MS)
	end
	return continued
end

function Certer.close_button(): Widget?
	local w = widget(Certer.GROUP, Certer.CLOSE)
	if w == nil or w.hidden or not Certer.is_open() then
		return nil
	end
	return w
end

function Certer.close(key_probability: number?): boolean
	if not Certer.is_open() then
		return true
	end
	return Toplevel.close(
		Certer.GROUP,
		Certer.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

function Certer.open(npc: Npc): (boolean, string?)
	if Certer.is_open() then
		return true, nil
	end
	if not Npcs.interact(npc, Certer.OPTION) then
		return false, `couldn't {Certer.OPTION} {npc.name}`
	end
	if not Certer.wait_open() then
		return false, "the quiz didn't open"
	end
	return true, nil
end

function Certer.solve(): (boolean, string?)
	local answer = Certer.correct()
	if answer == nil then
		Certer.close()
		return false, "no answer fits the picture"
	end
	Random.sleep(Certer.READ_MS[1], Certer.READ_MS[2])
	if not Certer.select(answer) then
		return false, `couldn't choose answer {answer.letter}`
	end
	Certer.finish_chat()
	return true, nil
end

return Certer
