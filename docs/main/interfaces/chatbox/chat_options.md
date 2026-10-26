# Main.Interfaces.Chatbox.ChatOptions

Talking to NPCs: the "Select an option" menus that show up in the chatbox, "Click here to continue", who is talking and what they say, and the level up messages.

```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")
```

The options, the title and the speech are the texts of the dialogue's interface, so nothing depends on the screen's colours or on reading letters. Options are picked with their number key or with a click; the click waits until the mouse is on the right line before clicking. After picking or continuing, the functions wait until the next box of the dialogue is up (or the dialogue ended), so you can chain them. Everything said in a dialogue is also saved in the chat history (`Chat.messages`, type `DIALOG`).

Option texts are compared ignoring case unless you pass `match_case`, and a part of the text is enough.

## Constants

Definition:
```luau
ChatOptions.GROUP = 219
ChatOptions.OPTIONS = 1
ChatOptions.TITLE_COLOR = 0x800000
ChatOptions.SPEECH = {
	[231] = { name = 4, text = 6 },
	[217] = { name = 4, text = 6 },
}
ChatOptions.CONTINUE_TEXT = "Click here to continue"
ChatOptions.WAIT_TEXT = "Please wait..."
```
The option menu interface and the part holding its lines, the dark red colour of its title, the speech boxes (an NPC talking on the left, you on the right) with the parts holding the name and the text, and the texts of the continue line before and after it's pressed.

## Types

Definition:
```luau
export type Option = {
	text: string,
	raw_text: string,
	index: number,
	key: number,
	widget: Widget,
}
```
A line of the option menu: its plain `text` (`raw_text` keeps the tags), its number from the top (`index`), the key that picks it, and its line on screen.

## ChatOptions.get

Definition:
```luau
function ChatOptions.get(): { Option }?
```
The options of the open option menu, top to bottom, without the title. Empty when no option menu is open.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

for _, option in ipairs(ChatOptions.get() or {}) do
	print(option.index, option.text)
end
```

## ChatOptions.to_string

Definition:
```luau
function ChatOptions.to_string(options: { Option }?): string?
```
The options (`options`, or the open menu's) as text, one per line.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

print(ChatOptions.to_string())
```

## ChatOptions.find

Definition:
```luau
function ChatOptions.find(text: string, match_case: boolean?): Option?
```
The first option that contains `text`, or nil.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

local option = ChatOptions.find("access my bank")
print(option and option.index)
```

## ChatOptions.index_of

Definition:
```luau
function ChatOptions.index_of(text: string, match_case: boolean?): number?
```
The number of the first option that contains `text`, or 0 when there is none.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

print(ChatOptions.index_of("Goodbye"))
```

## ChatOptions.contains

Definition:
```luau
function ChatOptions.contains(text: string, match_case: boolean?): boolean
```
True when an option contains `text`.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

