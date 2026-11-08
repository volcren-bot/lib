# Main.Interfaces.Mainscreen.SurpriseExam

The Surprise Exam random event. The Dunce (NPC 6749) asks whether you'd like an exam; saying "Sure, I fancy an exam." takes you to Mr. Mordaut's (5504) classroom, map square 7502. There the teacher asks questions of two kinds until you pass, and the door (object 9316) takes you back with the reward: a Book of Knowledge, or something else when you already own one.

```luau
local SurpriseExam = require("@lib/main/interfaces/mainscreen/surprise_exam")
```

`Randoms.handle` runs it: `SurpriseExam.accept` for the Dunce, `SurpriseExam.complete` when a script starts in the classroom.

**What comes next** (interface 103, `pattern_next`): three models in a row (children 10 to 12) and four answers (15, 17, 19 and 21, each clicked with "Select"). The answer is the one of the same theme as the row: melee weapons, ranged weapons and so on.

**Three cards** (interface 559, `pattern_cards`): fifteen cards in rows of five, their models at children 21 to 35 and their cells at 52 to 66 ("Select"), a hint at 67 ("This pattern is as sharp as an arrow.") and the button at 68, which offers "Confirm" once three are picked.

A wrong answer is told ("No. No, that's not right at all. Okay, next question.") and the next question follows; one wrong answer out of four still passed. The questions show models made for the exam (ids 41146 to 41232, and a few others such as 2674, 27091 to 27104, 28421 and 29232): they are no item's model, and the cache doesn't say which belong together (enum 1922 lists them all, with what look like display zooms). `ITEMS` names all 97, `THEMES` groups them (38 themes, an item can be in several) with the words a hint uses for each. That data is from Random Event Helper (github.com/Infinitay/Random-Event-Helper), BSD-2-Clause, Copyright (c) 2025, infinity; its fuzzy word matching, synonyms and negations ("not ...") aren't ported. The four questions of the one exam sat by hand (2026-11-07) all come out right, the one answered wrong by hand included; `complete` itself hasn't run.

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
The classroom, the NPCs, the answer to the Dunce and the door; the two questions' interfaces and their pieces; each exam model's item, and the themes with their items and hint words; and the waits: with no question and no talk for this long the exam is over, after an answer, between looks, and for the door.

## SurpriseExam.inside

Definition:
```luau
function SurpriseExam.inside(): boolean
```
Whether you're in the classroom: its map square, or Mr. Mordaut nearby.

## SurpriseExam.item

Definition:
```luau
function SurpriseExam.item(model: number): string?
```
What an exam model shows (`"pirate_hook"`), nil when `ITEMS` doesn't list it.

## SurpriseExam.pattern

Definition:
```luau
function SurpriseExam.pattern(): ({ number }?, { number }?)
```
The open "what comes next" question: the row's three models and the four answers' models. Nil when it isn't open.

## SurpriseExam.pattern_answer

Definition:
```luau
function SurpriseExam.pattern_answer(sequence: { number }, answers: { number }): number
```
The answer (1 to 4) that fits the row best. Each answer scores over every theme by how many of the row's three items the theme has: 3 of them gives 10 when the answer is in the theme too and 4 when it isn't, 2 gives 8 or 2, 1 gives 3 or 0.5, none gives 1 or 0. The highest total wins. Unknown models are logged.

## SurpriseExam.cards

Definition:
```luau
function SurpriseExam.cards(): ({ number }?, string?)
```
The open card question: the fifteen cards' models (rows of five) and the hint. Nil when it isn't open.

## SurpriseExam.hint_scores

Definition:
```luau
function SurpriseExam.hint_scores(hint: string): { [string]: number }
```
How well each theme fits a hint, case ignored: 5 for each of its keywords the hint has as a word or phrase, 3 for one a word of the hint only partly matches ("arrow" and "arrows").

## SurpriseExam.card_answer

Definition:
```luau
function SurpriseExam.card_answer(models: { number }, hint: string): { number }
```
Three cards (1 to 15): each takes the score of its best fitting theme (`hint_scores`), and the three best are picked. Unknown models, and a hint no theme fits, are logged.

## SurpriseExam.answer

Definition:
```luau
function SurpriseExam.answer(): boolean
```
Answers the question that is open, of either kind (the cards are picked, then confirmed). True when an answer was clicked.

## SurpriseExam.leave

Definition:
```luau
function SurpriseExam.leave(): boolean
```
Opens the door out of the classroom (the reward comes then). True once outside.

## SurpriseExam.complete

Definition:
```luau
function SurpriseExam.complete(): boolean
```
Sits the exam from wherever it is: continues the teacher's talk, answers each question, and once neither comes for `QUESTION_TIMEOUT_MS` leaves by the door. True once outside.

## SurpriseExam.accept

Definition:
```luau
function SurpriseExam.accept(dunce: Npc): boolean
```
The Dunce's event: talks to him, says yes to the exam, waits for the classroom, then `complete`. True once back outside.
