# Main.Interfaces.Chatbox.Chatbox

The chat area at the bottom of the screen, and the dialogues, option menus and message boxes that show up in it. Use it to find out which dialogue is open and to read what it says.

```luau
local Chatbox = require("../main/interfaces/chatbox/chatbox")
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
The interface numbers of the chat area and of the common dialogues that appear in it: the skill choice menu, option lists, the NPC and player speech boxes, message boxes, item boxes, the level-up display and the survey.

## Chatbox.interfaces

Definition:
```luau
function Chatbox.interfaces(): { number }?
```
The numbers of every dialogue currently open in the chat area, the level up display included wherever it is open.

Example:
```luau
local Chatbox = require("../main/interfaces/chatbox/chatbox")

for _, group in ipairs(Chatbox.interfaces() or {}) do
	print("open:", group)
end
```

## Chatbox.interface

Definition:
```luau
function Chatbox.interface(): number?
```
The number of the first open dialogue, or `nil` if there is none.

Example:
```luau
local Chatbox = require("../main/interfaces/chatbox/chatbox")

print(Chatbox.interface())
```

## Chatbox.interface_name

Definition:
```luau
function Chatbox.interface_name(): string?
```
The readable name of the first open dialogue.

Example:
```luau
local Chatbox = require("../main/interfaces/chatbox/chatbox")

print(Chatbox.interface_name())
```

## Chatbox.is_open

Definition:
```luau
function Chatbox.is_open(interface: number | string): boolean
```
Whether a specific dialogue is open, given by its number or its name.

Example:
```luau
local Chatbox = require("../main/interfaces/chatbox/chatbox")

print("level-up showing:", Chatbox.is_open(Chatbox.LEVELUP_DISPLAY))
```

## Chatbox.text

Definition:
```luau
function Chatbox.text(): string?
```
Everything the open dialogues say (speech, options, messages) as one text with one line per entry, top to bottom. It's an empty text when nothing is open.

Example:
```luau
local Chatbox = require("../main/interfaces/chatbox/chatbox")

local text = Chatbox.text()
if text and text ~= "" then
	print(text)
end
```
