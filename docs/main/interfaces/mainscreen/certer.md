# Main.Interfaces.Mainscreen.Certer

The certer random event's quiz (group 184): a rotating item picture and three answers ("Is this: A helmet. / A fish. / A bowl."), opened by "Talk-to" on the event NPC. [Randoms.handle](../../antiban/randoms.md) runs it for Niles, Miles and Giles.

```luau
local Certer = require("@lib/main/interfaces/mainscreen/certer")
```

The picture's model id (`Host.widget_model`) maps to a category in `MODELS`; the answer is the single line containing a word from that category's `WORDS`. With no match, several, or an unknown model, nothing is guessed. Only Giles's armour quiz has been seen live; afterwards he says one line, gives a reward and leaves once it is continued. An `Answer` is `{ letter: string, text: string, button: Widget }`.

## Constants

Definition:
```luau
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
```
Component ids, the NPC option, the answer menu prefix (`Select option A`), and wait lengths; `READ_MS` is the random pause before answering.

## Certer.MODELS

Definition:
```luau
export type Category = "food" | "weapon" | "armour" | "tool" | "jewel"
Certer.MODELS: { [number]: Category }
```
Picture model id to category.

Example:
```luau
print(Certer.MODELS[8833])
```

## Certer.WORDS

Definition:
```luau
Certer.WORDS: { [Category]: { string } }
```
Whole words that mark an answer as each category. Extend when a quiz logs "no answer fits".

Example:
```luau
print(table.concat(Certer.WORDS.armour, ", "))
```

## Certer.is_open

Definition:
```luau
function Certer.is_open(): boolean
```
Whether the quiz is open.

Example:
```luau
print(Certer.is_open())
```

## Certer.wait_open

Definition:
```luau
function Certer.wait_open(timeout_ms: number?): boolean
```
Polls `is_open` for up to `timeout_ms` (default `OPEN_TIMEOUT_MS`).

Example:
```luau
print(Certer.wait_open(2000))
```

## Certer.model

Definition:
```luau
function Certer.model(): number?
```
The model id of the picture, nil when the quiz isn't open.

Example:
```luau
print(Certer.model())
```

## Certer.category

Definition:
```luau
function Certer.category(): Category?
```
The category of the item in the picture, nil when the quiz isn't open or its model isn't one of `MODELS`.

Example:
```luau
print(Certer.category())
```

## Certer.answers

Definition:
```luau
function Certer.answers(): { Answer }?
```
The visible answers, A first. Nil when the quiz isn't open.

Example:
```luau
for _, answer in ipairs(Certer.answers() or {}) do
	print(answer.letter, answer.text)
end
```

## Certer.correct

Definition:
```luau
function Certer.correct(): Answer?
```
The one answer fitting the picture's category; nil (with the reason logged) when the model is unknown or zero or several fit.

Example:
```luau
local Certer = require("@lib/main/interfaces/mainscreen/certer")

local answer = Certer.correct()
print(answer and answer.text)
```

## Certer.select

Definition:
```luau
function Certer.select(answer: Answer): boolean
```
Hovers the answer, clicks once the menu offers `Select option <letter>`, and waits for the quiz to close. False (logged) otherwise.

Example:
```luau
local answer = Certer.correct()
if answer then
	Certer.select(answer)
end
```

## Certer.finish_chat

Definition:
```luau
function Certer.finish_chat(timeout_ms: number?): boolean
```
Continues the post-quiz chat until no continue prompt remains or `timeout_ms` (default `CHAT_TIMEOUT_MS`) passes, falling back to a click if the key doesn't take. True when at least one line was continued.

Example:
```luau
Certer.finish_chat()
```

## Certer.close_button

Definition:
```luau
function Certer.close_button(): Widget?
```
The close button, nil when the quiz isn't open.

Example:
```luau
print(Certer.close_button() ~= nil)
```

## Certer.close

Definition:
```luau
function Certer.close(key_probability: number?): boolean
```
Closes the quiz unanswered by Escape (chance `key_probability`, nil or 0 uses the biometric default) or the close button; see [Toplevel.close](toplevel.md). True if already closed.

Example:
```luau
Certer.close(0.5)
```

## Certer.open

Definition:
```luau
function Certer.open(npc: Npc): (boolean, string?)
```
"Talk-to" on the event NPC, then waits for the quiz. True if open (or already was); otherwise false and a reason.

Example:
```luau
local Npcs = require("@lib/main/entities/npcs")

local npc = (Npcs.find("Giles") or {})[1]
if npc then
	print(Certer.open(npc))
end
```

## Certer.solve

Definition:
```luau
function Certer.solve(): (boolean, string?)
```
Pauses `READ_MS`, selects `correct()` and finishes the chat. With no fitting answer it closes the quiz unanswered. False and a reason on failure.

Example:
```luau
local Certer = require("@lib/main/interfaces/mainscreen/certer")

if Certer.is_open() then
	print(Certer.solve())
end
```
