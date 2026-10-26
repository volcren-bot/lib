# Main.Varbits

Read "varbits": game settings stored as a few bits of a bigger setting (a varp). The game files say which setting and which bits; that is looked up for you.

```luau
local Varbits = require("../main/varbits")
```

## Constants

Definition:
```luau
Varbits.SPELLBOOK = 4070
Varbits.BUSY = 12393
```
Named varbit ids. `SPELLBOOK` is the spellbook in use: 0 standard, 1 ancient, 2 lunar, 3 arceuus. `BUSY` is 1 while you're stuck in something you can't walk away from mid-way, like being knocked down or untying a rope: clicks to walk do nothing until it's back to 0.

To find other varbits, `injector varbits-of <pid> <varp>` lists every varbit stored in a varp, with its name.

## Varbits.get

Definition:
```luau
function Varbits.get(id: number): number?
```
The current value of a varbit.

Example:
```luau
local Varbits = require("../main/varbits")

print("spellbook:", Varbits.get(Varbits.SPELLBOOK))
```
