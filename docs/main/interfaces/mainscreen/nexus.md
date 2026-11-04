# Main.Interfaces.Mainscreen.Nexus

The Portal Nexus in a player's house (group 17, `telenexus_teleport` in the cache): teleports in two lists, opened by "Teleport Menu".

```luau
local Nexus = require("@lib/main/interfaces/mainscreen/nexus")
```

Each row is like `B :  Marim`, and its letter is also its key. The list's names are short ("Fenken' Castle"), so `find` is loose. The rows scroll in a view far shorter than the list, and below the view a click would land on the floor, so `select` scrolls first and only clicks once the menu offers that row. What a Nexus holds is only known by opening it: `poh_nexus_tele_1` and on (varbit 6654 and on) say it has teleports, not which by name.

## Nexus.is_open

Definition:
```luau
function Nexus.is_open(): boolean
```
Whether the list is open.

Example:
```luau
local Nexus = require("@lib/main/interfaces/mainscreen/nexus")

print(Nexus.is_open())
```

## Nexus.open

Definition:
```luau
function Nexus.open(): (boolean, string?)
```
Opens the list, going to the Nexus's floor and walking to it. False and why.

Example:
```luau
local Nexus = require("@lib/main/interfaces/mainscreen/nexus")

print(Nexus.open())
```

## Nexus.destinations

Definition:
```luau
function Nexus.destinations(): { Destination }?
```
Every teleport of the open list, including those scrolled out of view, each with `key`, `name` and `area`. Nil when it isn't open.

Example:
```luau
local Nexus = require("@lib/main/interfaces/mainscreen/nexus")

for _, d in ipairs(Nexus.destinations() or {}) do
	print(d.key, d.name)
end
```

## Nexus.find

Definition:
```luau
function Nexus.find(name: string): Destination?
```
The teleport called `name`: the exact name, else one that starts with the other, else a list name whose first word starts the wanted one's.

Example:
```luau
local Nexus = require("@lib/main/interfaces/mainscreen/nexus")

print(Nexus.find("Fenkenstrain's Castle") ~= nil)
```

## Nexus.select

Definition:
```luau
function Nexus.select(name: string): boolean
```
Scrolls to a teleport of the open list and clicks it once the menu offers it. True once the list has gone: the trip follows.

Example:
```luau
local Nexus = require("@lib/main/interfaces/mainscreen/nexus")

print(Nexus.select("Barrows"))
```

## Nexus.close

Definition:
```luau
function Nexus.close(): boolean
```
Closes the list.

Example:
```luau
local Nexus = require("@lib/main/interfaces/mainscreen/nexus")

print(Nexus.close())
```
