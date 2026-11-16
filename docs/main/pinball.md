# Main.Pinball

The pinball random event. Flippa (NPC 6744, `pinball_invitation`) asks "You want play game of pinball?"; "Yes, pinball is fun." takes you to an instance with five Pinball Posts, the trolls Flippa (5427) and Tilt (5428), and a Cave Exit (object 9293). Tag the lit post ten times, then leave by the exit, which puts you back where you were with the reward. `Randoms.handle` calls `accept` for Flippa and `complete` when a script starts inside.

```luau
local Pinball = require("@lib/main/pinball")
```

The lit post can't be told from its object: it keeps its inactive id and only its animation changes, which the agent doesn't read. Varbit 2119 (`macro_pinball_current`) says which one is lit, 0 to 4 for the tree, iron, coal, fishing and essence posts (`POSTS`), and varbit 2121 (`macro_pinball_score`) counts the tags. The game moves the light about a second after a tag, so `tag` waits for the score to rise before the next one. The mapping comes from Random Event Helper (github.com/Infinitay/Random-Event-Helper), BSD-2-Clause, Copyright (c) 2025, infinity. What tagging the wrong post does hasn't been seen.

## Constants

Definition:
```luau
Pinball.FLIPPA = 6744
Pinball.ACCEPT = "Yes, pinball is fun."
Pinball.EXIT = 9293
Pinball.EXIT_OPTION = "Exit"
Pinball.TAG = "Tag"
Pinball.CURRENT = 2119
Pinball.SCORE = 2121
Pinball.TAGS = 10
Pinball.POSTS = { [0] = 8982, [1] = 8984, [2] = 9079, [3] = 9081, [4] = 9258 }
```

## Pinball.inside

Definition:
```luau
function Pinball.inside(): boolean
```
Whether you are in the pinball game: its cave exit is in the scene.

Example:
```luau
print(Pinball.inside())
```

## Pinball.post

Definition:
```luau
function Pinball.post(): Loc?
```
The post to tag now, from varbit 2119; nil when it can't be read or isn't in the scene.

Example:
```luau
local post = Pinball.post()
print(post and post.x, post and post.y)
```

## Pinball.score

Definition:
```luau
function Pinball.score(): number
```
Tags counted so far (varbit 2121).

Example:
```luau
print(Pinball.score())
```

## Pinball.tag

Definition:
```luau
function Pinball.tag(): boolean
```
Tags the lit post and waits up to `TAG_TIMEOUT_MS` for the score to rise. False when the post can't be found or the tag didn't count.

Example:
```luau
print(Pinball.tag())
```

## Pinball.leave

Definition:
```luau
function Pinball.leave(): boolean
```
Walks to the cave exit, uses it and waits up to `LEAVE_TIMEOUT_MS` to be out.

Example:
```luau
print(Pinball.leave())
```

## Pinball.complete

Definition:
```luau
function Pinball.complete(): boolean
```
Continues any dialogue and tags lit posts until the score is `TAGS`, then leaves. Gives up after three tags in a row that didn't count.

Example:
```luau
if Pinball.inside() then
	print(Pinball.complete())
end
```

## Pinball.accept

Definition:
```luau
function Pinball.accept(flippa: Host.Npc): boolean
```
Talks to Flippa, accepts the game, waits to arrive and runs `complete`.

Example:
```luau
local Npcs = require("@lib/main/entities/npcs")

local flippa = Npcs.find(Pinball.FLIPPA)
if flippa and flippa[1] then
	print(Pinball.accept(flippa[1]))
end
```
