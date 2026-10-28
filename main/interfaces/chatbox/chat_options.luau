--!strict
local Host = require("../../../host")
local widget = Host.widget
local widget_children = Host.widget_children
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
type MenuEntry = Host.MenuEntry
local Biometrics = require("../../antiban/biometrics")
local Chat = require("./chat")
local Chatbox = require("./chatbox")
local Interact = require("../../interact")
local Keyboard = require("../../../utils/input/keyboard")
local Log = require("../../../utils/log")
local Random = require("../../../utils/math/random")

local ChatOptions = {}

ChatOptions.GROUP = Chatbox.CHATMENU
ChatOptions.OPTIONS = 1
ChatOptions.TITLE_COLOR = 0x800000
ChatOptions.SPEECH = table.freeze({
	[Chatbox.CHAT_LEFT] = { name = 4, text = 6 },
	[Chatbox.CHAT_RIGHT] = { name = 4, text = 6 },
})
ChatOptions.CONTINUE_TEXT = "Click here to continue"
ChatOptions.WAIT_TEXT = "Please wait..."
ChatOptions.LEVEL_UP_TEXT = "Congratulations, you've just advanced"

export type Option = {
	text: string,
	raw_text: string,
	index: number,
	key: number,
	widget: Widget,
}

local POLL_MS = 50
local WAIT_MS = 600
local CHANGE_TIMEOUT_MS = 3000
local SETTLE_MS = 600
local CONTINUE_UNTIL_MS = 10000
local LEVEL_UP_MS = 8000

local function texts(): ({ Widget }?, Widget?)
	local open = Chatbox.is_open(ChatOptions.GROUP)
	if open == nil then
		return nil, nil
	end
	if not open then
		return {}, nil
	end
	local kids = widget_children(ChatOptions.GROUP, ChatOptions.OPTIONS)
	if kids == nil then
		return nil, nil
	end
	local options: { Widget } = {}
	local title: Widget? = nil
	for _, k in ipairs(kids) do
		if not k.hidden and k.text and k.text ~= "" then
			if title == nil and #options == 0 and k.text_color == ChatOptions.TITLE_COLOR then
				title = k
			else
				table.insert(options, k)
			end
		end
	end
	return options, title
end

function ChatOptions.get(): { Option }?
	local rows = texts()
	if rows == nil then
		return nil
	end
	local options: { Option } = {}
	for i, row in ipairs(rows) do
		local text = Chat.clean(row.text :: string)
		local key = if string.find(text, ChatOptions.CONTINUE_TEXT, 1, true)
			then Keyboard.keys.SPACE
			else Keyboard.keys.NUM_0 + i
		table.insert(options, { text = text, raw_text = row.text :: string, index = i, key = key, widget = row })
	end
	return options
end

function ChatOptions.to_string(options: { Option }?): string?
	local list = options
	if list == nil then
		list = ChatOptions.get()
		if list == nil then
			return nil
		end
	end
	local lines: { string } = {}
	for _, o in ipairs(list :: { Option }) do
		table.insert(lines, o.text)
	end
	return table.concat(lines, "\n")
end

local function contains(text: string, part: string, match_case: boolean?): boolean
	if match_case then
		return string.find(text, part, 1, true) ~= nil
	end
	return string.find(string.lower(text), string.lower(part), 1, true) ~= nil
end

function ChatOptions.find(text: string, match_case: boolean?): Option?
	local options = ChatOptions.get()
	if options == nil then
		return nil
	end
	for _, o in ipairs(options) do
		if contains(o.text, text, match_case) then
			return o
		end
	end
	return nil
end

function ChatOptions.index_of(text: string, match_case: boolean?): number?
	local option = ChatOptions.find(text, match_case)
	return if option then option.index else 0
end

function ChatOptions.contains(text: string, match_case: boolean?): boolean
	local option = ChatOptions.find(text, match_case)
	return option ~= nil
end

local function wait(check: () -> boolean, timeout_ms: number): boolean
	local waited = 0
	while true do
		local done = check()
		if done == nil then
			return false
		end
		if done or waited >= timeout_ms then
			return done
		end
		sleep(POLL_MS)
		waited += POLL_MS
	end
