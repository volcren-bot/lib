# Main.Interfaces.Chatbox.ChatOptions

Dialogues in the chatbox: option menus, "Click here to continue", speech, and level-up messages. Options are picked with their number key (space for continue) or a click that waits for the menu to show the right line first; the key/click choice is random. After picking or continuing, functions wait for the dialogue to move on, so calls chain. Dialogue lines are also in the chat history (`Chat.MessageType.DIALOG`). Text matching is a case-insensitive substring match unless `match_case` is set.

```luau
local ChatOptions = require("@lib/main/interfaces/chatbox/chat_options")
```

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
ChatOptions.LEVEL_UP_TEXT = "Congratulations, you've just advanced"
```
The option menu interface and its lines component, the title's text colour, the speech boxes (NPC left, player right) with their name and text components, the continue line before and after pressing, and the start of the level-up game message.

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
export type LevelUp = { skill: string, level: number }
```
An option line: cleaned `text`, tagged `raw_text`, 1-based `index`, the `key` that picks it and its `widget`. `LevelUp` is a parsed level-up.

## ChatOptions.get

Definition:
```luau
function ChatOptions.get(): { Option }?
```
The open menu's options, top to bottom, without the title. Empty when no menu is open.

Example:
```luau
for _, option in ipairs(ChatOptions.get() or {}) do
	print(option.index, option.text)
end
```

## ChatOptions.to_string

Definition:
```luau
function ChatOptions.to_string(options: { Option }?): string?
```
`options` (default: the open menu's) as text, one per line.

Example:
```luau
print(ChatOptions.to_string())
```

## ChatOptions.find

Definition:
```luau
function ChatOptions.find(text: string, match_case: boolean?): Option?
```
The first option containing `text`, or `nil`.

Example:
```luau
local option = ChatOptions.find("access my bank")
print(option and option.index)
```

## ChatOptions.index_of

Definition:
```luau
function ChatOptions.index_of(text: string, match_case: boolean?): number?
```
The index of the first option containing `text`, or 0 when none matches.

Example:
```luau
print(ChatOptions.index_of("Goodbye"))
```

## ChatOptions.contains

Definition:
```luau
function ChatOptions.contains(text: string, match_case: boolean?): boolean
```
Whether an option contains `text`.

Example:
```luau
print(ChatOptions.contains("access my bank"))
```

## ChatOptions.wait_option

Definition:
```luau
function ChatOptions.wait_option(text: string, match_case: boolean?, timeout_ms: number?): boolean
```
Waits up to `timeout_ms` (default 600) for an option containing `text`.

Example:
```luau
print(ChatOptions.wait_option("access my bank", false, 3000))
```

## ChatOptions.select

Definition:
```luau
function ChatOptions.select(text: string, match_case: boolean?, key_probability: number?): boolean
```
Picks the first option containing `text` by key or click, then waits up to 3 seconds for the dialogue to change. `key_probability` is the chance of using the key (default about 0.5, varied per account by biometrics). `false` when there's no such option or nothing changed.

Example:
```luau
print(ChatOptions.select("access my bank"))
```

## ChatOptions.continue_widget

Definition:
```luau
function ChatOptions.continue_widget(): Widget?
```
The open dialogue's "Click here to continue" line (or the "Please wait..." it becomes), or `nil`.

Example:
```luau
local w = ChatOptions.continue_widget()
print(w and w.text)
```

## ChatOptions.contains_continue

Definition:
```luau
function ChatOptions.contains_continue(): boolean
```
Whether a continue (or "Please wait...") line is showing.

Example:
```luau
print(ChatOptions.contains_continue())
```

## ChatOptions.continue_chat

Definition:
```luau
function ChatOptions.continue_chat(key_probability: number?): boolean
```
Presses continue (space or click, `key_probability` as in `select`) and waits for the dialogue to change. On "Please wait..." it only waits. `false` when there's nothing to continue.

Example:
```luau
while ChatOptions.contains_continue() do
	ChatOptions.continue_chat()
end
```

## ChatOptions.continue_until_option

Definition:
```luau
function ChatOptions.continue_until_option(text: string, timeout_ms: number?, match_case: boolean?): boolean
```
Continues the dialogue, with random human pauses, until an option containing `text` appears, then selects it. `false` after `timeout_ms` (default 10000).

Example:
```luau
print(ChatOptions.continue_until_option("access my bank"))
```

## ChatOptions.title

Definition:
```luau
function ChatOptions.title(): string?
```
The open menu's title (usually "Select an option"), or `nil`.

Example:
```luau
print(ChatOptions.title())
```

## ChatOptions.similarity

Definition:
```luau
function ChatOptions.similarity(a: string, b: string): number
```
Case-insensitive similarity from 0 to 1: 1 minus Levenshtein distance over the longer length.

Example:
```luau
print(ChatOptions.similarity("Select an option", "Select an Option")) --> 1
```

## ChatOptions.is_title

Definition:
```luau
function ChatOptions.is_title(text: string, similarity: number?): boolean
```
Whether the menu title's `similarity` to `text` is at least `similarity` (default 0.8).

Example:
```luau
print(ChatOptions.is_title("Select an option"))
```

## ChatOptions.wait_title

Definition:
```luau
function ChatOptions.wait_title(text: string, timeout_ms: number?, similarity: number?): boolean
```
Waits up to `timeout_ms` (default 600) for `is_title`.

Example:
```luau
print(ChatOptions.wait_title("Select an option", 3000))
```

## ChatOptions.speech

Definition:
```luau
function ChatOptions.speech(): { name: string, text: string }?
```
The speaker and text of the open NPC or player speech box, or `nil`.

Example:
```luau
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
Whether a level-up is showing: the level-up display is open or any open dialogue text contains "Congratulations".

Example:
```luau
if ChatOptions.leveled_up() then
	ChatOptions.handle_level_up()
end
```

## ChatOptions.level_up_message

Definition:
```luau
function ChatOptions.level_up_message(since: number?): Chat.Message?
```
The first history message newer than uid `since` (default: all) that contains `LEVEL_UP_TEXT`. The display doesn't always open, so use this to notice level-ups.

Example:
```luau
local message = ChatOptions.level_up_message()
if message then
	print("level up:", message.text)
end
```

## ChatOptions.parse_level_up

Definition:
```luau
function ChatOptions.parse_level_up(text: string): LevelUp?
```
Parses the skill and level from level-up display text or the level-up game message; `nil` when it isn't one.

Example:
```luau
local up = ChatOptions.parse_level_up("Congratulations, you've just advanced your Prayer level. You are now level 12.")
print(up and up.skill, up and up.level) -- Prayer 12
```

## ChatOptions.level_up

Definition:
```luau
function ChatOptions.level_up(): LevelUp?
```
`parse_level_up` of the open dialogue text, without dismissing it.

Example:
```luau
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
Continues through level-up messages with random pauses until gone; `false` if still showing after 8 seconds.

Example:
```luau
print(ChatOptions.handle_level_up())
```
