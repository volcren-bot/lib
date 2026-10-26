# Main.Interfaces.Chatbox.Skillmulti

The "what do you want to make?" menu that appears in the chat area when you can craft several things at once (for example choosing between several items to cook or fletch).

```luau
local Skillmulti = require("../main/interfaces/chatbox/skillmulti")
```

## Constants

Definition:
```luau
Skillmulti.GROUP = 270
```
The interface number of the menu.

## Skillmulti.is_open

Definition:
```luau
function Skillmulti.is_open(): boolean
```
Whether the menu is open.

Example:
```luau
local Skillmulti = require("../main/interfaces/chatbox/skillmulti")

print("menu open:", Skillmulti.is_open())
```