end

function ChatOptions.wait_option(text: string, match_case: boolean?, timeout_ms: number?): boolean
	return wait(function()
		return ChatOptions.contains(text, match_case)
	end, timeout_ms or WAIT_MS)
end

local function snapshot(): (string?, boolean?)
	local groups = Chatbox.interfaces()
	if groups == nil then
		return nil, nil
	end
	local text = Chatbox.text()
	if text == nil then
		return nil, nil
	end
	local ready = table.find(groups, ChatOptions.GROUP) ~= nil
		or string.find(text, ChatOptions.CONTINUE_TEXT, 1, true) ~= nil
	return table.concat(groups :: { any }, ",") .. "|" .. text, ready
end

local function wait_change(before: string): boolean
	local waited, stable, last = 0, 0, before
	while true do
		local now, ready = snapshot()
		if now == nil then
			return false
		end
		local waiting = string.find(now, ChatOptions.WAIT_TEXT, 1, true) ~= nil
		if now ~= before and not waiting then
			if ready or stable >= SETTLE_MS then
				return true
			end
		end
		stable = if now == last then stable + POLL_MS else 0
		last = now
		if waited >= CHANGE_TIMEOUT_MS then
			return now ~= before and not waiting
		end
		sleep(POLL_MS)
		waited += POLL_MS
	end
end

local function press(w: Widget, key: number, key_probability: number?): boolean
	local probability = key_probability or Biometrics.random_double(0.5)
	if Random.chance(probability) then
		Keyboard.key_press(key)
		return true
	end
	local function on_widget(entry: MenuEntry): boolean
		return entry.id == w.id and (w.index < 0 or entry.index == w.index)
	end
	local clicked = Interact.with(w, "Continue", on_widget, false)
	return clicked
end

function ChatOptions.select(text: string, match_case: boolean?, key_probability: number?): boolean
	local option = ChatOptions.find(text, match_case)
	if option == nil then
		return false
	end
	local before = snapshot()
	if before == nil then
		return false
	end
	local pressed = press(option.widget, option.key, key_probability)
	if not pressed then
		Log.log("ChatOptions", `couldn't pick "{option.text}"`)
		return pressed
	end
	local moved = wait_change(before)
	if not moved then
		Log.log("ChatOptions", `the dialogue didn't move on after "{option.text}"`)
		return moved
	end
	return true
end

function ChatOptions.continue_widget(): Widget?
	local groups = Chatbox.interfaces()
	if groups == nil then
		return nil
	end
	local function is_continue(w: Widget): boolean
		local text = if w.text then Chat.clean(w.text) else ""
		return not w.hidden and (text == ChatOptions.CONTINUE_TEXT or text == ChatOptions.WAIT_TEXT)
	end
	for _, group in ipairs(groups) do
		local child = 0
		while true do
			local w = widget(group, child)
			if w == nil then
				break
			end
			if is_continue(w) then
				return w
			end
			if not w.hidden then
				for _, k in ipairs(widget_children(group, child) or {}) do
					if is_continue(k) then
						return k
					end
				end
			end
			child += 1
		end
	end
	return nil
end

function ChatOptions.contains_continue(): boolean
	local w = ChatOptions.continue_widget()
	return w ~= nil
end

function ChatOptions.continue_chat(key_probability: number?): boolean
	local w = ChatOptions.continue_widget()
	if w == nil then
		return false
	end
	if Chat.clean(w.text or "") == ChatOptions.WAIT_TEXT then
		local now = snapshot()
		if now == nil then
			return false
		end
		return wait_change(now)
	end
	local before = snapshot()
	if before == nil then
		return false
	end
	local pressed = press(w, Keyboard.keys.SPACE, key_probability)
	if not pressed then
		Log.log("ChatOptions", 'couldn\'t press "Click here to continue"')
		return pressed
	end
	local moved = wait_change(before)
	if not moved then
		Log.log("ChatOptions", "the dialogue didn't move on")
		return moved
	end
	return true
end

