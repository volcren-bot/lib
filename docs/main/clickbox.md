# Main.Clickbox

Aiming the mouse at characters and objects. A "clickbox" is the area on screen where the game accepts a click for something (a character, a tree, a door). This module picks a good spot inside it, makes sure the game agrees the mouse is on the right thing, and clicks.

You normally use this through [Npcs](entities/npcs.md), [Objects](entities/objects.md) and [Players](entities/players.md), which build the clickbox for you.

```luau
local Clickbox = require("../main/clickbox")
```

## Settings

Definition:
```luau
Clickbox.TARGET_TRIES = 30
Clickbox.MIN_TRIANGLE_AREA = 4
Clickbox.MOUSE_FALLOFF = 0.25
Clickbox.CAMERA_RANGE = 15
Clickbox.ATTEMPTS = 5
Clickbox.HOVER_TIMEOUT = 150
Clickbox.MISCLICK_ATTEMPTS = 3
Clickbox.ANCHOR_HEIGHT = 200
Clickbox.WALK_REACTION_MS = 30
Clickbox.WALK_HOLD_MS = 150
Clickbox.WALK_LEAD_MS = 300
Clickbox.WALK_LEAD_TOLERANCE = 40
```
- `TARGET_TRIES`: how many times to try finding a free spot.
- `MIN_TRIANGLE_AREA`: parts of the shape smaller than this (in pixels) are ignored.
- `MOUSE_FALLOFF`: how strongly spots near the current mouse position are preferred.
- `CAMERA_RANGE`: things closer than this many tiles that aren't on the screen may get the camera zoomed out to show them. Set to `nil` to never zoom out for them. Turning towards things is `Camera.face`, with its own settings.
- `ATTEMPTS` / `HOVER_TIMEOUT`: how many times to aim and how long (milliseconds) to wait for the game to confirm the mouse is on the thing.
- `MISCLICK_ATTEMPTS`: how many times to retry when the game did something else.
- `ANCHOR_HEIGHT`: the height (fine units) of the reference point used to move a drawn box while walking (see `Clickbox.walking`).
- `WALK_REACTION_MS`: while walking, how long after the mouse lands the click goes in; the box is aimed at where it'll be by then.
- `WALK_HOLD_MS`: while walking, how long the spot should stay inside the box after that.
- `WALK_LEAD_MS`: the guess at the mouse's travel time when the thing isn't drawn yet.
- `WALK_LEAD_TOLERANCE`: the aim is worked out again for the spot it picked unless its travel time is within this many milliseconds of the guess.

## Clickbox.from_model

Definition:
```luau
function Clickbox.from_model(model: Model, what: string): Clickbox?
```
Builds a clickbox from the outline the game drew for a character or object. `what` is a name used in error messages. Returns `nil` and a message when the thing isn't in front of the camera.

Example:
```luau
local Host = require("../host")
local Clickbox = require("../main/clickbox")

local npcs = Host.npcs() or {}
if npcs[1] then
	local model = Host.npc_model(npcs[1].index)
	if model then
		local box = Clickbox.from_model(model, npcs[1].name)
		print(if box then "got a clickbox" else "unavailable")
	end
end
```

## Clickbox.target

Definition:
```luau
function Clickbox.target(box: Clickbox, what: string, keep: ((Point) -> boolean)?): Point?
```
Picks a spot inside the clickbox that isn't covered by any interface, leaning towards where the mouse already is. `keep` can turn down spots (for example ones that won't stay in the box). Returns `nil` and a message if nothing is visible.

Example:
```luau
local Clickbox = require("../main/clickbox")
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local npc = Npcs.nearest("Man", me)
local box = npc and Npcs.clickbox(npc)
if box then
	print(Clickbox.target(box, "the man"))
end
```

## Clickbox.reveal

Definition:
```luau
function Clickbox.reveal(clickbox: () -> Clickbox?, tile: () -> Tile?, what: string): boolean
```
Makes sure the thing is on the screen. If it isn't, it zooms out until it is, as long as it is within `CAMERA_RANGE` tiles. Does nothing when it is already visible. `Clickbox.hover` first turns the camera so the thing shows in the upper half of the screen (`Camera.face`).

Example:
```luau
local Clickbox = require("../main/clickbox")
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local npc = Npcs.nearest("Man", me)
if npc then
	print(Clickbox.reveal(function()
		return Npcs.clickbox(npc)
	end, function()
		return { x = npc.x, y = npc.y }
	end, "the man"))
end
```

## Clickbox.hover

Definition:
```luau
function Clickbox.hover(
	clickbox: () -> Clickbox?,
	hovered: () -> boolean,
	what: string,
	tile: (() -> Tile?)?
): boolean
```
Moves the mouse onto the thing and waits until the game confirms (through `hovered`) that the mouse is really on it. It aims again if the thing moved. Passing `tile` lets it first turn the camera so the thing shows in the upper half of the screen (`Camera.face`), and bring it on screen (`Clickbox.reveal`).

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local npc = Npcs.nearest("Man", me)
if npc then
	print(Npcs.hover(npc))
