# Main.Interfaces.Chatbox.Chat

The chat: message history, the input line, chat questions ("Enter amount:") and hiding or showing the chatbox. Messages come from the client's chat history, so they read the same with the chatbox hidden, covered or transparent, including messages the tabs filter out. For tabs see [ChatTabs](chat_tabs.md); for dialogues see [ChatOptions](chat_options.md). Text matching is a case-insensitive substring match unless `match_case` is set.

```luau
local Chat = require("@lib/main/interfaces/chatbox/chat")
```

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
Chat.MessageType = { GAME = 0, PUBLIC = 2, PRIVATE = 3, BROADCAST = 14, ITEM_EXAMINE = 27, CLAN_CHAT = 41, TRADE_REQUEST = 101, DIALOG = 114, MESBOX = 115, NPC_SAY = 116, LEVEL_UP = 118, ... }
Chat.IRON_TYPES = { [0] = "none", "ironman", "ultimate", "hardcore", "group", "hardcore_group", "unranked_group" }
```
The chat interface's components (display, input line, question layer and its text and answer). `TABS` are the tab buttons from "all" to "trade"; varc `VIEW_VARC` holds the open tab's index (0 = all) or `VIEW_CLOSED` while hidden. `ROOT_FIXED` is the fixed-mode root, where the chatbox can't be hidden. `MessageType` lists every `Message.kind` (see the source for the full table); `IRON_TYPES` maps the `IRONMAN_VARBIT` value to an account type.

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
`uid` increases with every message, so larger is newer. `name` is the speaker and `sender` the channel (empty for game messages); `name` and `text` are cleaned with `Chat.clean`, `raw_name` and `raw_text` keep the tags. `icon` is the `<img=N>` before the name, if any. `time` is arrival time in Unix milliseconds and `age` milliseconds since, both accurate to about a second; `time_utc` and `time_local` are "HH:MM" stamps. `DIALOG` lines have the speaker split into `name`.

## Chat.clean

Definition:
```luau
function Chat.clean(text: string): string
```
Strips tags, turns `<br>` and non-breaking spaces into spaces, decodes `<lt>`/`<gt>` and trims.

Example:
```luau
print(Chat.clean("<col=ff0000>Off</col>")) --> Off
```

## Chat.messages

Definition:
```luau
function Chat.messages(kinds: { number }?): { Message }?
```
The chat history, oldest first, optionally only the `kinds` given. The client keeps up to 100 messages per type.

Example:
```luau
for _, m in ipairs(Chat.messages({ Chat.MessageType.GAME }) or {}) do
	print(m.time_utc, m.text)
end
```

## Chat.new_messages

Definition:
```luau
function Chat.new_messages(since: number, kinds: { number }?): { Message }?
```
Messages with `uid` greater than `since`, oldest first. Keep the newest `uid` seen to poll only new ones.

Example:
```luau
local seen = -1
for _, m in ipairs(Chat.new_messages(seen) or {}) do
	print(m.name, m.text)
	seen = m.uid
end
```

## Chat.last_message

Definition:
```luau
function Chat.last_message(kinds: { number }?): Message?
```
The newest message, optionally of `kinds`, or `nil`.

Example:
```luau
local m = Chat.last_message()
print(m and m.text)
```

## Chat.find_message

Definition:
```luau
function Chat.find_message(text: string, match_case: boolean?, kinds: { number }?): Message?
```
The newest message whose text contains `text`, or `nil`.

Example:
```luau
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
Whether any message in the history contains `text`.

Example:
```luau
print(Chat.contains_message("Welcome to the game"))
```

## Chat.count_new_message

Definition:
```luau
function Chat.count_new_message(text: string, match_case: boolean?): number?
```
How many of the newest messages in a row equal `text` (case-insensitive unless `match_case`), skipping dialogue lines. Compare before and after an action to see whether it failed again.

Example:
```luau
local before = Chat.count_new_message("You can't light a fire here.") or 0
light_fire()
if (Chat.count_new_message("You can't light a fire here.") or 0) > before then
	print("can't light here")
end
```

