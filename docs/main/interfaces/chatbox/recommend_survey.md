# Main.Interfaces.Chatbox.RecommendSurvey

The "Would you recommend it to a friend?" survey that can show in the chatbox after login. While it's open, actions like world hopping are refused, so answer or skip it first. Every function returns `false` when the survey isn't open or the click fails. Buttons are pressed by moving the mouse onto them and clicking only once the menu shows that button.

```luau
local RecommendSurvey = require("@lib/main/interfaces/chatbox/recommend_survey")
```

## Constants

Definition:
```luau
RecommendSurvey.GROUP = 709
RecommendSurvey.FOOTNOTE = 1
RecommendSurvey.DONT_ASK = 2
RecommendSurvey.TITLE = 3
RecommendSurvey.NO = 4
RecommendSurvey.SKIP = 5
RecommendSurvey.YES = 6
RecommendSurvey.DONT_ASK_LABEL = 9
RecommendSurvey.DONT_ASK_BOX = 10
```
The survey's interface and the components of its buttons, title and "Don't ask again" box.

## RecommendSurvey.is_open

Definition:
```luau
function RecommendSurvey.is_open(): boolean
```
Whether the survey is showing.

Example:
```luau
print(RecommendSurvey.is_open())
```

## RecommendSurvey.yes

Definition:
```luau
function RecommendSurvey.yes(): boolean
```
Answers "Yes" and waits up to 3 seconds for the survey to close.

Example:
```luau
print(RecommendSurvey.yes())
```

## RecommendSurvey.no

Definition:
```luau
function RecommendSurvey.no(): boolean
```
Answers "No" and waits up to 3 seconds for the survey to close.

Example:
```luau
print(RecommendSurvey.no())
```

## RecommendSurvey.skip

Definition:
```luau
function RecommendSurvey.skip(): boolean
```
Skips the survey and waits up to 3 seconds for it to close.

Example:
```luau
if RecommendSurvey.is_open() then
	RecommendSurvey.skip()
end
```

## RecommendSurvey.dont_ask

Definition:
```luau
function RecommendSurvey.dont_ask(): boolean
```
Whether the "Don't ask again" box is ticked.

Example:
```luau
print(RecommendSurvey.dont_ask())
```

## RecommendSurvey.toggle_dont_ask

Definition:
```luau
function RecommendSurvey.toggle_dont_ask(): boolean
```
Clicks the "Don't ask again" box once without waiting for it to change. Use `set_dont_ask` for a specific state.

Example:
```luau
print(RecommendSurvey.toggle_dont_ask())
```

## RecommendSurvey.set_dont_ask

Definition:
```luau
function RecommendSurvey.set_dont_ask(ticked: boolean): boolean
```
Ticks or unticks the "Don't ask again" box, clicking only if needed, and waits up to 1.2 seconds for it to change.

Example:
```luau
if RecommendSurvey.set_dont_ask(true) then
	RecommendSurvey.skip()
end
```
