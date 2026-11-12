# Main.Varbits

Read varbits: values stored in a few bits of a varp. The varp and bits are looked up from the game files.

```luau
local Varbits = require("@lib/main/varbits")
```

## Constants

Definition:
```luau
Varbits.SPELLBOOK = 4070
Varbits.BUSY = 12393
```
`SPELLBOOK`: 0 standard, 1 ancient, 2 lunar, 3 arceuus. `BUSY`: 1 during an uninterruptible action (knocked down, untying a rope); walk clicks do nothing until 0. `injector varbits-of <pid> <varp>` lists a varp's varbits by name.

## Varbits.get

Definition:
```luau
function Varbits.get(id: number): number?
```
A varbit's value, or `nil` when unavailable.

Example:
```luau
local Varbits = require("@lib/main/varbits")

print("spellbook:", Varbits.get(Varbits.SPELLBOOK))
```