## Chat.wait_message

Definition:
```luau
function Chat.wait_message(text: string, timeout_ms: number?, since: number?, match_case: boolean?): Message?
```
Waits up to `timeout_ms` (default 600) for a message newer than `since` (default: the newest at call time) containing `text`. `nil` on timeout.

Example:
```luau
local m = Chat.wait_message("You catch", 10000)
print(if m then m.text else "nothing caught")
```

## Chat.messages_string

Definition:
```luau
function Chat.messages_string(kinds: { number }?): string?
```
The history as text, oldest first, one "name: text" (or just text) per line.

Example:
```luau
print(Chat.messages_string())
```

## Chat.lines

Definition:
```luau
function Chat.lines(): { string }?
```
The lines visible in the chat now, top to bottom, cleaned, with the name and timestamp prefix. Empty while the chat is hidden or covered by a dialogue.

Example:
```luau
for _, line in ipairs(Chat.lines() or {}) do
	print(line)
end
```

## Chat.display_name

Definition:
```luau
function Chat.display_name(): string?
```
Your name from the input line, falling back to the local player's name.

Example:
```luau
print(Chat.display_name())
```

## Chat.input_text

Definition:
```luau
function Chat.input_text(): string?
```
The unsent text in the input line.

Example:
```luau
print(Chat.input_text())
```

## Chat.input_has_text

Definition:
```luau
function Chat.input_has_text(): boolean
```
Whether the input line has unsent text.

Example:
```luau
print(Chat.input_has_text())
```

## Chat.iron_type

Definition:
```luau
function Chat.iron_type(): IronType?
```
The account type, read from `IRONMAN_VARBIT`.

Example:
```luau
print(Chat.iron_type())
```

## Chat.is_transparent

Definition:
```luau
function Chat.is_transparent(): boolean
```
Whether "Transparent chatbox" is on (resizable modes only).

Example:
```luau
print(Chat.is_transparent())
```

## Chat.query

Definition:
```luau
function Chat.query(): string?
```
The open chat question, such as "Enter amount:", or `nil`.

Example:
```luau
print(Chat.query())
```

## Chat.query_answer

Definition:
```luau
function Chat.query_answer(): string?
```
The answer typed so far, without the trailing cursor.

Example:
```luau
print(Chat.query_answer())
```

## Chat.find_query

Definition:
```luau
function Chat.find_query(query: string, match_case: boolean?): boolean
```
Whether the open question contains `query`.

Example:
```luau
print(Chat.find_query("Enter amount"))
```

## Chat.wait_query

Definition:
```luau
function Chat.wait_query(query: string, timeout_ms: number?, match_case: boolean?): boolean
```
Waits up to `timeout_ms` (default 600) for a question containing `query`.

Example:
```luau
print(Chat.wait_query("Enter amount", 2000))
```

## Chat.answer_query

Definition:
```luau
function Chat.answer_query(query: string, answer: string, timeout_ms: number?): boolean
```
Waits for `query` (as `wait_query`), erases any different typed text, types `answer` with a short human pause and presses enter. If `answer` is already typed it only presses enter. `false` when the question didn't show.

Example:
```luau
print(Chat.answer_query("Enter amount", "14", 2000))
```

## Chat.is_open

Definition:
```luau
function Chat.is_open(): boolean
```
Whether the chatbox is shown. In resizable modes clicking the open tab hides it.

Example:
```luau
print(Chat.is_open())
```

## Chat.open

Definition:
```luau
function Chat.open(): boolean
```
Shows a hidden chatbox by clicking "All" and waits up to 1.2 seconds.

Example:
```luau
print(Chat.open())
```

## Chat.close

Definition:
```luau
function Chat.close(): boolean
```
Hides the chatbox by clicking the open tab and waits up to 1.2 seconds. `false` in fixed mode.

Example:
```luau
print(Chat.close())
```
