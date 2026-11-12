# Main.Interfaces.Mainscreen.SurpriseExam

The Surprise Exam random event. The Dunce (NPC 6749) offers an exam; accepting takes you to Mr. Mordaut's (5504) classroom, map square 7502, where he asks questions until you pass, then the door (object 9316) takes you back with the reward. `Randoms.handle` calls `accept` for the Dunce and `complete` when a script starts in the classroom.

```luau
local SurpriseExam = require("@lib/main/interfaces/mainscreen/surprise_exam")
```

**What comes next** (interface 103): a row of three models (children 10 to 12) and four answers (15, 17, 19, 21, "Select"); the answer shares the row's theme.

**Three cards** (interface 559): fifteen cards in rows of five, models at children 21 to 35, cells at 52 to 66 ("Select"), a hint at 67 and "Confirm" at 68 once three are picked.

A wrong answer just moves to the next question; one wrong out of four still passed. The exam models (mostly 41146 to 41232) belong to no item, so `ITEMS` names all 97 and `THEMES` groups them into 38 themes with hint keywords. That data is from Random Event Helper (github.com/Infinitay/Random-Event-Helper), BSD-2-Clause, Copyright (c) 2025, infinity; its fuzzy matching, synonyms and negations aren't ported. The solvers answered one hand-sat exam correctly; `complete` itself hasn't run live.

## Constants

Definition:
```luau
SurpriseExam.REGION = 7502
SurpriseExam.MORDAUT = 5504
SurpriseExam.DUNCE = 6749
SurpriseExam.ACCEPT = "Sure, I fancy an exam."
SurpriseExam.DOOR = 9316
SurpriseExam.PATTERN = 103
SurpriseExam.PATTERN_SEQUENCE = { 10, 11, 12 }
SurpriseExam.PATTERN_ANSWERS = { 15, 17, 19, 21 }
SurpriseExam.SELECT = "Select"
SurpriseExam.CARDS = 559
SurpriseExam.CARD_MODELS = 21
SurpriseExam.CARD_CELLS = 52
SurpriseExam.CARD_COUNT = 15
SurpriseExam.CARD_PICKS = 3
SurpriseExam.CARD_HINT = 67
SurpriseExam.CARD_CONFIRM = 68
SurpriseExam.CONFIRM = "Confirm"
SurpriseExam.ITEMS: { [number]: string }
SurpriseExam.THEMES: { [string]: { items: { string }, keywords: { string } } }
SurpriseExam.QUESTION_TIMEOUT_MS = 6000
SurpriseExam.ANSWER_SETTLE_MS = 1200
SurpriseExam.POLL_MS = 100
SurpriseExam.LEAVE_TIMEOUT_MS = 8000
```
Region, NPC and object ids, the accept option, the two question interfaces and their children, model-to-item and theme data, and timings. `QUESTION_TIMEOUT_MS` is how long with no question or dialogue means the exam is over.

## SurpriseExam.inside

Definition:
```luau
function SurpriseExam.inside(): boolean
```
Whether you're in the classroom: in its map square, or with Mr. Mordaut loaded.

## SurpriseExam.item

Definition:
```luau
function SurpriseExam.item(model: number): string?
```
The item an exam model shows (`"pirate_hook"`), nil when not in `ITEMS`.

## SurpriseExam.pattern

Definition:
```luau
function SurpriseExam.pattern(): ({ number }?, { number }?)
```
The open "what comes next" question: the row's three model ids and the four answers' (-1 for a missing model). Nil, nil when it isn't open.

## SurpriseExam.pattern_answer

Definition:
```luau
function SurpriseExam.pattern_answer(sequence: { number }, answers: { number }): number
```
The answer index (1 to 4) that fits best. For each theme, counting how many row items it has (0 to 3), an answer in the theme scores 1/3/8/10 and one outside it 0/0.5/2/4; the highest total wins, ties to the lower index. Logs unknown models.

Example:
```luau
local row, answers = SurpriseExam.pattern()
if row and answers then
	print(SurpriseExam.pattern_answer(row, answers))
end
```

## SurpriseExam.cards

Definition:
```luau
function SurpriseExam.cards(): ({ number }?, string?)
```
The open card question: the fifteen card model ids (rows of five) and the hint text. Nil, nil when it isn't open.

## SurpriseExam.hint_scores

Definition:
```luau
function SurpriseExam.hint_scores(hint: string): { [string]: number }
```
Each theme's fit to `hint`, case-insensitive: 5 per keyword present as a word or phrase, else 3 per keyword that a hint word longer than two letters partly matches ("arrow"/"arrows").

## SurpriseExam.card_answer

Definition:
```luau
function SurpriseExam.card_answer(models: { number }, hint: string): { number }
```
The three card indices (1 to 15) whose best theme scores highest under `hint_scores`, with a small random tiebreak. Logs unknown models and a hint no theme fits.

## SurpriseExam.answer

Definition:
```luau
function SurpriseExam.answer(): boolean
```
Answers whichever question is open; for cards, selects three then confirms. True when the answer (or Confirm) was clicked.

## SurpriseExam.leave

Definition:
```luau
function SurpriseExam.leave(): boolean
```
Opens the classroom door and waits up to `LEAVE_TIMEOUT_MS` to be outside. True once outside.

## SurpriseExam.complete

Definition:
```luau
function SurpriseExam.complete(): boolean
```
Sits the exam from any point: continues dialogue and answers questions until neither appears for `QUESTION_TIMEOUT_MS`, then leaves. True once outside, at once if not inside.

Example:
```luau
if SurpriseExam.inside() then
	SurpriseExam.complete()
end
```

## SurpriseExam.accept

Definition:
```luau
function SurpriseExam.accept(dunce: Host.Npc): boolean
```
Talks to the Dunce, accepts the exam, waits up to `QUESTION_TIMEOUT_MS` for the classroom, then runs `complete`. True once back outside.
