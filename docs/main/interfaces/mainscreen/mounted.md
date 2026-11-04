# Main.Interfaces.Mainscreen.Mounted

What a house has mounted on its walls: the amulet of glory, the mythical cape, Xeric's talisman and the digsite pendant. The trips are free.

```luau
local Mounted = require("@lib/main/interfaces/mainscreen/mounted")
```

The glory names its places as options, and the cape's "Teleport" has one place. The talisman and the pendant list theirs under "Teleport menu" (group 187, the game's generic `menu` list). Their first options change with the "Configuration" the player set, so those aren't used. Nothing here clicks "Remove", which takes a piece out of the house.

A piece is named by its `Kind`: `"glory"`, `"cape"`, `"talisman"` or `"digsite"`. The chooser uses this through `Transports.house`.

## Mounted.is_open

Definition:
```luau
function Mounted.is_open(): boolean
```
Whether a list is open. The group is shared with other lists, so this only means something after opening one of these.

Example:
```luau
local Mounted = require("@lib/main/interfaces/mainscreen/mounted")

print(Mounted.is_open())
```

## Mounted.destinations

Definition:
```luau
function Mounted.destinations(): { Destination }?
```
The places of the open list, top to bottom, each with `name` ("Xeric's Glade"), `available` (false for one you haven't unlocked) and `row`. Nil when it isn't open.

Example:
```luau
local Mounted = require("@lib/main/interfaces/mainscreen/mounted")

for _, d in ipairs(Mounted.destinations() or {}) do
	print(d.name, d.available)
end
```

## Mounted.find

Definition:
```luau
function Mounted.find(name: string): Destination?
```
The place in the open list whose name contains `name`, ignoring case, when only one does.

Example:
```luau
local Mounted = require("@lib/main/interfaces/mainscreen/mounted")

print(Mounted.find("Glade") ~= nil)
```

## Mounted.select

Definition:
```luau
function Mounted.select(name: string): boolean
```
Clicks a place in the open list and waits for it to close. True once it has. The trip isn't waited for.

Example:
```luau
local Mounted = require("@lib/main/interfaces/mainscreen/mounted")

print(Mounted.select("Glade"))
```

## Mounted.close

Definition:
```luau
function Mounted.close(): boolean
```
Closes the list. See `Toplevel.close`.

Example:
```luau
local Mounted = require("@lib/main/interfaces/mainscreen/mounted")

Mounted.close()
```

## Mounted.teleport

Definition:
```luau
function Mounted.teleport(kind: Kind, place: string): (boolean, string?, boolean?)
```
Finds the piece in the house the player is in, on any floor, goes to it and starts the teleport to `place`, which isn't waited for. False with why when it didn't start, and true third when trying again is pointless: the piece or the place isn't there.

Example:
```luau
local Mounted = require("@lib/main/interfaces/mainscreen/mounted")

print(Mounted.teleport("talisman", "Glade"))
```
