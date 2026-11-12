# Main.Interfaces.Chatbox.Skillmulti

The "What would you like to make?" menu in the chat area. To read and use it, see [Make](make.md).

```luau
local Skillmulti = require("@lib/main/interfaces/chatbox/skillmulti")
```

## Constants

Definition:
```luau
Skillmulti.GROUP = 270
```
The menu's interface.

## Skillmulti.is_open

Definition:
```luau
function Skillmulti.is_open(): boolean
```
Whether the menu is open.

Example:
```luau
print(Skillmulti.is_open())
```
