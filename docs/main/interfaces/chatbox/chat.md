# Main.Interfaces.Chatbox.Chat

The chat at the bottom left of the screen: the messages (with the time each one arrived), what you have typed, the questions the chat asks ("Enter amount:"), and hiding and showing the chatbox.

```luau
local Chat = require("../main/interfaces/chatbox/chat")
```

Nothing here looks at the screen's colours. Messages come from the chat history the game keeps, so they can be read with the chatbox closed, covered by a dialogue, or transparent, and messages the tabs hide are there too. Everything else is read from the chat's buttons and texts. For the tabs see `ChatTabs`; for dialogues with NPCs see `ChatOptions`.

Texts are compared ignoring case unless you pass `match_case`, and a part of the text is enough.

## Constants

Definition:
```luau
Chat.GROUP = 162
Chat.CHATDISPLAY = 57
Chat.INPUT = 58
Chat.SCROLLAREA = 59
Chat.QUERY = 39
Chat.QUERY_TEXT = 43
Chat.QUERY_ANSWER = 44
Chat.TAB_ALL = 4
Chat.TABS = { 4, 7, 11, 15, 19, 23, 27 }
Chat.VIEW_VARC = 41
Chat.VIEW_CLOSED = 1337
Chat.ROOT_FIXED = 548
Chat.TRANSPARENCY_VARBIT = 4608
Chat.IRONMAN_VARBIT = 1777
Chat.MessageType = { GAME = 0, PUBLIC = 2, PRIVATE = 3, BROADCAST = 14, ITEM_EXAMINE = 27, CLAN_CHAT = 41, TRADE_REQUEST = 101, DIALOG = 114, LEVEL_UP = 118, ... }
Chat.IRON_TYPES = { [0] = "none", "ironman", "ultimate", "hardcore", "group", "hardcore_group", "unranked_group" }
```
The chat interface and its parts: the message display, the input line and the question layer (the question and the answer typed so far). `TABS` are the tab buttons in order (all, game, public, private, channel, clan, trade); the game setting `VIEW_VARC` says which one is open (0 for all, 1 for game, ...) or `VIEW_CLOSED` while the chatbox is hidden. `ROOT_FIXED` is the fixed mode screen, where the chatbox can't be hidden. `MessageType` names every message type the game uses (`Message.kind`), and `IRON_TYPES` the account types by the value of the game setting `IRONMAN_VARBIT`.

## Types

Definition:
```luau
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
export type IronType = "none" | "ironman" | "ultimate" | "hardcore" | "group" | "hardcore_group" | "unranked_group"
```
A chat message. `uid` counts up with every message, so a bigger one is newer. `kind` is its type (see `Chat.MessageType`). `name` is who said it and `sender` the channel it came through (empty for game messages); `text` and `name` are plain text, while `raw_text` and `raw_name` keep the colour and icon tags. `icon` is the icon in front of the name (ironman helmets, moderator crowns), if any.

`time` is when it arrived, in milliseconds since 1970 (UTC), and `age` how many milliseconds ago. Both come from the game's clock, which ticks every 20 ms, so they're precise to the second. `time_utc` and `time_local` are the "HH:MM" stamps the game shows when chat timestamps are on, in UTC and in your computer's time.

Dialogue lines (`DIALOG`) come with the speaker in `name` and the line in `text`.

## Chat.clean

Definition:
```luau
function Chat.clean(text: string): string
```
Turns a game text into plain text: colour and image tags removed, line breaks made spaces, `<lt>`/`<gt>` turned into `<`/`>`, and the game's non-breaking spaces made normal spaces.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.clean("<col=ff0000>Off</col>")) --> Off
```

## Chat.messages

Definition:
```luau
function Chat.messages(kinds: { number }?): { Message }?
```
The chat history, oldest first, or only the messages of the types in `kinds`. The game keeps up to 100 messages of each type.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

for _, m in ipairs(Chat.messages({ Chat.MessageType.GAME }) or {}) do
	print(m.time_utc, m.text)
end
```

## Chat.new_messages

Definition:
```luau
function Chat.new_messages(since: number, kinds: { number }?): { Message }?
```
The messages that arrived after the one whose `uid` is `since`, oldest first. Keep the newest `uid` you've seen to read only what's new each time.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")
local Host = require("../host")

local last = Chat.last_message()
local seen = if last then last.uid else -1
while true do
	for _, m in ipairs(Chat.new_messages(seen) or {}) do
		print(m.name, m.text)
		seen = m.uid
	end
	Host.sleep(600)
end
```

## Chat.last_message

Definition:
```luau
function Chat.last_message(kinds: { number }?): Message?
```
The newest message (of the types in `kinds`), or nil when there is none.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

local m = Chat.last_message()
print(m and m.text)
```

## Chat.find_message

Definition:
```luau
function Chat.find_message(text: string, match_case: boolean?, kinds: { number }?): Message?
```
The newest message whose text contains `text`.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

