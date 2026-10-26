# Utils.StatsReport

Reports what a script gains (experience, gold, your own counters) to Volcren, so it shows up in the script's totals. It remembers the last values it saw, works out the difference and sends it once a minute, so a script only has to hand it the current numbers.

```luau
local StatsReport = require("../utils/stats_report")
```

## Constants

Definition:
```luau
StatsReport.INTERVAL_MS = 60000
```
How often gains are sent by default, in milliseconds. Once a minute matches how often the loader talks to Volcren.

## StatsReport.new

Definition:
```luau
function StatsReport.new(interval_ms: number?): Tracker
```
Creates a tracker. Make one when the script starts and keep it. `interval_ms` changes how often gains are sent.

Example:
```luau
local StatsReport = require("../utils/stats_report")

local tracker = StatsReport.new()
```

## StatsReport.add_custom

Definition:
```luau
function StatsReport.add_custom(tracker: Tracker, index: number, amount: number)
```
Adds to one of the script's custom counters (the first counter is `index` 1). The counters are set up in the script's limits on the website; a script can only use as many as it has.

Example:
```luau
StatsReport.add_custom(tracker, 1, 3) -- three more of the first counter
```

## StatsReport.flush

Definition:
```luau
function StatsReport.flush(tracker: Tracker): boolean
```
Sends what has been collected right away, instead of waiting for the interval. Returns `true` if something was sent, and `false` if there was nothing new. Call it when the script ends.

Example:
```luau
StatsReport.flush(tracker)
```

## StatsReport.update

Definition:
```luau
function StatsReport.update(tracker: Tracker, skills: { Host.Skill }?, gold: number?): boolean
```
Call this every time through the main loop with the skills from `Host.game_state()` and, if the script earns gold, the gold the player has now. It adds up what was gained since the last call and sends it when the interval has passed. The first call only sets the starting point, and a total that goes down (after a logout, say) does too, so nothing is counted twice. Returns `true` when it sent something.

Example:
```luau
local Host = require("../host")
local StatsReport = require("../utils/stats_report")

local tracker = StatsReport.new()
while true do
	local state = Host.game_state()
	StatsReport.update(tracker, state.skills)
	Host.sleep(600)
end
```
