# Main.Interfaces.Mainscreen.Certer

The certer's quiz: a picture of an item and three answers, "Is this: A helmet. / A fish. / A bowl.", opened by "Talk-to" on the random event's NPC (group 184, `macro_certer` in the cache). `Tasks.handle_randoms` runs it for Niles, Miles and Giles.

```luau
local Certer = require("@lib/main/interfaces/mainscreen/certer")
```

The picture is a rotating model. `Host.widget_model` gives its id, which says which of the quiz's items it is (`macro_quiz_*` in the cache), and so its category. The answer is the one line whose words fit the category. With none or several, or a picture that isn't known, nothing is guessed, because what a wrong answer does isn't known.

One quiz has been answered, Giles's, armour with "A helmet". Niles and Miles haven't been seen. After it Giles says one line in the chat, gives a reward (a Kebab that time), and leaves when the line is continued. The other categories' words in `WORDS` are expected ones that haven't been seen.

An answer has `letter`, `text` and `button` (where to hover and click).

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
The interface piece numbers, the option that opens the quiz, a button's option before its letter, and the waits: for `wait_open`, for a hover to show the menu, for the quiz to go after a click, for the chat after it, between looks, for the menu to follow the mouse, and a moment to read the question before answering.

## Certer.MODELS

Definition:
```luau
export type Category = "food" | "weapon" | "armour" | "tool" | "jewel"
Certer.MODELS: { [number]: Category }
```
The quiz's items by the model id of their picture.

## Certer.WORDS

Definition:
```luau
Certer.WORDS: { [Category]: { string } }
```
The words of an answer that fit each category, matched as whole words. Add to these when a quiz is logged with "no answer fits".

## Certer.is_open

Definition:
```luau
function Certer.is_open(): boolean
```
Whether the quiz is open.

## Certer.wait_open

Definition:
```luau
function Certer.wait_open(timeout_ms: number?): boolean
```
Whether the quiz is open, polled for up to `timeout_ms` (`OPEN_TIMEOUT_MS` by default).

## Certer.model

Definition:
```luau
function Certer.model(): number?
```
The model id of the picture, nil when the quiz isn't open.

## Certer.category

Definition:
```luau
function Certer.category(): Category?
```
The category of the item in the picture, nil when the quiz isn't open or its model isn't one of `MODELS`.

## Certer.answers

Definition:
```luau
function Certer.answers(): { Answer }?
```
The three answers, in order. Nil when the quiz isn't open.

## Certer.correct

Definition:
```luau
function Certer.correct(): Answer?
```
The answer that fits the picture's category. Exactly one must, or it is nil and the reason is logged.

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
Clicks an answer's button and waits for the quiz to go. The click only happens once the menu under the mouse offers that button.

## Certer.finish_chat

Definition:
```luau
function Certer.finish_chat(timeout_ms: number?): boolean
```
Continues the chat the quiz ends with, until it has been clear for a moment or `timeout_ms` (`CHAT_TIMEOUT_MS` by default) is up, by click if a key doesn't take. True when at least one line was continued.

## Certer.close_button

Definition:
```luau
function Certer.close_button(): Widget?
```
The close button, nil when the quiz isn't open.

## Certer.close

Definition:
```luau
function Certer.close(key_probability: number?): boolean
```
Closes the quiz without answering: Escape (chance `key_probability`; nil or 0 is the Escape biometric) unless "Esc to close" is off, else the close button. See `Toplevel.close`.

## Certer.open

Definition:
```luau
function Certer.open(npc: Npc): (boolean, string?)
```
Opens the quiz with "Talk-to" on the event's NPC. True when it is open, also if it already was. When it didn't work the second result says why.

## Certer.solve

Definition:
```luau
function Certer.solve(): (boolean, string?)
```
Answers the open quiz and finishes the chat after it. With no answer that fits, the quiz is closed unanswered. When it didn't work the second result says why.

Example:
```luau
local Certer = require("@lib/main/interfaces/mainscreen/certer")

if Certer.is_open() then
	print(Certer.solve())
end
```