function ChatOptions.continue_until_option(text: string, timeout_ms: number?, match_case: boolean?): boolean
	local deadline = time() + (timeout_ms or CONTINUE_UNTIL_MS)
	while time() < deadline do
		local found = ChatOptions.contains(text, match_case)
		if found == nil then
			return false
		end
		if found then
			return ChatOptions.select(text, match_case)
		end
		local continued = ChatOptions.continue_chat()
		if continued == nil then
			return false
		end
		if not continued then
			sleep(POLL_MS * 4)
		else
			Random.sleep(0, 1200, "left")
		end
	end
	return false
end

function ChatOptions.title(): string?
	local _, title = texts()
	return if title then Chat.clean(title.text :: string) else nil
end

function ChatOptions.similarity(a: string, b: string): number
	local s, t = string.lower(a), string.lower(b)
	if s == t then
		return 1
	end
	local n, m = #s, #t
	if n == 0 or m == 0 then
		return 0
	end
	local previous: { number } = {}
	for j = 0, m do
		previous[j] = j
	end
	for i = 1, n do
		local current: { number } = { [0] = i }
		for j = 1, m do
			local cost = if string.byte(s, i) == string.byte(t, j) then 0 else 1
			current[j] = math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
		end
		previous = current
	end
	return 1 - previous[m] / math.max(n, m)
end

function ChatOptions.is_title(text: string, similarity: number?): boolean
	local title = ChatOptions.title()
	return title ~= nil and ChatOptions.similarity(title, text) >= (similarity or 0.8)
end

function ChatOptions.wait_title(text: string, timeout_ms: number?, similarity: number?): boolean
	return wait(function()
		return ChatOptions.is_title(text, similarity)
	end, timeout_ms or WAIT_MS)
end

function ChatOptions.speech(): { name: string, text: string }?
	local groups = Chatbox.interfaces()
	if groups == nil then
		return nil
	end
	for _, group in ipairs(groups) do
		local parts = ChatOptions.SPEECH[group]
		if parts then
			local name = widget(group, parts.name)
			local text = widget(group, parts.text)
			if name == nil or text == nil then
				return nil
			end
			return { name = Chat.clean(name.text or ""), text = Chat.clean(text.text or "") }
		end
	end
	return nil
end

-- The first level up game message newer than the message `since` (its uid).
function ChatOptions.level_up_message(since: number?): Chat.Message?
	local found = Chat.new_messages(since or -1)
	if found == nil then
		return nil
	end
	for _, m in ipairs(found) do
		if string.find(Chat.clean(m.text), ChatOptions.LEVEL_UP_TEXT, 1, true) then
			return m
		end
	end
	return nil
end

function ChatOptions.leveled_up(): boolean
	local open = Chatbox.is_open(Chatbox.LEVELUP_DISPLAY)
	if open == nil then
		return false
	end
	if open then
		return true
	end
	local text = Chatbox.text()
	if text == nil then
		return false
	end
	return string.find(text, "Congratulations", 1, true) ~= nil
end

export type LevelUp = { skill: string, level: number }

-- Reads the skill and level from a level up display or game message text.
function ChatOptions.parse_level_up(text: string): LevelUp?
	local clean = Chat.clean(text)
	local skill = string.match(clean, "advanced an? ([%w ]-) level")
		or string.match(clean, "advanced your ([%w ]-) level")
	local level = string.match(clean, "[Ll]evel is now (%d+)") or string.match(clean, "You are now level (%d+)")
	if skill == nil or level == nil then
		return nil
	end
	return { skill = skill, level = tonumber(level) :: number }
end

-- The skill and level of the level up showing now, from the display or chatbox; nil when none.
function ChatOptions.level_up(): LevelUp?
	local text = Chatbox.text()
	if text == nil then
		return nil
	end
	return ChatOptions.parse_level_up(text)
end

function ChatOptions.handle_level_up(key_probability: number?): boolean
	local deadline = time() + LEVEL_UP_MS
	while time() < deadline do
		local leveled = ChatOptions.leveled_up()
		if leveled == nil then
			return false
		end
		if not leveled then
			return true
		end
		local continued = ChatOptions.continue_chat(key_probability)
		if continued == nil then
			return false
		end
		Random.sleep(60, 1500, "left")
	end
	Log.log("ChatOptions", "the level up messages didn't go away")
	return false
end

return ChatOptions
