# Utils.Log

```luau
local Log = require("../utils/log")
```

## Log.log

Definition:
```luau
function Log.log(tag: string, ...: any)
```
Prints `[tag][hh:mm:ss:ms]: ...` with the arguments joined by spaces.

Example:
```luau
Log.log("Tempoross", "Wave incoming")
```

## Log.warn

Definition:
```luau
function Log.warn(tag: string, ...: any)
```
Like `Log.log`, but the loader shows the line in yellow (see `Host.report_warning`).

Example:
```luau
Log.warn("Bank", "no bank around")
```

## Log.Row

Definition:
```luau
export type Row = { label: string, value: string? }
```
One line of a `Log.block`: a label with its value, or a heading when `value` is nil.

## Log.block

Definition:
```luau
function Log.block(tag: string, title: string, rows: { Row })
```
Prints one multi-line entry: the usual `[tag][time]:` line with the title, then the rows indented, with the values aligned.

Example:
```luau
Log.block("Progress", "Report", {
	{ label = "Win rate", value = "80%" },
	{ label = "XP" },
	{ label = "Fishing", value = "12,000" },
})
```

## Log.duration

Definition:
```luau
function Log.duration(ms: number): string
```
Formats milliseconds as `h:mm:ss`.

Example:
```luau
Log.duration(3725000) -- "1:02:05"
```

## Log.per_hour

Definition:
```luau
function Log.per_hour(count: number, ms: number): number
```
Rate per hour of `count` events over `ms` milliseconds; 0 when no time has passed.

Example:
```luau
Log.per_hour(3, 1800000) -- 6
```

## Log.number

Definition:
```luau
function Log.number(n: number): string
```
Formats a number with thousands separators, rounded to whole numbers (one decimal below 100).

Example:
```luau
Log.number(1234567.8) -- "1,234,568"
Log.number(2.5) -- "2.5"
```
