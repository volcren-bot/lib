# Host

The functions the game client gives to every script: reading what is on screen, moving the mouse, typing, drawing on top of the game and waiting. Everything else in `lib` is built on top of these.

Almost every function returns two values: the result, and an error message. When something goes wrong the result is `nil` and the second value tells you why.

```luau
local Host = require("../host")
```

## Types

The data the functions below hand back. Each one is a plain table, so you read it with `value.field`.

| Type | What it holds |
| --- | --- |
| `ClientState` | The player's position, name, skills, run energy, weight, camera, minimap zoom and walking destination. Any field can be `nil` when it is not known yet (for example before logging in). |
| `PositionData` | A tile (`x`, `y`) and its `plane` (0 is the ground floor; `nil` if it can't be read), plus the tile inside the loaded area (`local_x`, `local_y`). |
| `Skill` | `name`, boosted `level`, `real_level` and `xp`. |
| `LoginLayout` | Where the login screen's parts are drawn. |
| `CameraState` | Camera position, `pitch`, `yaw`, focal point and `zoom`. Positions are in 128ths of a tile. Angles go 0 to 16383 for a full turn. |
| `MinimapState` | The minimap's `zoom` (pixels per tile, 2 to 8). |
| `Connection` | Client `version`, `protocol`, window `width`/`height` and the mouse position. |
| `Widget` | One interface element: position, size, text, sprite, whether it is hidden and its scroll values. |
| `ItemSlot` | One slot of an item container: `slot`, item `id` and `quantity`. |
| `Npc` / `PlayerInfo` | A character near you: `index`, `name`, world tile and local tile. An NPC also has `animation`, the id of the animation it is playing (-1 for none). |
| `NpcModel` | The outline of a character or object as drawn this frame (box corners, outline and triangles). |
| `Collision` | Part of the scene's collision map (`Host.collision`): its corner `x`, `y`, `width`, `height`, `plane` and the `flags` of each tile. |
| `CacheLoc` | A world object as the game cache places it on the map (`name`, `x`, `y`, `plane`, `size_x`, `size_y`, `shape`, `rotation`, `actions`), loaded or not. |
| `CacheLocFilter` | What `Host.cache_locs` keeps: a `plane`, `names` (part of the name) and `actions` (whole menu options). |
| `Loc` | A world object (door, tree, wall...) with its tile, size, shape and whether it can be clicked. |
| `GroundItem` | An item lying on the ground. |
| `Projectile` | A projectile in flight: its graphic `id`, the tiles and actors it flies between, its start and end `cycle`s and where it is now (see [Projectiles](main/entities/projectiles.md)). |
| `SpotAnim` | A spot animation (RuneLite's graphics object) on a tile: its graphic `id`, world tile and `plane`, and when it starts (see [Spot animations](main/entities/spot_anims.md)). |
| `ChatMessage` | A message of the chat history as the game keeps it: `uid` (counts up), `kind` (the message type), `name` (who said it, with icon tags), `sender` (the channel it came from), `text`, when it was added (`time` in ms since 1970, `age` in ms ago, `cycle`) and the game's own `time_utc`/`time_local` ("HH:MM"). |
| `MenuEntry` / `MenuClick` | A right-click menu line, and the line the client last acted on. A line of an open menu has `submenu = true` when it opens a submenu. |
| `MenuLayout` / `MenuSubmenu` / `MenuRect` | The open right-click menu and its open submenus as the client lays them out (see `Host.menu_layout`). |
| `SelectedWidget` | What waits for a target, like a selected spell: its `verb` ("Cast"), `name`, component (`id`, `group`, `child`, `index`), `item` and `targets` (what it can be used on: 1 ground items, 2 NPCs, 4 objects, 8 players, 16 yourself, 32 interface components; add them up). |
| `EnumDef` / `CacheValue` | A table of keys and values from the game files, and one of its values (a number or a string). |
| `SubInterface` | An interface opened inside another one. |
| `World` / `WorldSelect` | The world list and the world switcher's state. |
| `Tile` / `Area` / `Corners` / `ScreenPoint` / `FinePoint` | Small helper shapes for coordinates. |
| `Shape` | One shape for `Host.draw_batch`: a rect, a line or a clear. |
| `FormSpec` / `FormField` | The description of a settings window. |
| `WindMouseOptions` | Tuning for human-like mouse movement. |

## Host.game_state

Definition:
```luau
Host.game_state: () -> ClientState
```
Reads a snapshot of the player and the client. This is the most used function: login state, position, skills, camera and more all come from here. It always returns a table, like `Host.connection`, and raises if the client or the agent is gone. Fields such as `position` or `camera` are nil when they aren't known (for example when logged out).

Example:
```luau
local Host = require("../host")

local state = Host.game_state()
if state.position then
	print("standing at", state.position.x, state.position.y)
end
```

## Host.connection

Definition:
```luau
Host.connection: () -> Connection
```
Tells you about the connection to the client: its version, the window size and where the mouse is. It never returns nil: `injector run` refuses to start if the agent isn't loaded or runs a different protocol, and the call raises an error if the client or the agent goes away mid-run.

Example:
```luau
local Host = require("../host")

local info = Host.connection()
print(`client {info.version}, window {info.width}x{info.height}`)
```

## Host.widget

Definition:
```luau
Host.widget: (group: number, child: number) -> Widget?
```
Looks up one interface element by its group and child number.

Example:
```luau
local Host = require("../host")

local w = Host.widget(149, 0)
if w then
	print("inventory at", w.x, w.y, w.width, w.height)
end
```

## Host.widget_children

Definition:
```luau
Host.widget_children: (group: number, child: number) -> { Widget }?
```
Gets all the elements inside one interface element (for example every slot of a panel).

Example:
```luau
local Host = require("../host")

local children = Host.widget_children(149, 0)
print("children:", if children then #children else 0)
```

## Host.item_container

Definition:
```luau
Host.item_container: (id: number) -> { ItemSlot }?
```
Lists what is in an item container such as the inventory (`93`), worn items (`94`) or the bank (`95`).

Example:
```luau
local Host = require("../host")

local slots = Host.item_container(93)
for _, slot in ipairs(slots or {}) do
	print(slot.slot, slot.id, slot.quantity)
end
```

## Host.on_item_change

Definition:
```luau
Host.on_item_change: (callback: (change: ItemChange) -> ()) -> number
```
Calls `callback` for every change the client makes to an item container slot (inventory `93`, worn items `94`, bank `95`, ...), from now on. The change has `container`, `slot`, `tick`, `old_item`, `old_quantity`, `new_item`, `new_quantity` (an empty slot is item `-1`) and `old_known`, false when the write created the container. Returns an id for `Host.off_item_change`.

The client tells the script the moment it makes the change, but a script is one thread: the callbacks run inside `Host.sleep` and `Host.wait_item_change`, waking them early, and not while the script is busy elsewhere. A script that never sleeps never sees a callback. An error in a callback ends the script like any other. The changes of one game tick arrive together, a bank opening is a few hundred.

Example:
```luau
local Host = require("../host")

Host.on_item_change(function(change)
	if change.container == 93 and change.new_item ~= change.old_item then
		print(`inventory slot {change.slot}: {change.old_item} -> {change.new_item} (tick {change.tick})`)
	end
end)
while true do
	Host.sleep(1000) -- callbacks run while this sleeps
end
```

## Host.off_item_change

Definition:
```luau
Host.off_item_change: (id: number) -> boolean
```
Stops calling the callback `Host.on_item_change` returned `id` for. Returns whether there was one.

## Host.wait_item_change

Definition:
```luau
Host.wait_item_change: (ms: number) -> boolean
```
Waits up to `ms` for the client to change an item container, runs the callbacks for what it changed and returns true; false when nothing changed in that time. Needs a callback from `Host.on_item_change` (without one it only sleeps).

Example:
```luau
local Host = require("../host")

Host.on_item_change(function() end)
if Host.wait_item_change(30000) then
	print("something changed")
end
```

## Host.project

Definition:
```luau
Host.project: (
	points: { FinePoint },
	via: ("auto" | "local" | "client")?,
	shift: { x: number, y: number }?
) -> { ScreenPoint }?
```
Turns points in the game world into points on your screen. `via` picks how it is calculated; leave it out unless you have a reason. `shift` (whole fine units) projects them as the camera will show them once the player has walked that far: the camera is moved by it, and up or down with the ground under the player. Only the local calculation can do this, so `via = "client"` with a `shift` is an error.

Example:
```luau
local Host = require("../host")

local state = Host.game_state()
if state and state.camera then
	local points = Host.project({ { x = state.camera.focal_x, y = state.camera.focal_y } })
	print(points and points[1].x, points and points[1].y)
end
```

## Host.form

Definition:
```luau
Host.form: (spec: FormSpec) -> { [string]: any }?
```
Shows a settings window and waits until the user presses the button. Returns the chosen values by field id, or `nil, "cancelled"`. Field kinds are `label`, `check`, `number`, `text` and `choice`.

Example:
```luau
local Host = require("../host")

local values = Host.form({
	title = "My script",
	submit = "Start",
	fields = {
		{ id = "name", kind = "text", label = "Name", default = "Bob" },
		{ id = "loops", kind = "number", label = "Loops", default = 5, min = 1, max = 100, integer = true },
		{ id = "fast", kind = "check", label = "Go fast", default = false },
	},
})
if values == nil then
	print("closed")
	return
end
print(values.name, values.loops, values.fast)
```

## Host.menu

Definition:
```luau
Host.menu: () -> { MenuEntry }?
```
Lists the lines of the right-click menu. While it's open, they're the rows it shows, top to bottom, as the client draws them: entries the client hides (other players' followers, say) aren't listed, and `submenu` is `true` on lines that open a submenu. While it's closed, they're what hovering shows, the first being what a left click does. The lines of open submenus are in `Host.menu_layout().submenus`.

Example:
```luau
local Host = require("../host")

for _, entry in ipairs(Host.menu() or {}) do
	print(entry.option, entry.target)
end
```

## Host.menu_click

Definition:
```luau
Host.menu_click: () -> MenuClick?
```
Returns the menu line the client last acted on and where the mouse was. Returns `nil` without an error when this is not available.

Example:
```luau
local Host = require("../host")

local click = Host.menu_click()
if click then
	print(click.entry.option, click.entry.target, "frames ago:", click.age)
end
```

## Host.selected_widget

Definition:
```luau
Host.selected_widget: () -> SelectedWidget?
```
What is waiting for something to be used on, like a spell you clicked that now needs a target. Returns `nil` without an error when nothing is selected. See [Magic](main/interfaces/gametabs/magic.md) for spells.

Example:
```luau
local Host = require("../host")

local selected = Host.selected_widget()
if selected then
	print(selected.verb, selected.name, "on component", selected.group, selected.child)
end
```

## Host.sub_interfaces

Definition:
```luau
Host.sub_interfaces: () -> { SubInterface }?
```
Lists the interfaces currently open inside other interfaces.

Example:
```luau
local Host = require("../host")

for _, sub in ipairs(Host.sub_interfaces() or {}) do
	print(sub.group, "inside", sub.parent_group)
end
```

## Host.game_val_name

Definition:
```luau
Host.game_val_name: (kind: number, id: number) -> string?
```
Looks up the readable name of a game value (an object, NPC, interface...) from its number.

Example:
```luau
local Host = require("../host")

print(Host.game_val_name(0, 1))
```

## Host.game_val_names

Definition:
```luau
Host.game_val_names: (kind: number, ids: { number }) -> { string? }?
```
Same as `game_val_name`, but for many numbers at once.

Example:
```luau
local Host = require("../host")

local names = Host.game_val_names(0, { 1, 2, 3 })
print(names and #names)
```

## Host.item_name

Definition:
```luau
Host.item_name: (id: number) -> string?
```
Returns an item's name from its id.

Example:
```luau
local Host = require("../host")

print(Host.item_name(995))
```

## Host.item_names

Definition:
```luau
Host.item_names: (ids: { number }) -> { string? }?
```
Same as `item_name`, but for many items at once.

Example:
```luau
local Host = require("../host")

local names = Host.item_names({ 995, 554 })
print(names and names[1], names and names[2])
```

## Host.varc

Definition:
```luau
Host.varc: (id: number) -> number?
```
Reads one client setting value (a "varc").

Example:
```luau
local Host = require("../host")

print("zoom setting:", Host.varc(74))
```

## Host.varp

Definition:
```luau
Host.varp: (id: number) -> number?
```
Reads one saved game setting value (a "varp"). See [Varps](main/varps.md) for named ids.

Example:
```luau
local Host = require("../host")

print("run toggle:", Host.varp(173))
```

## Host.varps

Definition:
```luau
Host.varps: () -> { number }?
```
Reads every game setting at once. The list is 1-based: id `n` is at position `n + 1`.

Example:
```luau
local Host = require("../host")

local all = Host.varps()
print("settings:", all and #all)
```

## Host.varbit

Definition:
```luau
Host.varbit: (id: number) -> number?
```
Reads a "varbit": a few bits of a game setting. Which setting and which bits are read from the game files once per script. See [Varbits](main/varbits.md) for named ids.

Example:
```luau
local Host = require("../host")

print("spellbook:", Host.varbit(4070))
```

## Host.enum_def

Definition:
```luau
Host.enum_def: (id: number) -> EnumDef?
```
Reads a table of keys and values (an "enum") from the game files. Returns `nil` without an error when there is no such enum.

Example:
```luau
local Host = require("../host")

local books = Host.enum_def(1981)
for _, entry in ipairs(books and books.entries or {}) do
	print(entry.key, entry.value)
end
```

## Host.item_params

Definition:
```luau
Host.item_params: (ids: { number }) -> { { [number]: CacheValue }? }?
```
Reads the extra values ("params") the game files keep for each item, by param number. An item the game files don't have is `nil` in the list.

Example:
```luau
local Host = require("../host")

local params = Host.item_params({ 3281 })
print(params and params[1] and params[1][601]) -- Wind Bolt
```

## Host.npcs

Definition:
```luau
Host.npcs: () -> { Npc }?
```
Lists the NPCs currently loaded around you.

Example:
```luau
local Host = require("../host")

for _, npc in ipairs(Host.npcs() or {}) do
	print(npc.name, npc.x, npc.y)
end
```

## Host.npc_model

Definition:
```luau
Host.npc_model: (index: number) -> NpcModel?
```
Returns the on-screen outline of one NPC (by its `index`).

Example:
```luau
local Host = require("../host")

local npcs = Host.npcs() or {}
if npcs[1] then
	local model = Host.npc_model(npcs[1].index)
	print(model and #model.hull)
end
```

## Host.npc_sizes

Definition:
```luau
Host.npc_sizes: (indices: { number }) -> { [number]: number }?
```
The size in tiles (the side of the square it stands on) of the NPCs with these `index`es, from their definitions, keyed by index. NPCs that are gone are left out. [SafeSpot](main/safespot.md) needs them: an NPC paths from its south-west tile, and its position is drawn in the middle of its tiles.

Example:
```luau
local Host = require("../host")

local all = Host.npcs() or {}
local indices = {}
for _, npc in ipairs(all) do
	table.insert(indices, npc.index)
end
local sizes = Host.npc_sizes(indices) or {}
for _, npc in ipairs(all) do
	print(npc.name, sizes[npc.index])
end
```

## Host.npc_hitsplats

Definition:
```luau
Host.npc_hitsplats: (indices: { number }) -> { [number]: { Hitsplat } }?
```
The hitsplats on the NPCs with these `index`es, keyed by index; the NPCs that are gone are left out. An NPC shows at most its last four, for about a second and a half, and a new hit replaces the oldest, so read them at least once a tick to see every hit. Each one has its `slot` (0 to 3, it keeps it until replaced), its `kind` (the splat type: 16 for damage, 12 for a block), the `damage` it shows and the client `cycle` it was added on, which tells hits apart. [NpcHealth](main/entities/npc_health.md) works the health of NPCs out from them.

Example:
```luau
local Host = require("../host")

local all = Host.npcs() or {}
local indices = {}
for _, npc in ipairs(all) do
	table.insert(indices, npc.index)
end
local splats = Host.npc_hitsplats(indices) or {}
for _, npc in ipairs(all) do
	for _, splat in ipairs(splats[npc.index] or {}) do
		print(npc.name, splat.damage, splat.cycle)
	end
end
```

## Host.locs

Definition:
```luau
Host.locs: (plane: number?) -> { Loc }?
```
Lists the world objects (doors, trees, walls...) of the loaded scene on a plane (0 to 3, yours by default). `shape` and `rotation` are known for every kind (walls included). `clickable` is the client's own flag for an object you can click; it is also what makes the minimap draw a wall red, so a clickable wall is a door, gate or curtain.

Example:
```luau
local Host = require("../host")

for _, loc in ipairs(Host.locs() or {}) do
	if loc.name == "Bank booth" then
		print("bank booth at", loc.x, loc.y)
	end
end
```

## Host.cache_locs

Definition:
```luau
Host.cache_locs: (area: Corners, filter: CacheLocFilter?) -> { CacheLoc }?
```
Lists the world objects the game cache places on the map inside an area (`x1`, `y1`, `x2`, `y2`, both corners included), on every plane, whether or not that part of the map is loaded: where `Host.locs` only has your floor of the loaded scene. Each one has its name and menu `actions`. The filter keeps the objects on a `plane`, with any of the `names` in their name (any case) and any of the `actions` as a whole option (any case). The area covers at most 64 map squares (64 x 64 tiles each). It is what the cache says about the map: not what changed since (doors that are open, objects that came or went), and objects that transform into others (by a varbit) show as their first form. An 80 x 80 tile area takes about 50 ms.

Example:
```luau
local Host = require("../host")

local me = Host.game_state().position
if me then
	local stairs = Host.cache_locs(
		{ x1 = me.x - 40, y1 = me.y - 40, x2 = me.x + 40, y2 = me.y + 40 },
		{ actions = { "Climb-up", "Climb-down" } }
	)
	for _, loc in ipairs(stairs or {}) do
		print(loc.name, loc.x, loc.y, "plane", loc.plane, table.concat(loc.actions, ", "))
	end
end
```

## Host.loc_model

Definition:
```luau
Host.loc_model: (loc: Loc) -> NpcModel?
```
Returns the on-screen outline of a world object.

Example:
```luau
local Host = require("../host")

local locs = Host.locs() or {}
if locs[1] then
	print(Host.loc_model(locs[1]))
end
```

## Host.ground_items

Definition:
```luau
Host.ground_items: () -> { GroundItem }?
```
Lists the items lying on the ground on your floor.

Example:
```luau
local Host = require("../host")

for _, item in ipairs(Host.ground_items() or {}) do
	print(item.name, item.quantity, item.x, item.y)
end
```

## Host.projectiles

Definition:
```luau
Host.projectiles: () -> { Projectile }?
```
Lists the projectiles in flight, and the ones the server sent that haven't left yet. `Main.Entities.Projectiles` has the helpers.

Example:
```luau
local Host = require("../host")

for _, p in ipairs(Host.projectiles() or {}) do
	print(p.id, p.x, p.y, p.height, p.end_cycle - p.cycle)
end
```

## Host.spot_anims

Definition:
```luau
Host.spot_anims: () -> { SpotAnim }?
```
Lists the spot animations on tiles in your scene: the ones the server placed with a position, like impacts and splashes. Effects on a character (a teleport flash on you, a freeze on an NPC) are not here; those are the `graphic` of that `Npc` or `PlayerInfo`. `Main.Entities.SpotAnims` has the helpers.

Example:
```luau
local Host = require("../host")

for _, s in ipairs(Host.spot_anims() or {}) do
	print(s.id, s.x, s.y, s.plane)
end
```

## Host.map_regions

Definition:
```luau
Host.map_regions: () -> { { number } }?
```
The map squares (64x64 tiles) the loaded scene is built from, each as `{ x, y }` (a tile's coordinates divided by 64). Outdoors they are the squares around you; in an instance they are the source squares the server copied. `Player.map_chunks` wraps this.

Example:
```luau
local Host = require("../host")

for _, region in ipairs(Host.map_regions() or {}) do
	print(region[1], region[2])
end
```

## Host.in_instance

Definition:
```luau
Host.in_instance: () -> boolean?
```
The game client's own flag for "the loaded scene is an instance". `nil` when it can't be read (logged out, or an agent without the flag). `Player.in_instance` wraps this.

Example:
```luau
local Host = require("../host")

print(Host.in_instance())
```

## Host.chat_messages

Definition:
```luau
Host.chat_messages: () -> { ChatMessage }?
```
Lists the chat history, oldest first. The game keeps up to 100 messages of each type, including the ones the chat's tabs and filters hide, and the lines of the dialogues you go through. It's read from the game, not from the screen, so it works with the chatbox closed or covered. `time` is worked out from the game's clock, which ticks every 20 ms, so it's precise to the second; `time_utc` and `time_local` are the "HH:MM" stamps the game shows when chat timestamps are on. Use `Chat.messages` for the same list cleaned up.

Example:
```luau
local Host = require("../host")

for _, m in ipairs(Host.chat_messages() or {}) do
	print(m.time_utc, m.kind, m.name, m.text)
end
```

## Host.players

Definition:
```luau
Host.players: () -> { PlayerInfo }?
```
Lists the other players loaded around you.

Example:
```luau
local Host = require("../host")

for _, p in ipairs(Host.players() or {}) do
	print(p.name, p.x, p.y)
end
```

## Host.player_model

Definition:
```luau
Host.player_model: (index: number) -> NpcModel?
```
Returns the on-screen outline of a player.

Example:
```luau
local Host = require("../host")

local players = Host.players() or {}
if players[1] then
	print(Host.player_model(players[1].index))
end
```

## Host.find_path

Definition:
```luau
Host.find_path: (from: Tile, to: Tile, plane: number?, max_tiles: number?) -> { Tile }?
```
Finds a walking route between two tiles of a plane (yours by default), both included. It knows the walls and blocked tiles of the whole map, but not stairs or other shortcuts, and it takes closed doors for walls. `max_tiles` limits how many tiles the search looks at: a target that can't be reached otherwise makes it search every tile that can be. The first call after a game update takes about ten seconds while the map is prepared.

Example:
```luau
local Host = require("../host")

local state = Host.game_state()
local me = state and state.position
if me then
	local path = Host.find_path({ x = me.x, y = me.y }, { x = me.x + 10, y = me.y })
	print("steps:", path and #path)
end
```

## Host.nav_plan

Definition:
```luau
Host.nav_plan: (from: Tile | NavTile, to: Tile | NavTile, options: NavOptions?) -> NavPlan?
```
Plans a walk over every plane of the loaded scene at once, through closed doors and up and down ladders and staircases; a tile without a `plane` is on yours. It reads the client's collision of all four planes, then:

- **Doors.** A door is what the minimap draws red: a wall (or a diagonal wall) the client lets you click, that blocks, has one of `door_options` and is closed (its walls are in the collision). Its walls are taken out of the collision while planning, at `door_cost` (tenths of a tile) for going through, so a plan uses a door when that is shorter than the way round.
- **Climbs.** Any clickable object with one of `climb_options` (menu option to planes climbed, `1` up and `-1` down) joins the tiles it is used from (beside it, where no wall is between) to the tiles beside the nearest object on the other plane that climbs back (within 6 tiles), at `climb_cost`. Where exactly you land is a guess, so plan again once there.

The plan's `tiles` are every tile walked, start first, each with its plane; `actions` are the doors and climbs on the way, in order, each with the index `at` of the tile it is used from (the next tile is past it). When `to` is outside the loaded scene the plan uses the game cache's collision (closed doors open) for the rest, up to about 400 tiles across; farther than that it plans to a tile along the world path (`goal`), and `reached` is false. A target that can't be reached gives a plan to the closest tile on its plane, with `reached` false. In an instance only the loaded scene is used. All fields are optional:
- `near`: the plan ends this many tiles (any direction) from `to` on its plane (default 0).
- `door_options`: the options that open a door, any case (default `{ "Open" }`; `{}` takes closed doors for walls).
- `climb_options`: default `{ ["Climb-up"] = 1, ["Climb-down"] = -1 }`; `{}` stays on the plane.
- `avoid`: locs not to use (`id`, `x`, `y`, `plane`), such as a door that didn't open.
- `seed`, `rnd`: with a seed every tile's cost is scaled by 1 +- `rnd` / 2, the same seed planning the same way (default `rnd` 0.6).
- `door_cost`, `climb_cost`: default 30 and 50.

Example:
```luau
local Host = require("../host")

local me = Host.game_state().position
if me then
	local plan = Host.nav_plan({ x = me.x, y = me.y }, { x = me.x, y = me.y, plane = 0 })
	for _, action in ipairs(plan and plan.actions or {}) do
		print(action.kind, action.loc.option, action.loc.x, action.loc.y, "plane", action.loc.plane, "to", action.to_plane)
	end
end
```

## Host.scene_route

Definition:
```luau
Host.scene_route: (from: Tile, to: Tile, options: SceneRouteOptions?) -> SceneRoute?
```
The route the game walks when you click `to` while standing on `from`: every tile of it, the start first. It uses the game's own route finder on the area around the player as the game client sees it right now, so it works in instances (minigames, raids) and knows about opened doors. When `to` can't be reached, `reached` is false and the route ends where the game would send you instead: the nearest reachable tile within 10 tiles of `to`. Both tiles must be in the loaded area (about 50 tiles around the player).

Passing `options` (even `{}`) returns a randomized route instead: the game's route always takes the same line, so this lays a sparse lattice of jittered nodes over the walkable tiles of the scene (built from the live collision, cached while the scene doesn't change) and takes the cheapest way over it with noise on each edge. On open ground that picks between whole corridors, and each leg is still a legal walk. Short or unreachable routes, and routes that would be longer than `max_detour` times the game's, are the game's own route.

`to` doesn't have to be in the loaded scene: when it isn't, the route is built over whole map squares around the scene and `to` (up to about 400 tiles across), where the client's own collision is used for the tiles of the scene it shows (and of the last few it showed) and the game cache's collision for the rest. The cache has the terrain and the locs, not what changed since (opened doors, spawned objects, instances), and the outermost 4 tiles of a scene are left to the cache because the client doesn't have all their objects. A `to` that can't be reached inside that area (for example a path that winds out of it), or is farther, gives no route: use `Host.find_path` to get partway there. All fields are optional:
- `seed`: the noise; the same seed is the same route when `offset` is 0 (default: random).
- `rnd`: how much each edge's cost varies, 0.8 means 40% either way (default 0.8).
- `spacing`: the lattice's cell size in tiles (default 8).
- `jitter`: how far from its cell's centre a node can be (default 2).
- `max_detour`: the longest route allowed, as a multiple of the game's (default 1.3).
- `offset`: every call moves the route's lattice nodes by up to this many tiles on each axis (to a standable tile the walk can reach, otherwise the node stays), so two calls with the same seed still differ; 0 turns it off (default 2).

Example:
```luau
local Host = require("../host")

local state = Host.game_state()
local me = state and state.position
if me then
	local route = Host.scene_route({ x = me.x, y = me.y }, { x = me.x + 8, y = me.y - 4 })
	if route then
		print(#route.tiles - 1, "steps, reaches the tile:", route.reached)
	end
end
```

## Host.collision

Definition:
```luau
Host.collision: (area: Corners?) -> Collision?
```
The collision flags the game client keeps for your plane of the loaded scene, as it is now (opened doors, instances, spawned objects): the whole scene, or the part of it inside `area` (corners included). The flags of tile (`x + i`, `y + j`) are at `flags[i * height + j + 1]`; [SafeSpot](main/safespot.md) names them (`SafeSpot.FLAG`) and reads them for you. The scene's outer ring of tiles has every flag set. It takes about 2 ms.

Example:
```luau
local Host = require("../host")

local me = Host.game_state().position
if me then
	local c = Host.collision({ x1 = me.x - 1, y1 = me.y - 1, x2 = me.x + 1, y2 = me.y + 1 })
	if c then
		local north = c.flags[(me.x - c.x) * c.height + (me.y + 1 - c.y) + 1]
		print(string.format("flags north of you: %x", north))
	end
end
```

## Host.world_select

Definition:
```luau
Host.world_select: () -> WorldSelect?
```
Reads the world switcher: whether it is open and the list of worlds.

Example:
```luau
local Host = require("../host")

local ws = Host.world_select()
if ws then
	print("open:", ws.open, "worlds:", #ws.worlds)
end
```

## Host.click

Definition:
```luau
Host.click: (x: number, y: number, button: string?, hold_ms: number?) -> ()
```
Jumps the mouse to a point and clicks it, holding the button for `hold_ms` (60 by default). Prefer [Mouse](utils/input/mouse.md), which moves like a person would.

Example:
```luau
local Host = require("../host")

Host.click(100, 100)
```

## Host.move

Definition:
```luau
Host.move: (x: number, y: number) -> ()
```
Jumps the mouse to a point.

Example:
```luau
local Host = require("../host")

Host.move(200, 150)
```

## Host.wind_mouse

Definition:
```luau
Host.wind_mouse: (x: number, y: number, options: WindMouseOptions?) -> ()
```
Moves the mouse to a point along a curved, human-like path. Optional `speed`, `wind`, `gravity` and `timeout` tune the movement.

Example:
```luau
local Host = require("../host")

Host.wind_mouse(300, 200, { speed = 12 })
```

## Host.mouse_down

Definition:
```luau
Host.mouse_down: (button: string?) -> ()
```
Presses a mouse button and keeps it held.

Example:
```luau
local Host = require("../host")

Host.mouse_down()
Host.sleep(100)
Host.mouse_up()
```

## Host.mouse_up

Definition:
```luau
Host.mouse_up: (button: string?) -> ()
```
Releases a mouse button.

Example:
```luau
local Host = require("../host")

Host.mouse_up()
```

## Host.scroll

Definition:
```luau
Host.scroll: (notches: number) -> ()
```
Turns the mouse wheel by that many notches.

Example:
```luau
local Host = require("../host")

Host.scroll(-3)
```

## Host.key_down

Definition:
```luau
Host.key_down: (key: number) -> ()
```
Presses a keyboard key and keeps it held.

Example:
```luau
local Host = require("../host")

Host.key_down(0x25)
Host.sleep(300)
Host.key_up(0x25)
```

## Host.key_up

Definition:
```luau
Host.key_up: (key: number) -> ()
```
Releases a keyboard key.

Example:
```luau
local Host = require("../host")

Host.key_up(0x25)
```

## Host.type_text

Definition:
```luau
Host.type_text: (text: string, hold_ms: number?) -> ()
```
Types a piece of text, optionally holding each key for `hold_ms`.

Example:
```luau
local Host = require("../host")

Host.type_text("hello")
```

## Async input

`Host.click_async`, `Host.move_async`, `Host.wind_mouse_async` and `Host.type_text_async` take the same arguments as their blocking versions, but queue the input on a thread of its own and return at once, so the script keeps running. Queued input runs in order. It stops, and what was queued is dropped, when the script:

- sends blocking input (`click`, `move`, `wind_mouse`, `mouse_down`, `key_down`, `type_text`, ...);
- calls `Host.input_cancel`;
- reads the open menu with `Host.menu`, `Host.menu_open` or `Host.menu_layout`;
- ends.

A cancelled click still releases its button, a cancelled `type_text` its key and modifiers. A cancelled move leaves the mouse where it stopped. Buttons and keys pressed with `Host.mouse_down_async` and `Host.key_down_async` stay down until released the same way; when the input is cancelled or the script ends they are released, the last pressed first, whether the worker was idle or in the middle of a move or a pause. Prefer [Mouse](utils/input/mouse.md).

## Host.click_async

Definition:
```luau
Host.click_async: (x: number, y: number, button: string?, hold_ms: number?) -> ()
```
Queues a click, like `Host.click`.

Example:
```luau
local Host = require("../host")

Host.click_async(100, 100)
```

## Host.move_async

Definition:
```luau
Host.move_async: (x: number, y: number) -> ()
```
Queues a jump of the mouse, like `Host.move`.

Example:
```luau
local Host = require("../host")

Host.move_async(200, 150)
```

## Host.wind_mouse_async

Definition:
```luau
Host.wind_mouse_async: (x: number, y: number, options: WindMouseOptions?) -> ()
```
Queues a human-like move, like `Host.wind_mouse`. The path starts from where the mouse is when the move begins running.

Example:
```luau
local Host = require("../host")

Host.wind_mouse_async(300, 200, { speed = 12 })
```

## Host.type_text_async

Definition:
```luau
Host.type_text_async: (text: string, hold_ms: number?) -> ()
```
Queues typing, like `Host.type_text`.

Example:
```luau
local Host = require("../host")

Host.type_text_async("hello")
```

## Host.mouse_down_async

Definition:
```luau
Host.mouse_down_async: (button: string?) -> ()
```
Queues pressing a mouse button and keeping it held, like `Host.mouse_down`. Cancelling releases it.

Example:
```luau
local Host = require("../host")

Host.mouse_down_async("middle")
Host.wind_mouse_async(400, 300)
Host.mouse_up_async("middle")
```

## Host.mouse_up_async

Definition:
```luau
Host.mouse_up_async: (button: string?) -> ()
```
Queues releasing a mouse button, like `Host.mouse_up`.

Example:
```luau
local Host = require("../host")

Host.mouse_up_async("middle")
```

## Host.scroll_async

Definition:
```luau
Host.scroll_async: (notches: number) -> ()
```
Queues turning the mouse wheel, like `Host.scroll`.

Example:
```luau
local Host = require("../host")

Host.scroll_async(2)
```

## Host.key_down_async

Definition:
```luau
Host.key_down_async: (key: number) -> ()
```
Queues pressing a key and keeping it held, like `Host.key_down`. Cancelling releases it.

Example:
```luau
local Host = require("../host")

Host.key_down_async(0x25)
Host.sleep_async(300)
Host.key_up_async(0x25)
```

## Host.key_up_async

Definition:
```luau
Host.key_up_async: (key: number) -> ()
```
Queues releasing a key, like `Host.key_up`.

Example:
```luau
local Host = require("../host")

Host.key_up_async(0x25)
```

## Host.sleep_async

Definition:
```luau
Host.sleep_async: (ms: number) -> ()
```
Queues a pause: the inputs queued after it start `ms` milliseconds later. Cancelling cuts it short. Use it to hold a key or a button for a while.

Example:
```luau
local Host = require("../host")

Host.key_down_async(0x25)
Host.sleep_async(300)
Host.key_up_async(0x25)
```

## Host.input_busy

Definition:
```luau
Host.input_busy: () -> boolean
```
Whether async input is running or queued.

Example:
```luau
local Host = require("../host")

Host.move_async(200, 150)
print(Host.input_busy())
```

## Host.input_wait

Definition:
```luau
Host.input_wait: () -> string?
```
Waits until all async input is done. Returns the error of an async input that failed since the last check, or `nil`.

Example:
```luau
local Host = require("../host")

Host.move_async(200, 150)
local error = Host.input_wait()
if error then
	print(error)
end
```

## Host.input_error

Definition:
```luau
Host.input_error: () -> string?
```
Returns, without waiting, the error of an async input that failed since the last check, or `nil`.

Example:
```luau
local Host = require("../host")

local error = Host.input_error()
if error then
	print(error)
end
```

## Host.input_cancel

Definition:
```luau
Host.input_cancel: () -> ()
```
Stops async input and drops what was queued. Returns once nothing is being sent any more.

Example:
```luau
local Host = require("../host")

Host.move_async(200, 150)
Host.input_cancel()
```

## Host.draw_rect

Definition:
```luau
Host.draw_rect: (x1: number, y1: number, x2: number, y2: number, r: number, g: number, b: number, a: number?) -> ()
```
Draws a colored rectangle on top of the game (colors 0 to 255). Handy for seeing what a script is looking at.

Example:
```luau
local Host = require("../host")

Host.draw_rect(50, 50, 150, 100, 255, 0, 0)
```

## Host.draw_line

Definition:
```luau
Host.draw_line: (x1: number, y1: number, x2: number, y2: number, r: number, g: number, b: number, a: number?) -> ()
```
Draws a colored line on top of the game.

Example:
```luau
local Host = require("../host")

Host.draw_line(0, 0, 200, 200, 0, 255, 0)
```

## Host.draw_lines

Definition:
```luau
Host.draw_lines: (lines: { { number } }, r: number, g: number, b: number, a: number?) -> ()
```
Draws many lines of one color in one go. Each line is `{ x1, y1, x2, y2 }`.

Example:
```luau
local Host = require("../host")

Host.draw_lines({ { 0, 0, 100, 0 }, { 100, 0, 100, 100 } }, 255, 255, 0)
```

## Host.clear_overlay

Definition:
```luau
Host.clear_overlay: () -> ()
```
Removes everything you drew on top of the game.

Example:
```luau
local Host = require("../host")

Host.clear_overlay()
```

## Host.draw_batch

Definition:
```luau
Host.draw_batch: (shapes: { Shape }) -> ()
```
Draws a list of shapes, in order, as one update: the game never shows it half drawn, and the overlay is sent to the game once instead of once per shape. A shape is `{ kind = "rect" | "line", x1, y1, x2, y2, r, g, b, a? }`, or `{ kind = "clear" }` to wipe what's there first. `Draw.batch` builds the list for you.

Example:
```luau
local Host = require("../host")

Host.draw_batch({
	{ kind = "clear" },
	{ kind = "rect", x1 = 50, y1 = 50, x2 = 150, y2 = 100, r = 255, g = 0, b = 0 },
	{ kind = "line", x1 = 50, y1 = 50, x2 = 150, y2 = 100, r = 0, g = 255, b = 0 },
})
```

## Host.sleep

Definition:
```luau
Host.sleep: (ms: number) -> ()
```
Pauses the script for that many milliseconds.

Example:
```luau
local Host = require("../host")

Host.sleep(1000)
print("one second later")
```

## Host.time

Definition:
```luau
Host.time: () -> number
```
Milliseconds since the script started. It never goes backwards, so it is good for measuring how long something took.

Example:
```luau
local Host = require("../host")

local start = Host.time()
Host.sleep(500)
print("took", Host.time() - start, "ms")
```

## Host.clock

Definition:
```luau
Host.clock: () -> number
```
Seconds since local midnight on this computer, with the milliseconds as the fraction. Unlike `Host.time`, it's the time of day, so use it to schedule things at a clock time (see `Antiban.add_sleep`).

Example:
```luau
local Host = require("../host")

local now = Host.clock()
print("it's", math.floor(now // 3600), "o'clock")
```


## Host.report_counters

Definition:
```luau
Host.report_counters: (counters: { Counter }) -> ()
```
Tells the loader what the script counts, to show in its XP Tracker tab under the skills. Send the totals since the script started, not the changes; each call replaces the last, so send them again when a number changes. The loader keeps the latest totals and works out the rest against the run's clock, so there's nothing to compute or format.

A counter is `{ id, label, value, hourly?, per?, percent_of? }`:
- `id` is what other counters refer to it by, `label` is what the tab shows, `value` is the total.
- It's shown per hour of the run unless `hourly` is `false`.
- `per` is the `id` of another counter to divide by, shown as "750 per Games".
- `percent_of` is the `id` of a counter this is a share of, shown as "75% of Games".

Works in any run, and needs no store session. Values must be finite numbers.

Example:
```luau
local Host = require("../host")

Host.report_counters({
	{ id = "games", label = "Games", value = 12 },
	{ id = "wins", label = "Wins", value = 9, percent_of = "games" },
	{ id = "points", label = "Points", value = 9000, per = "games" },
})
```

## Host.report_breaks

Definition:
```luau
Host.report_breaks: (plan: BreakPlan) -> ()
```
Shows the breaks and sleeps the script has scheduled in the loader's Breaks tab. Every time is in milliseconds, and the loader counts the times down itself, so send the plan when it changes, not every second. `breaks` and `sleeps` hold `{ remaining, length, at? }` (`at` is the time of day of a sleep, in seconds since local midnight), and `active` says which one is being taken right now and how long is left of it. `Antiban` sends this for you. Works in any run, and needs no store session.

Example:
```luau
local Host = require("../host")

Host.report_breaks({
	breaks = { { remaining = 600000, length = 120000 } },
	sleeps = {},
})
```

## Host.report_stats

Definition:
```luau
Host.report_stats: (experience: number, gold: number, custom: { number }?) -> ()
```
Tells Volcren what the script gained since the last call. The loader adds these up and sends them with its next heartbeat, and they end up in the script's and your own totals on the website. Experience must be 0 or more, gold can be negative, and `custom` holds the gains of the script's custom trackers in order. Numbers are rounded to whole numbers.

Send gains, not totals, and not too often: once a minute is plenty. `Utils.StatsReport` does the bookkeeping for you. The time the script has run is measured by the loader, you can't report it. Each script has limits per minute of runtime, and a report outside them is refused, so don't send made up numbers. Outside a store run (a script run from the editor) the numbers are dropped.

Example:
```luau
local Host = require("../host")

Host.report_stats(1250, 0)
```

## Host.menu_open

Definition:
```luau
Host.menu_open: () -> boolean
```
Whether the client's choose-option menu is open. Returns an error when the agent doesn't know where the client keeps the flag (the menu's open field is found from the client's exe when it loads).

Example:
```luau
local Host = require("../host")

print(Host.menu_open())
```

## Host.menu_layout

Definition:
```luau
Host.menu_layout: () -> MenuLayout?
```
The open right-click menu exactly as the client lays it out, in interface units (multiply by `game_state().ui_scale` for client pixels): `x`, `y`, `width`, `height` of the whole menu, `rows` (the area its lines are drawn in, as `x`, `y`, `width`, `height`), `header_height`, `row_height`, `scroll`, how far the lines are scrolled up (interface units) when the menu is too tall for the client, and `margin`, how far outside the menu the mouse may go before the client closes it (the client rounds the mouse to interface units and counts the edges as inside). The agent runs the client's own layout routine, the one it draws the menu with, so it's right for any number of lines and when the menu is pushed in from the client's edges. Returns `nil` without an error when the menu is closed. `Minimenu.bounds` and `Minimenu.row` are built on it.

`submenus` lists the open submenus, the one opened from the menu first (the client nests them up to 4 deep). Each has the same layout fields, plus `row`, the line of the menu above it that opened it (1 for the top line), and `entries`, its lines top to bottom. The menu stays open while the mouse is near any of them.

Example:
```luau
local Host = require("../host")

local menu = Host.menu_layout()
if menu then
	print(menu.x, menu.y, menu.width, menu.height, "lines from", menu.rows.y)
	for _, sub in ipairs(menu.submenus) do
		print("submenu of line", sub.row, "at", sub.x, sub.y, "with", #sub.entries, "lines")
	end
end
```
