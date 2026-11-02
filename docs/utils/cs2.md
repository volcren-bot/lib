# Utils.Cs2

## Cs2.script

Definition:
```luau
function Cs2.script(bytes: string): Script?
```
A compiled CS2 script's instructions (`{ op, value }`) and switch tables, from the bytes of a file of cache index 12. Nil when the bytes aren't a script, including when the instruction count doesn't match the file's own count.

Example:
```luau
local Cs2 = require("@lib/utils/cs2")
local Host = require("@lib/host")

local bytes = Host.cache_file(12, 4024, 0)
local script = bytes and Cs2.script(bytes)
print(script and #script.instructions)
```

## Cs2.dbrow

Definition:
```luau
function Cs2.dbrow(bytes: string): { [number]: Column }?
```
A database row's columns by number, each as `{ types, values }` (values are a list of tuples), from the bytes of a file of cache index 2, archive 38. Nil when the bytes aren't a row.

Example:
```luau
local Cs2 = require("@lib/utils/cs2")
local Host = require("@lib/host")

local bytes = Host.cache_file(2, 38, 17)
local row = bytes and Cs2.dbrow(bytes)
print(row and row[2].values[1][1])
```
