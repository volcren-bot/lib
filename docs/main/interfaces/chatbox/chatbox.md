# Main.Interfaces.Chatbox.Chatbox

The dialogues, option menus and message boxes open in the chat area: which are open and what they say. All functions return `nil` (or `false`) when the open interfaces can't be read.

```luau
local Chatbox = require("@lib/main/interfaces/chatbox/chatbox")
```

## Constants

Definition:
```luau
Chatbox.GROUP = 162
Chatbox.MODAL = 568
Chatbox.SKILLMULTI = 270
Chatbox.CHATMENU = 219
Chatbox.CHAT_LEFT = 231
Chatbox.CHAT_RIGHT = 217
Chatbox.MESSAGEBOX = 229
Chatbox.OBJECTBOX = 193
Chatbox.OBJECTBOX_DOUBLE = 11
Chatbox.LEVELUP_DISPLAY = 233
Chatbox.RECOMMEND_SURVEY = 709
```
The chat area (`GROUP`), its dialogue slot (`MODAL`), and the dialogues that open there: make menu, option menu, NPC and player speech, message box, item boxes, level-up display and survey.

## Chatbox.interfaces

Definition:
```luau
function Chatbox.interfaces(): { number }?
```
Every interface open in the chat area's dialogue slot, plus the level-up display wherever it is open.

Example:
```luau
for _, group in ipairs(Chatbox.interfaces() or {}) do
	print(group)
end
```

## Chatbox.interface

Definition:
```luau
function Chatbox.interface(): number?
```
The first open dialogue, or `nil` when none is open.

Example:
```luau
print(Chatbox.interface())
```

## Chatbox.interface_name

Definition:
```luau
function Chatbox.interface_name(): string?
```
The game's name for the first open dialogue.

Example:
```luau
print(Chatbox.interface_name())
```

## Chatbox.is_open

Definition:
```luau
function Chatbox.is_open(interface: number | string): boolean
```
Whether a dialogue is open, by interface number or by name (case-insensitive).

Example:
```luau
print(Chatbox.is_open(Chatbox.LEVELUP_DISPLAY))
```

## Chatbox.text

Definition:
```luau
function Chatbox.text(): string?
```
The visible text of every open dialogue, one line per non-empty text, tags kept. Empty when nothing is open.

Example:
```luau
print(Chatbox.text())
```
