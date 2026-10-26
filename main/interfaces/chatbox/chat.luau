--!strict
local Host = require("../../../host")
local widget = Host.widget
local widget_children = Host.widget_children
local chat_messages = Host.chat_messages
local varc = Host.varc
local game_state = Host.game_state
local sleep = Host.sleep
type Widget = Host.Widget
type ChatMessage = Host.ChatMessage
local Varbits = require("../../varbits")
local Player = require("../../player")
local Widgets = require("../widgets")
local Keyboard = require("../../../utils/input/keyboard")
local Random = require("../../../utils/math/random")
local Log = require("../../../utils/log")

local Chat = {}

Chat.GROUP = 162
Chat.CHATDISPLAY = 57
Chat.INPUT = 58
Chat.SCROLLAREA = 59
Chat.QUERY = 39
Chat.QUERY_TEXT = 43
Chat.QUERY_ANSWER = 44
Chat.TAB_ALL = 4
Chat.TABS = table.freeze({ 4, 7, 11, 15, 19, 23, 27 })
Chat.VIEW_VARC = 41
Chat.VIEW_CLOSED = 1337
Chat.ROOT_FIXED = 548
Chat.TRANSPARENCY_VARBIT = 4608
Chat.IRONMAN_VARBIT = 1777

Chat.MessageType = table.freeze({
	GAME = 0,
	MOD_CHAT = 1,
	PUBLIC = 2,
	PRIVATE = 3,
	ENGINE = 4,
	LOGIN_LOGOUT = 5,
	PRIVATE_OUT = 6,
	MOD_PRIVATE = 7,
	FRIENDS_CHAT = 9,
	FRIENDS_CHAT_NOTIFICATION = 11,
	TRADE_SENT = 12,
	BROADCAST = 14,
	SNAPSHOT_FEEDBACK = 26,
	ITEM_EXAMINE = 27,
	NPC_EXAMINE = 28,
	OBJECT_EXAMINE = 29,
	FRIEND_NOTIFICATION = 30,
	IGNORE_NOTIFICATION = 31,
	CLAN_CHAT = 41,
	CLAN_MESSAGE = 43,
	CLAN_GUEST_CHAT = 44,
	CLAN_GUEST_MESSAGE = 46,
	AUTOTYPER = 90,
	MOD_AUTOTYPER = 91,
	CONSOLE = 99,
	TRADE_REQUEST = 101,
	TRADE = 102,
	CHALLENGE_TRADE = 103,
	CHALLENGE_FRIENDS_CHAT = 104,
	SPAM = 105,
	PLAYER_RELATED = 106,
	TEN_SECOND_TIMEOUT = 107,
	WELCOME = 108,
	CLAN_CREATION_INVITATION = 109,
	CHALLENGE_CLAN_CHAT = 110,
	GIM_FORM_GROUP = 111,
	GIM_GROUP_WITH = 112,
	DIALOG = 114,
	MESBOX = 115,
	NPC_SAY = 116,
	DID_YOU_KNOW = 117,
	LEVEL_UP = 118,
})

Chat.IRON_TYPES = table.freeze({
	[0] = "none",
	"ironman",
	"ultimate",
	"hardcore",
	"group",
	"hardcore_group",
	"unranked_group",
})
export type IronType = "none" | "ironman" | "ultimate" | "hardcore" | "group" | "hardcore_group" | "unranked_group"

export type Message = {
	uid: number,
	kind: number,
	name: string,
	raw_name: string,
	icon: number?,
	sender: string,
	text: string,
	raw_text: string,
	cycle: number,
	age: number,
	time: number,
	time_utc: string,
	time_local: string,
}

local POLL_MS = 50
local QUERY_TIMEOUT_MS = 600
local TOGGLE_TIMEOUT_MS = 1200

function Chat.clean(text: string): string
	local clean = string.gsub(text, "<br>", " ")
	clean = string.gsub(clean, "<[^>]*>", function(tag: string)
		if tag == "<lt>" then
			return "<"
		elseif tag == "<gt>" then
			return ">"
		end
		return ""
	end)
	clean = string.gsub(clean, "\u{a0}", " ")
	clean = string.gsub(clean, "^%s+", "")
	clean = string.gsub(clean, "%s+$", "")
	return clean
end

