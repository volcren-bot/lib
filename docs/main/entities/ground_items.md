# Main.Entities.GroundItems

Finding and picking up items that are lying on the ground.

```luau
local GroundItems = require("@lib/main/entities/ground_items")
```

An item is a table with `id`, `quantity`, `name` (can be `nil`), `x`, `y` (world tile) and `plane`. A tile shows its top three items as one pile, and the pile is what the mouse points at; the right-click menu then lists an option for each item in it.

## Constants

Definition:
```luau
GroundItems.ITEM_PILE = 4
GroundItems.PILE_HEIGHT = 40
```
`ITEM_PILE` is the kind of shape the game uses for a tile's pile of items. `PILE_HEIGHT` is the height (fine units) of the box aimed at when the pile isn't drawn yet while walking (see `Clickbox.walking`).

Definition:
```luau
GroundItems.PILE_TAKE_MS = 2400
GroundItems.PILE_WALK_TILE_MS = 600
GroundItems.PILE_REACTION_MS = { 60, 250 }
GroundItems.PILE_ATTEMPTS = 3
```
For `take_pile`: how long a clicked item gets to leave the pile, plus `PILE_WALK_TILE_MS` for each tile the player was from it; the pause, rolled between the two numbers and leaning low, between an item leaving and the next click; and how many clicks in a row may take nothing before it gives up.

## GroundItems.distance

Definition:
```luau
function GroundItems.distance(item: GroundItem, from: Tile): number
```
How many tiles an item is from a tile (diagonal steps count as one).

Example:
```luau
local GroundItems = require("@lib/main/entities/ground_items")
local Walker = require("@lib/main/walker")

local me = assert(Walker.position())
local bones = GroundItems.nearest("Bones", me)
print(bones and GroundItems.distance(bones, me))
```

## GroundItems.find

Definition:
```luau
function GroundItems.find(what: (string | number)?): { GroundItem }?
```
Lists the items on the ground. Give a name or an id to only get matching ones.

Example:
```luau
local GroundItems = require("@lib/main/entities/ground_items")

for _, item in ipairs(GroundItems.find() or {}) do
	print(item.name, item.quantity, item.x, item.y)
end
```

## GroundItems.nearest

Definition:
```luau
function GroundItems.nearest(what: (string | number)?, from: Tile): GroundItem?
```
The closest matching item to a tile.

Example:
```luau
local GroundItems = require("@lib/main/entities/ground_items")
local Walker = require("@lib/main/walker")

local item = GroundItems.nearest("Bones", assert(Walker.position()))
print(if item then `bones at {item.x}, {item.y}` else "no bones around")
```

## GroundItems.refresh

Definition:
```luau
function GroundItems.refresh(item: GroundItem): GroundItem?
```
Gets the up-to-date version of an item you found earlier (its quantity may have changed). Returns `nil` if it's gone.

Example:
```luau
local GroundItems = require("@lib/main/entities/ground_items")
local Walker = require("@lib/main/walker")

local item = GroundItems.nearest("Bones", assert(Walker.position()))
if item then
	print(GroundItems.refresh(item) ~= nil and "still there" or "gone")
end
```

## GroundItems.model

Definition:
```luau
function GroundItems.model(item: GroundItem): NpcModel?
```
The shape of the item's pile as drawn on screen right now.

Example:
```luau
local GroundItems = require("@lib/main/entities/ground_items")
local Walker = require("@lib/main/walker")

local item = GroundItems.nearest("Bones", assert(Walker.position()))
local model = item and GroundItems.model(item)
print(model and #model.faces)
```

## GroundItems.clickbox

Definition:
```luau
function GroundItems.clickbox(item: GroundItem): Clickbox?
```
The area on screen where a click lands on the item's pile. See [Clickbox](../clickbox.md).

Example:
```luau
local Clickbox = require("@lib/main/clickbox")
local GroundItems = require("@lib/main/entities/ground_items")
local Walker = require("@lib/main/walker")

local item = GroundItems.nearest("Bones", assert(Walker.position()))
local box = item and GroundItems.clickbox(item)
if box then
	Clickbox.draw(box)
end
```

## GroundItems.owns

Definition:
```luau
function GroundItems.owns(item: GroundItem, entry: MenuEntry): boolean
```
Whether a right-click menu line belongs to this kind of item. The menu doesn't say which tile, so the same item elsewhere counts too.

Example:
```luau
local Host = require("@lib/host")
local GroundItems = require("@lib/main/entities/ground_items")
local Walker = require("@lib/main/walker")

local item = GroundItems.nearest("Bones", assert(Walker.position()))
if item then
	for _, entry in ipairs(Host.menu() or {}) do
		print(entry.option, GroundItems.owns(item, entry))
	end
end
```