local m = Chat.find_message("correctly entered your PIN")
if m then
	print("PIN entered", math.floor(m.age / 1000), "seconds ago")
end
```

## Chat.contains_message

Definition:
```luau
function Chat.contains_message(text: string, match_case: boolean?, kinds: { number }?): boolean
```
True when a message of the history contains `text`.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.contains_message("Welcome to the game"))
```

## Chat.count_new_message

Definition:
```luau
function Chat.count_new_message(text: string, match_case: boolean?): number?
```
How many of the newest messages in a row are exactly `text` (dialogue lines are skipped). Compare it before and after doing something to know if that something failed again.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")
local Host = require("../host")

local before = Chat.count_new_message("You can't light a fire here.") or 0
-- ... use the tinderbox on the logs ...
Host.sleep(4000)
if (Chat.count_new_message("You can't light a fire here.") or 0) > before then
	print("couldn't light a fire here")
end
```

## Chat.wait_message

Definition:
```luau
function Chat.wait_message(text: string, timeout_ms: number?, since: number?, match_case: boolean?): Message?
```
Waits up to `timeout_ms` (600 ms by default) for a new message containing `text` and returns it, or nil if none came. Only messages newer than the one whose `uid` is `since` count; by default, newer than the newest one when you call it.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

local m = Chat.wait_message("You catch", 10000)
print(if m then m.text else "nothing caught")
```

## Chat.messages_string

Definition:
```luau
function Chat.messages_string(kinds: { number }?): string?
```
The whole history as text, one message per line ("name: text", or just the text when nobody said it), oldest first.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.messages_string())
```

## Chat.lines

Definition:
```luau
function Chat.lines(): { string }?
```
The lines the chat shows right now, top to bottom, as plain text with the name and timestamp the chat puts in front. A long message the chat wraps is one line. It's empty while a dialogue covers the chat or the chatbox is hidden.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

for _, line in ipairs(Chat.lines() or {}) do
	print(line)
end
```

## Chat.display_name

Definition:
```luau
function Chat.display_name(): string?
```
Your name as the chat's input line shows it, or your player's name when the input line is hidden.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.display_name())
```

## Chat.input_text

Definition:
```luau
function Chat.input_text(): string?
```
What has been typed in the chat's input line and not sent yet.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.input_text())
```

## Chat.input_has_text

Definition:
```luau
function Chat.input_has_text(): boolean
```
True when something has been typed in the chat's input line and not sent.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.input_has_text())
```

## Chat.iron_type

Definition:
```luau
function Chat.iron_type(): IronType?
```
The account type: "none", "ironman", "ultimate", "hardcore", "group", "hardcore_group" or "unranked_group". It's read from a game setting, not from the helmet in front of your name.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.iron_type())
```

## Chat.is_transparent

Definition:
```luau
function Chat.is_transparent(): boolean
```
True when the "Transparent chatbox" setting is on (it only shows in the resizable modes).

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.is_transparent())
```

## Chat.query

Definition:
```luau
function Chat.query(): string?
```
The question the chat is asking, like "Enter amount:" after a bank's Withdraw-X, or nil when it isn't asking anything.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.query())
```

## Chat.query_answer

Definition:
```luau
function Chat.query_answer(): string?
```
The answer typed so far to the chat's question.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.query_answer())
```

## Chat.find_query

Definition:
```luau
function Chat.find_query(query: string, match_case: boolean?): boolean
```
True when the chat is asking a question that contains `query`.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.find_query("Enter amount"))
```

## Chat.wait_query

Definition:
```luau
function Chat.wait_query(query: string, timeout_ms: number?, match_case: boolean?): boolean
```
Waits up to `timeout_ms` (600 ms by default) for the chat to ask a question that contains `query`.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.wait_query("Enter amount", 2000))
```

## Chat.answer_query

Definition:
```luau
function Chat.answer_query(query: string, answer: string, timeout_ms: number?): boolean
```
Waits up to `timeout_ms` for the question `query`, erases what was typed if it isn't `answer`, types `answer` and presses enter. False when the question didn't show up.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

-- after picking Withdraw-X on an item in the bank
print(Chat.answer_query("Enter amount", "14", 2000))
```

## Chat.is_open

Definition:
```luau
function Chat.is_open(): boolean
```
False while the chatbox is hidden. In the resizable modes, clicking the open tab again hides it.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.is_open())
```

## Chat.open

Definition:
```luau
function Chat.open(): boolean
```
Shows the chatbox by clicking the "All" tab, if it's hidden.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.open())
```

## Chat.close

Definition:
```luau
function Chat.close(): boolean
```
Hides the chatbox by clicking the open tab. Fails in fixed mode, where it can't be hidden.

Example:
```luau
local Chat = require("../main/interfaces/chatbox/chat")

print(Chat.close())
```