local function message(m: ChatMessage): Message
	local raw_name, raw_text = m.name, m.text
	if m.kind == Chat.MessageType.DIALOG and raw_name == "" then
		local speaker, line = string.match(raw_text, "^([^|]*)|(.*)$")
		if speaker and line then
			raw_name, raw_text = speaker, line
		end
	end
	return {
		uid = m.uid,
		kind = m.kind,
		name = Chat.clean(raw_name),
		raw_name = raw_name,
		icon = tonumber(string.match(raw_name, "<img=(%d+)>")),
		sender = Chat.clean(m.sender),
		text = Chat.clean(raw_text),
		raw_text = raw_text,
		cycle = m.cycle,
		age = m.age,
		time = m.time,
		time_utc = m.time_utc,
		time_local = m.time_local,
	}
end

local function wanted(kinds: { number }?, kind: number): boolean
	return kinds == nil or table.find(kinds, kind) ~= nil
end

function Chat.messages(kinds: { number }?): { Message }?
	local all = chat_messages()
	if all == nil then
		return nil
	end
	local found: { Message } = {}
	for _, m in ipairs(all) do
		if wanted(kinds, m.kind) then
			table.insert(found, message(m))
		end
	end
	return found
end

function Chat.new_messages(since: number, kinds: { number }?): { Message }?
	local all = Chat.messages(kinds)
	if all == nil then
		return nil
	end
	local found: { Message } = {}
	for _, m in ipairs(all) do
		if m.uid > since then
			table.insert(found, m)
		end
	end
	return found
end

