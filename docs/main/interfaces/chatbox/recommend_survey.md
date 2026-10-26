# Main.Interfaces.Chatbox.RecommendSurvey

The "Would you recommend it to a friend?" survey that can show up in the chatbox after you log
in. While it's open, actions like world hopping are refused, so answer or skip it first.

Every function returns `false` if the survey isn't open and `nil` if something went wrong.

## RecommendSurvey
Definition:
```luau
local RecommendSurvey: { GROUP: number, ... }
```
The survey itself. `RecommendSurvey.GROUP` is its chatbox interface id (709); the other
constants (`YES`, `NO`, `SKIP`, `DONT_ASK`, `DONT_ASK_BOX`, ...) are the ids of its components.

Example:
```luau
local RecommendSurvey = require("../main/interfaces/chatbox/recommend_survey")

print("survey group:", RecommendSurvey.GROUP)
```

## RecommendSurvey.is_open
Definition:
```luau
function RecommendSurvey.is_open(): boolean
```
Checks if the survey is currently showing.

Example:
```luau
local RecommendSurvey = require("../main/interfaces/chatbox/recommend_survey")

local open = RecommendSurvey.is_open()
print("survey open:", open)
```

## RecommendSurvey.yes
Definition:
```luau
function RecommendSurvey.yes(): boolean
```
Answers "Yes" and waits for the survey to close.

Example:
```luau
local RecommendSurvey = require("../main/interfaces/chatbox/recommend_survey")

print("answered yes:", RecommendSurvey.yes())
```

## RecommendSurvey.no
Definition:
```luau
function RecommendSurvey.no(): boolean
```
Answers "No" and waits for the survey to close.

Example:
```luau
local RecommendSurvey = require("../main/interfaces/chatbox/recommend_survey")

print("answered no:", RecommendSurvey.no())
```

## RecommendSurvey.skip
Definition:
```luau
function RecommendSurvey.skip(): boolean
```
Skips the survey without answering and waits for it to close.

Example:
```luau
local RecommendSurvey = require("../main/interfaces/chatbox/recommend_survey")

if RecommendSurvey.is_open() then
	print("skipped:", RecommendSurvey.skip())
end
```

## RecommendSurvey.dont_ask
Definition:
```luau
function RecommendSurvey.dont_ask(): boolean
```
Checks if the "Don't ask again" box is ticked.

Example:
```luau
local RecommendSurvey = require("../main/interfaces/chatbox/recommend_survey")

print("don't ask again:", RecommendSurvey.dont_ask())
```

## RecommendSurvey.toggle_dont_ask
Definition:
```luau
function RecommendSurvey.toggle_dont_ask(): boolean
```
Clicks the "Don't ask again" box once, flipping it. Prefer `set_dont_ask` if you want a
specific state.

Example:
```luau
local RecommendSurvey = require("../main/interfaces/chatbox/recommend_survey")

print("clicked:", RecommendSurvey.toggle_dont_ask())
```

## RecommendSurvey.set_dont_ask
Definition:
```luau
function RecommendSurvey.set_dont_ask(ticked: boolean): boolean
```
Makes sure the "Don't ask again" box is ticked or unticked, clicking it only if needed.

Example:
```luau
local RecommendSurvey = require("../main/interfaces/chatbox/recommend_survey")

if RecommendSurvey.is_open() then
	print("ticked:", RecommendSurvey.set_dont_ask(true))
	print("skipped:", RecommendSurvey.skip())
end
```
