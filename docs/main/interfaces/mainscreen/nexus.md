# Main.Interfaces.Mainscreen.Nexus

The Portal Nexus teleport list in a player's house (group 17, cache `telenexus_teleport`), opened by "Teleport Menu". Rows read like `B :  Marim`; the letter is also the key. Names are abbreviated ("Fenken' Castle"), so `find` matches loosely. What a Nexus holds can be read without opening it via `House.nexus_teleports`.

```luau
local Nexus = require("@lib/main/interfaces/mainscreen/nexus")
```

## Nexus.is_open

Definition:
```luau
function Nexus.is_open(): boolean
```
Whether the list is open.

Example:
```luau
print(Nexus.is_open())
```

## Nexus.open

Definition:
```luau
function Nexus.open(): (boolean, string?)
```
Reaches the Nexus via `House.reach` (changing floor if needed), uses "Teleport Menu" and waits for the list. True at once if already open; otherwise false plus a reason.

Example:
```luau
print(Nexus.open())
```

## Nexus.destinations

Definition:
```luau
function Nexus.destinations(): { Destination }?
```
Every teleport across both lists, including rows scrolled out of view, each with `key`, `name` and `area` (click widget). Nil when not open.

Example:
```luau
for _, d in ipairs(Nexus.destinations() or {}) do
	print(d.key, d.name)
end
```

## Nexus.find

Definition:
```luau
function Nexus.find(name: string): Destination?
```
The teleport called `name` (case-insensitive), else the same place by `House.same_place` ("Fenken' Castle" for "Fenkenstrain's Castle"). Nil when absent or not open.

Example:
```luau
print(Nexus.find("Fenkenstrain's Castle") ~= nil)
```

## Nexus.select

Definition:
```luau
function Nexus.select(name: string): boolean
```
Scrolls the row into view, hovers it and clicks only once the menu offers that row (a click below the view would hit the floor). True once the list closes; the trip itself isn't waited for.

Example:
```luau
print(Nexus.select("Barrows"))
```

## Nexus.close

Definition:
```luau
function Nexus.close(): boolean
```
Closes the list via `Toplevel.close`. True once closed.

Example:
```luau
print(Nexus.close())
```