function Chat.last_message(kinds: { number }?): Message?
	local all = Chat.messages(kinds)
	if all == nil then
		return nil
	end
	return all[#all]
end

local function contains(text: string, part: string, match_case: boolean?): boolean
	if match_case then
		return string.find(text, part, 1, true) ~= nil
	end
	return string.find(string.lower(text), string.lower(part), 1, true) ~= nil
end

function Chat.find_message(text: string, match_case: boolean?, kinds: { number }?): Message?
	local all = Chat.messages(kinds)
	if all == nil then
		return nil
	end
	for i = #all, 1, -1 do
		if contains(all[i].text, text, match_case) then
			return all[i]
		end
	end
	return nil
end

function Chat.contains_message(text: string, match_case: boolean?, kinds: { number }?): boolean
	local found = Chat.find_message(text, match_case, kinds)
	return found ~= nil
end

function Chat.count_new_message(text: string, match_case: boolean?): number?
	local all = Chat.messages()
	if all == nil then
		return nil
	end
	local function same(a: string): boolean
		return if match_case then a == text else string.lower(a) == string.lower(text)
	end
	local count = 0
	for i = #all, 1, -1 do
		local m = all[i]
		if m.kind ~= Chat.MessageType.DIALOG then
			if not same(m.text) then
				break
			end
			count += 1
		end
	end
	return count
end

function Chat.wait_message(text: string, timeout_ms: number?, since: number?, match_case: boolean?): Message?
	local after = since
	if after == nil then
		local last = Chat.last_message()
		after = if last then last.uid else -1
	end
	local timeout = timeout_ms or 600
	local waited = 0
	while true do
		local found = Chat.new_messages(after :: number)
		if found == nil then
			return nil
		end
		for _, m in ipairs(found) do
			if contains(m.text, text, match_case) then
				return m
			end
		end
		if waited >= timeout then
			return nil
		end
		sleep(POLL_MS)
		waited += POLL_MS
	end
end

function Chat.messages_string(kinds: { number }?): string?
	local all = Chat.messages(kinds)
	if all == nil then
		return nil
	end
	local lines: { string } = {}
	for _, m in ipairs(all) do
		table.insert(lines, if m.name ~= "" then `{m.name}: {m.text}` else m.text)
	end
	return table.concat(lines, "\n")
end

function Chat.lines(): { string }?
	local view = widget(Chat.GROUP, Chat.SCROLLAREA)
	if view == nil then
		return nil
	end
	if view.hidden then
		return {}
	end
	local kids = widget_children(Chat.GROUP, Chat.SCROLLAREA)
	if kids == nil then
		return nil
	end
	local rows: { [number]: { Widget } } = {}
	local tops: { number } = {}
	for _, k in ipairs(kids) do
		local inside = k.y >= view.y and k.y + k.height <= view.y + view.height + 1
		if not k.hidden and k.text and k.text ~= "" and inside then
			if rows[k.y] == nil then
				rows[k.y] = {}
				table.insert(tops, k.y)
			end
			table.insert(rows[k.y], k)
		end
	end
	table.sort(tops)
	local lines: { string } = {}
	for _, top in ipairs(tops) do
		local row = rows[top]
		table.sort(row, function(a: Widget, b: Widget): boolean
			return a.x < b.x
		end)
		local parts: { string } = {}
		for _, k in ipairs(row) do
			table.insert(parts, Chat.clean(k.text :: string))
		end
		table.insert(lines, table.concat(parts, " "))
	end
	return lines
end

local function input_line(): string?
	local w = widget(Chat.GROUP, Chat.INPUT)
	if w == nil then
		return nil
	end
	return w.text or ""
end

function Chat.display_name(): string?
	local line = input_line()
	if line == nil then
		return nil
	end
	local name = string.match(line, "^(.-):")
	if name and Chat.clean(name) ~= "" then
		return Chat.clean(name)
	end
	local player = Player.name()
	return if player then Chat.clean(player) else nil
end

function Chat.input_text(): string?
	local line = input_line()
	if line == nil then
		return nil
	end
	local typed = string.match(line, ":%s*(.*)$") or ""
	typed = string.gsub(typed, "<col=0000ff>%*</col>$", "")
	return Chat.clean(typed)
end

function Chat.input_has_text(): boolean
	local typed = Chat.input_text()
	if typed == nil then
		return false
	end
	return typed ~= ""
end

function Chat.iron_type(): IronType?
	local value = Varbits.get(Chat.IRONMAN_VARBIT)
	if value == nil then
		return nil
	end
	return (Chat.IRON_TYPES[value] or "none") :: IronType
end

function Chat.is_transparent(): boolean
	local value = Varbits.get(Chat.TRANSPARENCY_VARBIT)
	if value == nil then
		return false
	end
	return value == 1
end

function Chat.query(): string?
	local layer = widget(Chat.GROUP, Chat.QUERY)
	if layer == nil then
		return nil
	end
	if layer.hidden then
		return nil
	end
	local text = widget(Chat.GROUP, Chat.QUERY_TEXT)
	if text == nil then
		return nil
	end
	return Chat.clean(text.text or "")
end

function Chat.query_answer(): string?
	local answer = widget(Chat.GROUP, Chat.QUERY_ANSWER)
	if answer == nil then
		return nil
	end
	local text = Chat.clean(answer.text or "")
	return (string.gsub(text, "%*$", ""))
end

function Chat.find_query(query: string, match_case: boolean?): boolean
	local current = Chat.query()
	return current ~= nil and contains(current, query, match_case)
end

function Chat.wait_query(query: string, timeout_ms: number?, match_case: boolean?): boolean
	local timeout = timeout_ms or QUERY_TIMEOUT_MS
	local waited = 0
	while true do
		local found = Chat.find_query(query, match_case)
		if found == nil then
			return false
		end
		if found or waited >= timeout then
			return found
		end
		sleep(POLL_MS)
		waited += POLL_MS
	end
end

function Chat.answer_query(query: string, answer: string, timeout_ms: number?): boolean
	local found = Chat.wait_query(query, timeout_ms)
	if not found then
		return found
	end
	local typed = Chat.query_answer()
	if typed ~= answer then
		for _ = 1, #(typed or "") + 1 do
			Keyboard.key_press(Keyboard.keys.BACK)
		end
		Random.sleep(80, 250)
		Keyboard.send(answer, Keyboard.keys.RETURN)
	else
		Keyboard.key_press(Keyboard.keys.RETURN)
	end
	return true
end

function Chat.is_open(): boolean
	local view = varc(Chat.VIEW_VARC)
	if view == nil then
		return false
	end
	return view ~= Chat.VIEW_CLOSED
end

local function wait_open(open: boolean): boolean
	local waited = 0
	while true do
		local now = Chat.is_open()
		if now == nil then
			return false
		end
		if now == open then
			return true
		end
		if waited >= TOGGLE_TIMEOUT_MS then
			Log.log("Chat", `the chatbox didn't {if open then "open" else "close"}`)
			return false
		end
		sleep(POLL_MS)
		waited += POLL_MS
	end
end

function Chat.open(): boolean
	local open = Chat.is_open()
	if open == nil then
		return false
	end
	if open then
		return true
	end
	local clicked = Widgets.click(Chat.GROUP, Chat.TAB_ALL)
	if not clicked then
		return clicked
	end
	return wait_open(true)
end

function Chat.close(): boolean
	local view = varc(Chat.VIEW_VARC)
	if view == nil then
		return false
	end
	if view == Chat.VIEW_CLOSED then
		return true
	end
	local state = game_state()
	if state.root_interface == Chat.ROOT_FIXED then
		return false
	end
	local tab = Chat.TABS[view + 1]
	if tab == nil then
		Log.log("Chat", `unknown chat view {view}`)
		return false
	end
	local clicked = Widgets.click(Chat.GROUP, tab)
	if not clicked then
		return clicked
	end
	return wait_open(false)
end

return Chat