print(ChatOptions.contains("access my bank"))
```

## ChatOptions.wait_option

Definition:
```luau
function ChatOptions.wait_option(text: string, match_case: boolean?, timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (600 ms by default) for an option that contains `text`.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

print(ChatOptions.wait_option("access my bank", false, 3000))
```

## ChatOptions.select

Definition:
```luau
function ChatOptions.select(text: string, match_case: boolean?, key_probability: number?): boolean
```
Picks the first option that contains `text`, with its number key or with a click, then waits for the dialogue to move on. `key_probability` is the chance of using the key (0 always clicks, 1 always uses the key); by default it's about half, a bit different for each account. False when there is no such option.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

print(ChatOptions.select("access my bank"))
```

## ChatOptions.continue_widget

Definition:
```luau
function ChatOptions.continue_widget(): Widget?
```
The "Click here to continue" line of the dialogue open in the chatbox (or the "Please wait..." it turns into once pressed), or nil when there is none.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

local w = ChatOptions.continue_widget()
print(w and w.text)
```

## ChatOptions.contains_continue

Definition:
```luau
function ChatOptions.contains_continue(): boolean
```
True when the dialogue shows "Click here to continue" (or "Please wait...").

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

print(ChatOptions.contains_continue())
```

## ChatOptions.continue_chat

Definition:
```luau
function ChatOptions.continue_chat(key_probability: number?): boolean
```
Presses "Click here to continue" (the space bar, or a click; `key_probability` as in `select`) and waits for the next box of the dialogue, or for it to end. False when there is nothing to continue.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

while ChatOptions.contains_continue() do
	ChatOptions.continue_chat()
end
```

## ChatOptions.continue_until_option

Definition:
```luau
function ChatOptions.continue_until_option(text: string, timeout_ms: number?, match_case: boolean?): boolean
```
Continues the dialogue until an option that contains `text` shows up, then picks it. Gives up after `timeout_ms` (10 seconds by default).

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

-- after Talk-to on a banker
print(ChatOptions.continue_until_option("access my bank"))
```

## ChatOptions.title

Definition:
```luau
function ChatOptions.title(): string?
```
The title of the open option menu (usually "Select an option"; the dark red line you can't pick), or nil when no option menu is open.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

print(ChatOptions.title())
```

## ChatOptions.similarity

Definition:
```luau
function ChatOptions.similarity(a: string, b: string): number
```
How alike two texts are, from 0 to 1, ignoring case: 1 minus the number of letters to change, add or remove, divided by the longer text's length.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

print(ChatOptions.similarity("Select an option", "Select an Option")) --> 1
```

## ChatOptions.is_title

Definition:
```luau
function ChatOptions.is_title(text: string, similarity: number?): boolean
```
True when the option menu's title is at least `similarity` (0.8 by default) alike to `text`.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

print(ChatOptions.is_title("Select an option"))
```

## ChatOptions.wait_title

Definition:
```luau
function ChatOptions.wait_title(text: string, timeout_ms: number?, similarity: number?): boolean
```
Waits up to `timeout_ms` (600 ms by default) for an option menu whose title is alike to `text`.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

print(ChatOptions.wait_title("Select an option", 3000))
```

## ChatOptions.speech

Definition:
```luau
function ChatOptions.speech(): { name: string, text: string }?
```
Who is talking in the open speech box and what they say, or nil when none is open.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

local speech = ChatOptions.speech()
if speech then
	print(speech.name .. ": " .. speech.text)
end
```

## ChatOptions.leveled_up

Definition:
```luau
function ChatOptions.leveled_up(): boolean
```
True while the level up message is open: the level up display, which is just the message and "Click here to continue". The message's text is also checked, for when it isn't in the usual place.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

if ChatOptions.leveled_up() then
	ChatOptions.handle_level_up()
end
```

## ChatOptions.level_up_message

Definition:
```luau
function ChatOptions.level_up_message(since: number?): Chat.Message?
```
The first level up message in the chat history newer than the message `since` (its `uid`; all messages when nil). Level ups show up as a game message ("Congratulations, you've just advanced your X level. You are now level N."), and the dialogue box doesn't always open with it, so use this to notice a level up.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

local last = -1
local message = ChatOptions.level_up_message(last)
if message then
	print("level up:", message.text)
end
```

## ChatOptions.parse_level_up

Definition:
```luau
function ChatOptions.parse_level_up(text: string): LevelUp?
```
Reads the skill and new level out of level up text, either the display ("Congratulations, you just advanced a Prayer level." with "Your Prayer level is now 12.") or the game message ("Congratulations, you've just advanced your Prayer level. You are now level 12."). Returns `{ skill: string, level: number }`, or nil when the text isn't a level up.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

local up = ChatOptions.parse_level_up("Congratulations, you've just advanced your Prayer level. You are now level 12.")
print(up and up.skill, up and up.level) -- Prayer 12
```

## ChatOptions.level_up

Definition:
```luau
function ChatOptions.level_up(): LevelUp?
```
The skill and new level of the level up display open right now, nil when there is none. Read only: it doesn't dismiss the display.

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

local up = ChatOptions.level_up()
if up then
	print(`{up.skill} is now level {up.level}`)
end
```

## ChatOptions.handle_level_up

Definition:
```luau
function ChatOptions.handle_level_up(key_probability: number?): boolean
```
Continues through the level up messages until they're gone (8 seconds at most).

Example:
```luau
local ChatOptions = require("../main/interfaces/chatbox/chat_options")

print(ChatOptions.handle_level_up())
```
