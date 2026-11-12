# Utils.StatsReport

Turns current totals into the gains [Host.report_stats](../host.md) wants and sends them every interval.

```luau
local StatsReport = require("@lib/utils/stats_report")
```

## Constants

Definition:
```luau
StatsReport.INTERVAL_MS = 60000
```
Default send interval, matching the loader heartbeat.

## StatsReport.new

Definition:
```luau
function StatsReport.new(interval_ms: number?): Tracker
```
Creates a tracker; make one at start and keep it.

Example:
```luau
local StatsReport = require("@lib/utils/stats_report")

local tracker = StatsReport.new()
```

## StatsReport.add_custom

Definition:
```luau
function StatsReport.add_custom(tracker: Tracker, index: number, amount: number)
```
Adds to custom counter `index` (1-based), as configured in the script's website limits.

Example:
```luau
StatsReport.add_custom(tracker, 1, 3) -- three more of the first counter
```

## StatsReport.flush

Definition:
```luau
function StatsReport.flush(tracker: Tracker): boolean
```
Sends pending gains now; returns whether anything was sent. Call it at script end.

Example:
```luau
StatsReport.flush(tracker)
```

## StatsReport.update

Definition:
```luau
function StatsReport.update(tracker: Tracker, skills: { Host.Skill }?, gold: number?): boolean
```
Call each loop with `game_state().skills` and optionally current gold; accumulates gains and sends when the interval passed. The first call only sets the baseline; an XP drop (logout) resets it, while gold changes count either way. Returns whether it sent.

Example:
```luau
local Host = require("@lib/host")
local StatsReport = require("@lib/utils/stats_report")

local tracker = StatsReport.new()
while true do
	local state = Host.game_state()
	StatsReport.update(tracker, state.skills)
	Host.sleep(600)
end
```