end
```

## Clickbox.hover_async

Definition:
```luau
function Clickbox.hover_async(clickbox: () -> Clickbox?, what: string): boolean
```
Starts the mouse moving onto the thing and returns at once. It aims from where the thing will be when the mouse arrives, but doesn't turn the camera or check the hover. Returns `true` if there was a spot to aim at, `false` if the thing isn't on screen.

Example:
```luau
-- see Npcs.hover_async
```

## Clickbox.click

Definition:
```luau
function Clickbox.click(
	clickbox: () -> Clickbox?,
	hovered: () -> boolean,
	what: string,
	button: Mouse.Button?,
	tile: (() -> Tile?)?
): boolean
```
Hovers the thing (see `hover`) and clicks it with the given mouse button (left by default).

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local npc = Npcs.nearest("Man", me)
if npc then
	print(Npcs.click(npc))
end
```

## Clickbox.interact

Definition:
```luau
function Clickbox.interact(
	clickbox: () -> Clickbox?,
	hovered: () -> boolean,
	what: string,
	option: string,
	target: Minimenu.Target?,
	tile: (() -> Tile?)?,
	walk_timeout_ms: (number | false)?
): boolean
```
Hovers the thing and picks an option on it (like "Talk-to"), then waits until you arrive if it made you walk. If the game clicked something else by mistake it tries again, up to `MISCLICK_ATTEMPTS` times.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local npc = Npcs.nearest("Man", me)
if npc then
	print(Npcs.interact(npc, "Talk-to"))
end
```

## Clickbox.draw

Definition:
```luau
function Clickbox.draw(box: Clickbox, color: Draw.Color?)
```
Draws the clickbox on top of the game, which is useful to see what a script is aiming at.

Example:
```luau
local Clickbox = require("../main/clickbox")
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local me = assert(Walker.position())
local npc = Npcs.nearest("Man", me)
local box = npc and Npcs.clickbox(npc)
if box then
	Clickbox.draw(box)
end
```

## Clickbox.from_cuboid

Definition:
```luau
function Clickbox.from_cuboid(cuboid: { bottom: Quad, top: Quad }): Clickbox
```
A clickbox from a projected cuboid (see `Projection.cuboid`): its outline is the hull of the box's corners, and only the box is aimed at, since there are no triangles to aim at.

Example:
```luau
local Projection = require("../main/projection/projection")
local Clickbox = require("../main/clickbox")

local cuboid = assert(Projection.cuboid(5824, 7104))
local box = Clickbox.from_cuboid(cuboid)
```

## Clickbox.walking

Definition:
```luau
function Clickbox.walking(model: () -> Clickbox?, anchor: () -> Anchor?, what: string): Aim

export type Aim = (lead_ms: number?) -> Clickbox?
export type Anchor = { x: number, y: number, size: number?, height: number? }
```
The aim for a thing (see `Clickbox.hover`). Called without `lead_ms` it's the client's `model` box as drawn now. Called with `lead_ms` while the player walks, it's where the box will be on screen that many milliseconds from now: the camera follows the player, so things slide across the screen while the mouse travels. The player's move comes from `Walker.ahead`. The drawn box is moved and scaled the way the camera move shifts the `anchor` (where the thing stands, in fine units like `Npc.local_x`, with `height` the height of the reference point, `ANCHOR_HEIGHT` by default). When nothing is drawn yet, a box of `size` tiles around the anchor is used instead.

`hover`, `click`, `interact` and `approach` ask for the box `Mouse.travel_ms` plus `WALK_REACTION_MS` ahead while the player has a destination. They pick a spot that is still inside it `WALK_HOLD_MS` later, so it's still under the mouse while the hover is checked and the click goes in. Without a destination `WALK_LEAD_MS` is used as the guess. While walking, `interact` tries again (up to `MISCLICK_ATTEMPTS`) when the option slid away before the click.

Example:
```luau
local Clickbox = require("../main/clickbox")
local Npcs = require("../main/entities/npcs")

local aim = Clickbox.walking(function()
	return Npcs.clickbox(npc)
end, function()
	return { x = npc.local_x, y = npc.local_y }
end, npc.name)
local now = aim()
local soon = aim(300)
```

## Clickbox.approach

Definition:
```luau
function Clickbox.approach(
	clickbox: Aim,
	hovered: () -> boolean,
	what: string,
	option: string | { string },
	target: Minimenu.Target?,
	tile: () -> Tile?,
	opts: Approach?
): boolean
```
Walks to the thing and picks `options` on it (see `Clickbox.interact`), so the player doesn't have to stand near it first. Before the walk the camera turns so the thing shows in the upper half of the screen (`Camera.face`). The walk ends `near` tiles away, where the pick happens as `interact` does. While walking, within `early_range` tiles, the thing may be picked straight away (`early_chance`, rolled once, then tried again every `EARLY_RETRY_MS` while it isn't on screen): the client walks the player there and does the option on arrival. Returns once they've arrived (`arrive_ms`), or right after the pick with `arrive_ms` false. `walk.on_step` or `walk.before_click` returning false stops the walk, and this returns false.

Example:
```luau
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local npc = assert(Npcs.nearest("Ferryman Nathwood", assert(Walker.position())))
-- picks Examine as soon as it can, or walks next to the ferryman and picks it there
local ok = Npcs.approach(npc, { "Examine" }, { early_chance = 0.5, arrive_ms = false })
print(ok)
```
