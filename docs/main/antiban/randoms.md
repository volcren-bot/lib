# Main.Antiban.Randoms

The game's random events: NPCs that turn up beside you and try to talk to you. `Randoms.handle` looks for one by its id that is interacting with you, and runs what that event needs. Scripts usually get this through the task `Tasks.handle_randoms`.

```luau
local Randoms = require("@lib/main/antiban/randoms")
```

An NPC counts only when its `interacting_player` is your own player index, so another player's event is left alone. To add an event, add its NPC id to `Randoms.HANDLERS`. Notes on the events seen so far are in `RANDOM_EVENTS.md` at the root of the workspace.

The genie, the certers (Niles, Miles and Giles) and the Dunce's Surprise Exam are handled so far. `handle` first finishes an exam already under way: a script that starts in the classroom sits it before anything else. The genie and Giles were only seen once, and Niles and Miles never, by hand or by running their steps piece by piece; `handle` itself has only run against a stubbed game, because events can't be made to appear.

## The genie

`Talk-to` gives a lamp (item 2528). Any dialogue on the way is continued. The lamp then goes on the skill chosen for the account on the loader's Accounts page (`Lamp.use`). The lamp is kept, and a line logged, when no skill is set, the run has no loader, or the loader can't say.

## The certers

Niles, Miles and Giles are taken to be the same event from their cache names (`macro_niles`, `macro_miles`, `macro_giles`). `Talk-to` opens the certer's quiz, which `Certer.solve` answers (see `Main.Interfaces.Mainscreen.Certer`). When no answer fits the picture, the quiz is closed unanswered and that is logged.

## The Dunce

`Talk-to`, then "Sure, I fancy an exam." takes you to Mr. Mordaut's classroom, where `SurpriseExam.complete` answers the questions and leaves by the door (see `Main.Interfaces.Mainscreen.SurpriseExam`). Run by hand once, 2026-11-07: three of four answers right passed it, and the door gave a Book of Knowledge.

## Constants

Definition:
```luau
Randoms.GENIE = 326
Randoms.GENIE_LAMP = 2528
Randoms.GENIE_OPTION = "Talk-to"
Randoms.NILES = 5436
Randoms.MILES = 5437
Randoms.GILES = 5438
Randoms.GENIE_TIMEOUT_MS = 8000
Randoms.GENIE_SETTLE_MS = 600
Randoms.POLL_MS = 100
```
The genie's NPC id, its lamp's item id, the option that takes the lamp, the certers' NPC ids, how long to wait for the lamp after talking, how long to keep watching for a dialogue once it is there, and the wait between looks.

## Randoms.HANDLERS

Definition:
```luau
export type Handler = (npc: Npc) -> boolean
Randoms.HANDLERS: { [number]: Handler }
```
The events handled, by NPC id. A handler returns true when the event was dealt with.

## Randoms.find

Definition:
```luau
function Randoms.find(): Npc?
```
The first NPC of a known event that is interacting with you, nil when there is none. It reads the NPC list once, so it is cheap to call often.

## Randoms.handle

Definition:
```luau
function Randoms.handle(): boolean
```
Deals with a random event if one is trying to interact with you. True when one was dealt with.

## Randoms.lamp_skill

Definition:
```luau
function Randoms.lamp_skill(): Stats.SkillName?
```
The skill this account's lamps go on, chosen on the loader's Accounts page. Nil when none is set, there is no loader, or the loader can't say, which is logged.

Example:
```luau
local Randoms = require("@lib/main/antiban/randoms")

print(Randoms.lamp_skill())
```