## GroundItems.hovered

Definition:
```luau
function GroundItems.hovered(item: GroundItem): boolean
```
Whether the game currently has the mouse on this item.

Example:
```luau
local GroundItems = require("@lib/main/entities/ground_items")
local Walker = require("@lib/main/walker")

local item = GroundItems.nearest("Bones", assert(Walker.position()))
if item then
	print("mouse is on it:", GroundItems.hovered(item))
end
```

## GroundItems.hover

Definition:
```luau
function GroundItems.hover(item: GroundItem): boolean
```
Moves the mouse onto the item's pile until the game lists the item in the menu. If it is nearby but off screen, the camera is turned and zoomed out first.

Example:
```luau
local GroundItems = require("@lib/main/entities/ground_items")
local Walker = require("@lib/main/walker")

local item = GroundItems.nearest("Bones", assert(Walker.position()))
if item then
	print(GroundItems.hover(item))
end
```

## GroundItems.hover_async

Definition:
```luau
function GroundItems.hover_async(item: GroundItem): boolean
```
Like `GroundItems.hover`, but queues the move as async input and returns at once, without turning the camera or checking that the game lists it under the mouse. Returns `false` if the item isn't on screen.

Example:
```luau
local GroundItems = require("@lib/main/entities/ground_items")

local found = GroundItems.find()
if found and #found > 0 then
	GroundItems.hover_async(found[1])
end
```

## GroundItems.click

Definition:
```luau
function GroundItems.click(item: GroundItem, button: Mouse.Button?, spam: number?): boolean
```
Hovers the item and clicks it (left button by default). `spam` is the chance of a few more clicks on the same spot, see [Interact.spam_click](../interact.md#interactspam_click).

Example:
```luau
local GroundItems = require("@lib/main/entities/ground_items")
local Walker = require("@lib/main/walker")

local item = GroundItems.nearest("Bones", assert(Walker.position()))
if item then
	print(GroundItems.click(item))
end
```

## GroundItems.interact

Definition:
```luau
function GroundItems.interact(item: GroundItem, option: string, walk_timeout_ms: (number | false)?, spam: number?): boolean
```
`spam` is the chance of a few more clicks on the same spot, see [Interact.spam_click](../interact.md#interactspam_click).

Picks an option (such as `"Take"` or `"Examine"`) on the item. Retries if the wrong thing got clicked, and waits for you to arrive if it made you walk. `false` skips the wait.

Example:
```luau
local GroundItems = require("@lib/main/entities/ground_items")
local Walker = require("@lib/main/walker")

local item = GroundItems.nearest("Bones", assert(Walker.position()))
if item then
	local ok = GroundItems.interact(item, "Take")
	print(ok)
end
```

## GroundItems.approach

Definition:
```luau
function GroundItems.approach(item: GroundItem, options: string | { string }, opts: Clickbox.Approach?): boolean
```
Walks to the item and picks the first of `options` its menu has, walking early on the way when it's close (see `Clickbox.approach`). Use it for an item too far away to click yet; `interact` is for one you can already see.

Example:
```luau
local GroundItems = require("@lib/main/entities/ground_items")
local Walker = require("@lib/main/walker")

local item = GroundItems.nearest("Bones", assert(Walker.position()))
if item then
	print(GroundItems.approach(item, "Take"))
end
```

## GroundItems.fits

Definition:
```luau
function GroundItems.fits(item: GroundItem): boolean
```
Whether the item can be picked up now: the inventory has a free slot, or the item stacks and a stack of it is already carried. Whether an item stacks is asked of the client once per id.

## GroundItems.take_pile

Definition:
```luau
function GroundItems.take_pile(tile: Tile): (number, string?)
```
Takes every item on the tile by left-clicking its pile again and again, as a player clearing a pile does. Each click takes whatever the game puts on top of the menu (its own order, by the items' menu priority), so no right-click menu opens. The mouse is moved onto the pile only when the top row isn't Take on one of its items (the first click, or after the pile moved under it). After each click it waits for that item to leave the tile, then pauses `PILE_REACTION_MS` before the next. Returns how many items were taken, and nil once the tile is empty, `"full"` when the item on top doesn't fit (`fits`), or `"failed"` when the pile can't be hovered, its left click isn't Take, or `PILE_ATTEMPTS` clicks in a row took nothing. Use it when the whole pile is wanted; for some of its items, `interact` each one with "Take".

Example:
```luau
local GroundItems = require("@lib/main/entities/ground_items")
local Walker = require("@lib/main/walker")

local item = GroundItems.nearest(nil, assert(Walker.position()))
if item then
	print(GroundItems.take_pile({ x = item.x, y = item.y }))
end
```
