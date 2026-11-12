# Host

The functions the game client gives to every script: reading what is on screen, moving the mouse, typing, drawing on top of the game and waiting. Everything else in `lib` is built on top of these.

Almost every function returns two values: the result, and an error message. When something goes wrong the result is `nil` and the second value tells you why.

```luau
local Host = require("@lib/host")
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
| `LayoutItem` | An item of an equipment or inventory layout (host API 15): `id`, every id that counts as it (`ids`), `name`, `stackable`, a stack's range `min` to `max` (equal: exactly that many, both 0: any amount), `doses` for a dose or charge item (the numbers that count, in the order the bank takes them, or nil) and `locked` for one of the script's `required` items. See [LayoutItem](main/layout_item.md). |
| `EquipmentLayout` / `EquipmentLayoutSlot` / `EquipmentSpell` | What an `equipment` form field gives: a layout's name, every worn items slot (and 14, the secondary ammo) with its `mode` (`item`, `empty` or `any`) and a `LayoutItem`'s fields when it wants an item, and its `spell` (`key`, `name`, `book`, `level`, `autocast`) when one was picked. See [EquipmentLayout](main/equipment_layout.md). |
| `PrayerLayout` | What a `prayer` form field gives: a layout's name, its prayers by key in the prayer book's order, and `locked`, the prayers the script controls (host API 15). See [PrayerLayout](main/prayer_layout.md). |
| `InventoryLayout` / `InventoryLayoutSlot` | What an `inventory` form field gives: a layout's name, its filled slots (a `LayoutItem` with its `slot`) and the rune pouch's runes (`pouch`, each a `LayoutItem`) when it holds a pouch. See [InventoryLayout](main/inventory_layout.md). |
| `LayoutRequirement` | An item of a layout field's `required` list (host API 15): `ids`, `slot` (needed for equipment), `min`, `max` and `doses`. |
| `WindMouseOptions` | Tuning for human-like mouse movement. |
| `HttpRequest` / `HttpResponse` | What `Host.http_request` takes and returns. |
| `ItemPrice` | A Grand Exchange item's prices and values (`Host.item_prices`): `id`, `name`, `members`, `value`, `high_alch`, `low_alch`, buy `limit`, and the latest instant-buy `high` and instant-sell `low` with their Unix times `high_time` and `low_time`. |

## Host.game_state

Definition:
```luau
Host.game_state: () -> ClientState
```
Reads a snapshot of the player and the client. This is the most used function: login state, position, skills, camera and more all come from here. It always returns a table, like `Host.connection`, and raises if the client or the agent is gone. Fields such as `position` or `camera` are nil when they aren't known (for example when logged out).

Example:
```luau
local Host = require("@lib/host")

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
local Host = require("@lib/host")

local info = Host.connection()
print(`client {info.version}, window {info.width}x{info.height}`)
```

## Host.widget

Definition:
```luau
Host.widget: (group: number, child: number) -> Widget?
```
Looks up one interface element by its group and child number. Besides its place, size and look, a widget has `item_id` and `item_quantity` (`HOST_API` 16): the item a cell shows (an inventory or bank slot; -1 for none) and how many. A bank placeholder shows quantity 0 there, while its slot in the bank's item container reads 1.

Example:
```luau
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

Host.on_item_change(function() end)
if Host.wait_item_change(30000) then
	print("something changed")
end
```

## Host.on_packet

Definition:
```luau
Host.on_packet: (opcodes: { number }, callback: (packet: Packet) -> (), sent: boolean?) -> number
```
Calls `callback` for every packet the client receives from the server whose id is in `opcodes`, from now on; with `sent` true, for the packets the client sends instead (client packet ids). Ids go from 0 to 255. The packet has `opcode`, `sent`, `length` (the whole payload), `payload` (a string of its first 104 bytes, read with `string.byte` or `buffer.fromstring`), `time_ms` and `sequence`. Returns an id for `Host.off_packet`.

Like item change callbacks, they run inside `Host.sleep`, `Host.wait_item_change` and `Host.wait_packet`, not while the script is busy elsewhere. The client keeps the last 4096 packets, a few seconds of a busy area, so a script that doesn't sleep for longer than that misses some. Server packet 2 has no payload and arrives once per game tick.

Example:
```luau
local Host = require("@lib/host")

local ticks = 0
Host.on_packet({ 2 }, function()
	ticks += 1
end)
Host.sleep(6000)
print(`{ticks} ticks in 6 seconds`) -- about 10
```

## Host.off_packet

Definition:
```luau
Host.off_packet: (id: number) -> boolean
```
Stops calling the callback `Host.on_packet` returned `id` for. Returns whether there was one.

## Host.wait_packet

Definition:
```luau
Host.wait_packet: (opcodes: { number }, ms: number, sent: boolean?) -> Packet?
```
Waits up to `ms` for the client to receive a packet whose id is in `opcodes` (with `sent` true, to send one), and returns it; `nil` when none came in that time. Only a packet that arrives after the call counts. Needs no callback, and runs the item and packet callbacks while it waits.

Example:
```luau
local Host = require("@lib/host")

-- wait for the next game tick
if Host.wait_packet({ 2 }, 1200) then
	print("new tick")
end
```

## Host.project

Definition:
```luau
Host.project: (
	points: { FinePoint },
	via: ("auto" | "local" | "client")?,
	shift: { x: number, y: number, plane: number? }?
) -> { ScreenPoint }?
```
Turns points in the game world into points on your screen. `via` picks how it is calculated; leave it out unless you have a reason. `shift` (whole fine units) projects them as the camera will show them once the player has walked that far: the camera is moved by it, and up or down with the ground under the player. Give the `plane` the player will stand on when it differs from yours (a climb or a drop): the camera then rises or sinks with the ground of that floor, not of yours. Only the local calculation can do this, so `via = "client"` with a `shift` is an error.

Example:
```luau
local Host = require("@lib/host")

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
Shows a settings window and waits until the user presses the button. Returns the chosen values by field id, or `nil, "cancelled"`. The `title` isn't shown: the loader already shows the script's name, and keeps the remembered values and layouts per title, so give each script its own. Field kinds are `label`, `check`, `number`, `text`, `choice`, `list` (a scrolling list of ticked rows, `items = { { id = "a", label = "A", default = true } }`, giving `{ a = true }`), `equipment`, `inventory` and `prayer`. The last three (host API 10) add an Equipment, Inventory or Prayer tab to the script's page in the loader, where the user reads layouts from the client, edits them (the range of a stack, the doses or charges that count for an item such as a potion and which are taken first, what an empty equipment slot means, the inventory's order; prayers are clicked together in the prayer book, which keeps out the ones that can't be on at once) and keeps them per script; the field shows a dropdown of those layouts and its value is the chosen one, an `EquipmentLayout`, `InventoryLayout` or `PrayerLayout`, or `nil` when none is chosen. An `equipment` or `inventory` field can set `required`, a list of `LayoutRequirement`s (`{ ids = { 2434 }, slot = 0, doses = { 4, 3 } }`; host API 15), items every layout holds, padlocked in the loader so the user can move but not remove or change them; and a `prayer` field can set `locked`, prayer keys the script controls itself, padlocked with every prayer they can't be on with and left out of the layouts. [EquipmentLayout](main/equipment_layout.md), [InventoryLayout](main/inventory_layout.md) and [PrayerLayout](main/prayer_layout.md) act on them. Any field can set `enabled_by` to the id of a check, and is greyed out while that check is off, or `disabled_by`, to be greyed out while it is on; a loader older than `disabled_by` leaves the field usable. Fields next to each other in the list that set the same `row` name share a line, left to right, each as wide as it needs and the form's `row_gap` points apart (24 when it sets none, at most 500), and are stacked again while the line doesn't fit the window; a loader older than this option stacks them. A `number` field can set `box_first = true` to show its edit box before its label. A `label` can set `heading = 1` to show as a title, or `2` as a section heading, to group the fields under it. A field can also set `visible_when = { id = "collect", equals = "Eclipse red" }` (`equals` may be a list of values) to be shown only while the field `id` has that value; `visible_when` may also be a list of such rules, all of which must hold; a hidden field keeps its value and is still returned.

Example:
```luau
local Host = require("@lib/host")

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

## Host.form_update

Definition:
```luau
Host.form_update: () -> { [string]: any }?
```
Returns the values the user changed the settings to since the last call, or `nil` when there is nothing new. After the user presses the form's button the settings stay on the script's page in the loader and the button becomes Update, which sends the changed values to the running script. They have the same shape as what `Host.form` returned; poll this in the main loop and replace your settings with the result when it isn't `nil`. Needs host API 8.

```luau
local values = Host.form({ title = "My script", fields = { { id = "fast", kind = "check", label = "Go fast" } } })
while true do
	local new = Host.form_update()
	if new then
		values = new
	end
	-- ...use values.fast
	Host.sleep(100)
end
```

## Host.menu

Definition:
```luau
Host.menu: () -> { MenuEntry }?
```
Lists the lines of the right-click menu. While it's open, they're the rows it shows, top to bottom, as the client draws them: entries the client hides (other players' followers, say) aren't listed, and `submenu` is `true` on lines that open a submenu. While it's closed, they're what hovering shows, the first being what a left click does. The lines of open submenus are in `Host.menu_layout().submenus`.

Example:
```luau
local Host = require("@lib/host")

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
local Host = require("@lib/host")

local click = Host.menu_click()
if click then
	print(click.entry.option, click.entry.target, "frames ago:", click.age)
end
```

## Host.entry_swaps

Definition:
```luau
Host.entry_swaps: () -> EntrySwaps?
```
Needs host API 18. Returns the client's own entry swaps for the logged-in account, read from the files it keeps (`entryswaps.dat` and `entryswapsalt.dat` in the account's folder). `swaps` are the plain swaps and `alt` the ones used with the alternate key held; each is `{ target, options }`, where `target` is the name of the NPC, object or item as the menu shows it and `options` are the options to prefer, best first. The client acts on the first of them that the menu offers when you left click, without changing the menu: `Host.menu` and the up-text still show the unswapped order. Returns `nil` when the account isn't known yet (not logged in), without an error. The account's folder is found through the files the client has open and is remembered per client; the files are read on every call.

Example:
```luau
local Host = require("@lib/host")

for _, swap in ipairs((Host.entry_swaps() or { swaps = {} }).swaps) do
	print(swap.target, table.concat(swap.options, ", "))
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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

local books = Host.enum_def(1981)
for _, entry in ipairs(books and books.entries or {}) do
	print(entry.key, entry.value)
end
```

## Host.world_route

Definition:
```luau
Host.world_route: (from: Tile, to: Tile, allow_climbs: { string }) -> ({ known: boolean, reachable: boolean, from: Tile?, to: Tile? }?, string?)
```
Whether `to` can be walked to from `from` on the whole map, across planes and through the underground, using the map's own climbs and links plus the gated ones named in `allow_climbs` (`Transports.allowed_climbs`). `known` is false when either point isn't on any landmass. `from` and `to` in the answer are the first climb on the way, absent when the two are on one landmass. The first call builds the map from the game cache, which takes under a second once the collision file exists.

Example:
```luau
local Host = require("@lib/host")
local Transports = require("@lib/main/transports")

local way = Host.world_route({ x = 3222, y = 3218, plane = 0 }, { x = 2884, y = 9798, plane = 0 }, Transports.allowed_climbs())
print(way and way.reachable, way and way.from and way.from.x)
```

## Host.transport_settings

Definition:
```luau
Host.transport_settings: () -> { off: { string } }
```
The types of transport the user turned off on the loader's Settings page. It can change while a script runs. Use `Transports.is_enabled` or `Transports.require_enabled`, which read it.

Example:
```luau
local Host = require("@lib/host")

print(#Host.transport_settings().off)
```

## Host.landmasses

Definition:
```luau
Host.landmasses: (points: { { x: number, y: number, plane: number } }) -> ({ number }?, string?)
```
The landmass number of each point on any plane, found by flood fill over the map's collision from the game cache (a tile above the ground with no floor is on none): points with the same number can be walked between (closed doors count as open, stairs and other shortcuts are not followed), and different numbers are separate islands or enclosed areas. 0 means no landmass: the point has none within 3 tiles, or it isn't on plane 0 (only the surface plane is numbered). Karamja and the mainland, for example, have different numbers. The first call after a game update builds the numbers, which takes a few seconds.

Example:
```luau
local Host = require("@lib/host")

local numbers = Host.landmasses({ { x = 3213, y = 3424, plane = 0 }, { x = 2797, y = 3175, plane = 0 } })
print(numbers and numbers[1] == numbers[2])
```

## Host.cache_file

Definition:
```luau
Host.cache_file: (index: number, archive: number, file: number) -> (string?, string?)
```
One file of the client's cache as a string of its bytes, or nil when it doesn't exist. Scripts are index 12 (the archive is the script id, the file 0) and config files index 2.

Example:
```luau
local Host = require("@lib/host")

local bytes = Host.cache_file(12, 4024, 0)
print(bytes and #bytes)
```

## Host.cache_files

Definition:
```luau
Host.cache_files: (index: number, files: { { number } }) -> ({ string | boolean }?, string?)
```
Several files of one cache index at once, as `{ archive, file }` pairs: a string of bytes for each that exists and `false` for each that doesn't. Far faster than one `cache_file` call per file.

Example:
```luau
local Host = require("@lib/host")

local files = Host.cache_files(2, { { 38, 17 }, { 38, 18 } })
print(files and #files)
```

## Host.item_params

Definition:
```luau
Host.item_params: (ids: { number }) -> { { [number]: CacheValue }? }?
```
Reads the extra values ("params") the game files keep for each item, by param number. An item the game files don't have is `nil` in the list.

Example:
```luau
local Host = require("@lib/host")

local params = Host.item_params({ 3281 })
print(params and params[1] and params[1][601]) -- Wind Bolt
```

## Host.npcs

Definition:
```luau
Host.npcs: () -> { Npc }?
```
Lists the NPCs currently loaded around you. Each has `head_icons` (`HOST_API` 13): the head icons the server set on it, like an overhead prayer, as `{ archive, sprite }` (archive 440 is the prayer icons; `Npcs.overhead` names them).

Example:
```luau
local Host = require("@lib/host")

for _, npc in ipairs(Host.npcs() or {}) do
	print(npc.name, npc.x, npc.y)
end
```

## Host.npc_type_model

Definition:
```luau
Host.npc_type_model: (id: number, animation: number, frame: number, fine_x: number, fine_y: number, orientation: number) -> NpcModel?
```
Has the client build an NPC type's model (`HOST_API` 13), the way it builds one for an NPC it shows, posed at `frame` of `animation` (-1 for none, frame then ignored), and returns its on-screen outline as if it stood at local fine `fine_x`, `fine_y` (128 to a tile, as `game_state().position.local_x` counts) facing `orientation` (0 to 2047). Nothing is added to the game: it's for showing a model or an animation. `frame_count` says how many frames the animation has, from 0. Nil for an id with no model; an error for an animation that doesn't have that frame or is skeletal (not supported yet). See `examples/show_npc_animation.luau`.

Example:
```luau
local Host = require("@lib/host")

local pos = assert(Host.game_state().position)
-- Zulrah (green) two tiles east of you, at the first frame of its attack
local model = Host.npc_type_model(2042, 5069, 0, pos.local_x + 256, pos.local_y, 0)
print(model and #model.faces, model and model.frame_count)
```

## Host.npc_model

Definition:
```luau
Host.npc_model: (index: number) -> NpcModel?
```
Returns the on-screen outline of one NPC (by its `index`).

Example:
```luau
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
The hitsplats on the NPCs with these `index`es, keyed by index; the NPCs that are gone are left out. An actor keeps its last four hits, and a new hit replaces the oldest, so read them at least once a tick to see every hit. A hit stays in its slot after it fades from the screen. Each one has:

- `slot`: 0 to 3, kept until the hit is replaced.
- `kind`: the splat type. 16 is damage and 12 a block, for hits that involve you, dealt or taken; other players' hits have other kinds.
- `damage`: the number it shows.
- `cycle`: the client cycle it stops showing on, about 50 cycles (1 s) after it lands. Compare it with `Host.client_cycle` to tell how long ago the hit was; the `slot` and `cycle` together tell hits apart. [NpcHealth](main/entities/npc_health.md) works the health of NPCs out from them.

Example:
```luau
local Host = require("@lib/host")

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

## Host.player_hitsplats

Definition:
```luau
Host.player_hitsplats: (indices: { number }) -> { [number]: { Hitsplat } }?
```
The hitsplats on the players with these `index`es (`PlayerInfo.index`), keyed by index, as `Host.npc_hitsplats` gives them for NPCs. On your own player, kind 16 is damage you took and 12 a hit that missed you. Host API 14.

Example:
```luau
local Host = require("@lib/host")
local Players = require("@lib/main/entities/players")

local me = assert(Players.me())
local now = assert(Host.client_cycle())
for _, splat in ipairs((Host.player_hitsplats({ me.index }) or {})[me.index] or {}) do
	print(`hit for {splat.damage}, {(now - splat.cycle) / 50} s after it faded`)
end
```

## Host.client_cycle

Definition:
```luau
Host.client_cycle: () -> number?
```
The client's cycle counter, 50 a second: the clock that hitsplat, projectile and spot animation cycles count in. Host API 14.

Example:
```luau
local Host = require("@lib/host")

local a = assert(Host.client_cycle())
Host.sleep(1000)
print(assert(Host.client_cycle()) - a) -- about 50
```

## Host.item_stackable

Definition:
```luau
Host.item_stackable: (ids: { number }) -> { boolean? }?
```
Whether each item stacks in the inventory (coins, runes, noted items), read from the game cache, in the order of `ids`; `nil` for an id the cache doesn't know. Host API 14.

Example:
```luau
local Host = require("@lib/host")

print((Host.item_stackable({ 995, 1127 }) or {})[1]) -- coins: true
```

## Host.locs

Definition:
```luau
Host.locs: (plane: number?) -> { Loc }?
```
Lists the world objects (doors, trees, walls...) of the loaded scene on a plane (0 to 3, yours by default). `shape` and `rotation` are known for every kind (walls included). `clickable` is the client's own flag for an object you can click; it is also what makes the minimap draw a wall red, so a clickable wall is a door, gate or curtain.

Example:
```luau
local Host = require("@lib/host")

for _, loc in ipairs(Host.locs() or {}) do
	if loc.name == "Bank booth" then
		print("bank booth at", loc.x, loc.y)
	end
end
```

## Host.loc_shown

Definition:
```luau
Host.loc_shown: (ids: { number }) -> { LocView }?
```
How each object id looks to the player now, in the order given: its `name` and its right-click `actions`. A multi-state object (a farming patch, a door that opens) shows the form its varbit or varp picks at the moment, so a spirit tree placed in a farming patch is the patch's name and options until the tree has grown. An id the cache doesn't know gives an empty name and no actions. Nil when the cache can't be read. The ids to ask about are the ones *placed* on the map (`Host.cache_locs` lists them); the id of the grown form always looks grown.

Example:
```luau
local Host = require("@lib/host")

local views = Host.loc_shown({ 26261 })
print(views and views[1].name, views and table.concat(views[1].actions, ", "))
```

## Host.cache_locs

Definition:
```luau
Host.cache_locs: (area: Corners, filter: CacheLocFilter?) -> { CacheLoc }?
```
Lists the world objects the game cache places on the map inside an area (`x1`, `y1`, `x2`, `y2`, both corners included), on every plane, whether or not that part of the map is loaded: where `Host.locs` only has your floor of the loaded scene. Each one has its name and menu `actions`. The filter keeps the objects on a `plane`, with any of the `names` in their name (any case) and any of the `actions` as a whole option (any case). The area covers at most 64 map squares (64 x 64 tiles each). It is what the cache says about the map: not what changed since (doors that are open, objects that came or went), and objects that transform into others (by a varbit) show as their first form. An 80 x 80 tile area takes about 50 ms.

Example:
```luau
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

print(Host.in_instance())
```

## Host.server_tile

Definition:
```luau
Host.server_tile: () -> ServerTile?
```
The tile the server last put you on. Your `position` in `Host.game_state` follows your character's model, which walks there smoothly and so lags the server by up to a tick or two; this is where the game already has you. `steps` is how many steps of the path the client still has to animate. `nil` when not logged in.

Example:
```luau
local Host = require("@lib/host")

local tile = Host.server_tile()
if tile then
	print(`server tile {tile.x}, {tile.y}, {tile.steps} steps to animate`)
end
```

## Host.movement

Definition:
```luau
Host.movement: () -> MovementState?
```
Your server tile and whether the server moved you this tick. The agent looks at the tile just before the client takes each packet, so it sees every tick's change even while your script is busy. `moving` turns true as the tick that moves you is received and stays true until the next tick ends, so a single step reads as one tick of `moving` and a walk as `moving` all the way. A teleport, a login or a world hop also shows as one change; `from_x`, `from_y` and `from_plane` tell you how far it went (walking moves you at most 1 tile a tick, running 2). `nil` when not logged in, or with an agent that doesn't track the tile. `Player.is_moving` wraps this.

Example:
```luau
local Host = require("@lib/host")

-- print each tick whether you moved
while Host.wait_packet({ 2 }, 1200) do
	local m = Host.movement()
	print(m and m.moving)
end
```

## Host.chat_messages

Definition:
```luau
Host.chat_messages: () -> { ChatMessage }?
```
Lists the chat history, oldest first. The game keeps up to 100 messages of each type, including the ones the chat's tabs and filters hide, and the lines of the dialogues you go through. It's read from the game, not from the screen, so it works with the chatbox closed or covered. `time` is worked out from the game's clock, which ticks every 20 ms, so it's precise to the second; `time_utc` and `time_local` are the "HH:MM" stamps the game shows when chat timestamps are on. Use `Chat.messages` for the same list cleaned up.

Example:
```luau
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
Plans a walk over every plane of the loaded scene at once, through closed doors and up and down ladders, staircases, ropes and the like; a tile without a `plane` is on yours. It reads the client's collision of all four planes, then:

- **Doors.** A door is what the minimap draws red: a wall (or a diagonal wall) the client lets you click, that blocks, has one of `door_options` and is closed (its walls are in the collision). Its walls are taken out of the collision while planning, at `door_cost` (tenths of a tile) for going through, so a plan uses a door when that is shorter than the way round.
- **Climbs.** Every way of changing plane in the transport data (`transports.tsv` of Shortest Path: stairs, ladders, ropes, cave mouths and the like, about 3,400 rows) is a climb, at `climb_cost`. A row gives the tile it is used from and the exact tile and plane it lands on, which can be any plane (a rope can go from plane 0 to plane 2) and the underground, which is the same map 6,400 tiles north, entered by the same plane. The row is tied to the clickable object beside its tile that offers the row's menu option (the one with the row's id first, else the nearest within 2 tiles); a row with no such object loaded or in the cache is left out. Nothing is guessed, and an object the data doesn't list isn't used. A row that asks for a quest, level, item or varbit is used only if its name is in `allow_climbs`.
- **Links.** The rows of `transports.tsv` that stay on one plane and cross up to 15 tiles (a stile, a log, a door that is an object, like the Grand Tree's Tree Door) are climbs that keep the plane, found and used the same way, at `climb_cost`. A hop of one tile with "Open" is a wall door, which the planner opens by taking its walls away, and no object is recognised as a door by its name. If such a row asks for something and isn't in `allow_climbs`, the plan won't step through in that direction. Rows farther than that are the script's (`Transports.ride`). The rows that start or end in the Wilderness, like the ditch, are used only by a plan that starts or ends there itself.
- **Agility shortcuts.** The rows of `agility_shortcuts.tsv` (a hop over an obstacle, short, within one world) are climbs that keep the plane, found the same way. A shortcut costs `climb_cost`, plus `SHORTCUT_TICK_COST` (4) tenths of a tile for each tick of its `Duration`, plus `shortcut_saving`, so it is only taken when it saves that much over walking round. The walker knows it worked when it stands on the tile it lands on.

The plan's `tiles` are every tile walked, start first, each with its plane; `actions` are the doors and climbs on the way, in order, each with the index `at` of the tile it is used from (the next tile is past it). When `to` is outside the loaded scene the plan uses the game cache's collision (closed doors open) for the rest, up to about 400 tiles across; farther than that it plans to a tile along the world path (`goal`), and `reached` is false. A target that can't be reached gives a plan to the closest tile on its plane, with `reached` false. In an instance only the loaded scene is used. All fields are optional:
- `near`: the plan ends this many tiles (any direction) from `to` on its plane (default 0).
- `door_options`: the options that open a door, any case (default `{ "Open" }`; `{}` takes closed doors for walls).
- `climbs`: `false` stays on the plane (default `true`).
- `shortcut_saving`: the least, in tiles, an agility shortcut has to save over walking round (default 10).
- `allow_climbs`: the climbs and shortcuts that ask for something and that the player has what they ask for, as `"x,y,plane>x,y,plane|menu"` (see `Transports.allowed_climbs`); none by default.
- `avoid`: locs not to use (`id`, `x`, `y`, `plane`), such as a door that didn't open.
- `seed`, `rnd`: with a seed every tile's cost is scaled by 1 +- `rnd` / 2, the same seed planning the same way (default `rnd` 0.6).
- `door_cost`, `climb_cost`: default 8 and 50.

Example:
```luau
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

Host.move(200, 150)
```

## Host.wind_mouse

Definition:
```luau
Host.wind_mouse: (x: number, y: number, options: WindMouseOptions?) -> ()
```
Moves the mouse to a point along a curved, human-like path. Optional `speed`, `wind`, `gravity` and `timeout` tune the movement, and `pace` (`HOST_API` 12, default 1) divides the wait between the path's points, so 1.2 runs the same path 20% faster (a rare hesitation pause keeps its length).

Example:
```luau
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

Host.key_up(0x25)
```

## Host.type_text

Definition:
```luau
Host.type_text: (text: string, hold_ms: number?) -> ()
```
Types a piece of text, optionally holding each key for `hold_ms`. Letters, digits, space and the usual punctuation are pressed as the keys of a US keyboard (with Shift where it needs it), since the client reads key codes as a US layout does; the system's layout is only asked for other characters, and one it has no key for is an error.

Example:
```luau
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

Host.move_async(200, 150)
Host.input_cancel()
```

## Host.bank_pin_enter

Definition:
```luau
Host.bank_pin_enter: () -> string
```
Enters the account's bank PIN on the open bank PIN keypad, entirely inside the injector, and returns how it went: `"entered"`, `"closed"`, `"no_pin"`, `"unavailable"`, `"locked"`, `"wrong"` or `"failed"`. The PIN comes from the loader, looked up by the hash of the logged in account's name, and is never given to the script. Blocking input, so it takes the mouse back from async input first. Use [BankpinKeypad.enter](main/interfaces/mainscreen/bankpin_keypad.md).

## Host.http_request

Definition:
```luau
Host.http_request: (options: HttpRequest) -> (HttpResponse?, string?)
```
Makes an HTTP request and returns the response, or `nil` and why not. `options` has a `url`, and optionally a `method` (`"GET"` by default), `headers` (a table of names to values), a text `body` (up to 1 MB) and a `timeout` in milliseconds (15000 by default, 60000 at most, redirects included). The response has `ok` (a status from 200 to 299), `status`, `headers` (lowercase names, a repeated header joined with `", "`) and `body` as text (up to 8 MB). A status like 404 is still a response: check `ok`, only a request that could not be made returns an error.

The loader makes the request, and only to hosts on the whitelist in its Settings (the Volcren hosts and `prices.runescape.wiki` are always on it, the user adds others). A redirect is followed only while every host on the way is whitelisted, and an `Authorization` or `Cookie` header isn't sent to a different host than the first. Blocks the script until the response is in, and needs no client.

Example:
```luau
local Host = require("@lib/host")

local response, err = Host.http_request({ url = "https://api.volcren.com/health" })
if not response then
	print("request failed:", err)
elseif response.ok then
	print(response.status, response.body)
end
```

## Host.item_prices

Definition:
```luau
Host.item_prices: (items: { number | string }) -> ({ ItemPrice? }?, string?)
```
The Grand Exchange prices of items, in the order of `items`, from the game wiki's real-time prices API (`prices.runescape.wiki`, built into the loader's HTTP whitelist). Host API 17. An item is an id or a name in any case. An id the API doesn't list, like a noted or placeholder id, is looked up by its name in the client, so it gives the tradeable item of that name (without a client it stays `nil`). `nil` for an item that isn't traded on the Grand Exchange. `high`, `low` and their times are `nil` when the item was never seen bought or sold, and `value`, `high_alch`, `low_alch` and `limit` when the wiki doesn't know them.

The injector downloads the item list and the latest prices on the first call and keeps them in memory, so asking often costs nothing: a call downloads the latest prices again once they are 10 minutes old, and the item list once it is a day old. Each run keeps its own. A failed download keeps the prices it had and tries again a minute later; only a run that has none yet gets the error. The first call blocks for the download (about a megabyte), and it needs the loader, like `Host.http_request`. Use [ItemData](utils/item_data.md).

Example:
```luau
local Host = require("@lib/host")

local prices, err = Host.item_prices({ 4151, "Rune scimitar" })
if not prices then
	print("no prices:", err)
elseif prices[1] then
	print(prices[1].name, prices[1].high, prices[1].low)
end
```

## Host.draw_rect

Definition:
```luau
Host.draw_rect: (x1: number, y1: number, x2: number, y2: number, r: number, g: number, b: number, a: number?) -> ()
```
Draws a colored rectangle on top of the game (colors 0 to 255). Handy for seeing what a script is looking at.

Example:
```luau
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

local start = Host.time()
Host.sleep(500)
print("took", Host.time() - start, "ms")
```

## Host.antiban_config

Definition:
```luau
Host.antiban_config: () -> AntibanConfig
```
The global break and sleep config the loader sent (the default one when run without it): `breaks_enabled`, `sleeps_enabled`, `breaks` (`interval`, `length`, `randomness?`, `logout_chance?`), `sleeps` (`time?`, `length?`, `randomness?`, `logout_chance?`) and a `version` that goes up whenever a new one arrives. Times are in milliseconds. A field that is left out is Auto. Scripts don't read this themselves; `Antiban.sync_config` does.

Example:
```luau
local Host = require("@lib/host")

print(#Host.antiban_config().breaks)
```

## Host.transports

Definition:
```luau
Host.transports: () -> TransportsData
```
The transports (teleport spells and the like) the loader downloaded and parsed (`HOST_API` 9; it copies thousands of rows, so read it once), from the Shortest Path plugin's data (BSD-2-Clause, github.com/Skretzo/shortest-path). `source` says which version the loader gave this run: a short commit, that with `, part bundled` when a kept file was damaged, or `bundled` (`none` when the loader sent nothing), `version` goes up when a new set arrives, and each `Transport` has `kind` (its file), `origin?`, `destination?`, `name`, `duration` (ticks), `wilderness?` (the highest level it can be used at), `skills`, `quests`, `varbits`, `varps` (tests like `{ id = 4070, op = "=", value = 0 }`), `items` and `consumable`. Scripts don't read this themselves; `Transports` does.

Example:
```luau
local Host = require("@lib/host")

print(#Host.transports().transports)
```

## Host.antiban_skips

Definition:
```luau
Host.antiban_skips: () -> { { kind: string, index: number } }
```
The "Skip next" presses in the loader's Breaks tab since the last call, oldest first. `kind` is `"break"` or `"sleep"` and `index` the position in the config, counting from 0. `Antiban.sync_config` handles them; scripts don't need to.

## Host.murmur2a

Definition:
```luau
Host.murmur2a: (text: string, seed: number?) -> number
```
The MurmurHash2A of `text` as a number from 0 to 2^32 - 1 (`seed` 0 by default). `Biometrics.murmur2a` calls it.

## Host.biometrics_profile

Definition:
```luau
Host.biometrics_profile: (name: string) -> { number }
```
The 24 byte biometric profile of an account name, each byte 0 to 255. The same name always gives the same profile. `Biometrics.setup` calls it.

## Host.widget_model

Definition:
```luau
Host.widget_model: (group: number, child: number) -> { kind: number, id: number }?
```
The model a component draws: `kind` is its type (1 is a model id) and `id` the model, -1 when it draws none. Nil when there is no such component. It reads the client's memory directly, so it's slower than `Host.widget`.

Example:
```luau
local Host = require("@lib/host")

local model = Host.widget_model(184, 7)
print(model and model.id)
```

## Host.lamp_skill

Definition:
```luau
Host.lamp_skill: () -> (string?, string?)
```
The skill set on the loader's Accounts page for spending the lamps of the logged in account (`HOST_API` 11). The sandbox reads the account itself and asks by the hash of its name, so a script can't ask about another saved account. Nil when none is set, nobody is logged in or the run has no loader; nil and the reason when there is no client or the loader can't say. Use `Randoms.lamp_skill`, which also checks the answer.

Example:
```luau
local Host = require("@lib/host")

print(Host.lamp_skill())
```

## Host.unix_time

Definition:
```luau
Host.unix_time: () -> number
```
Seconds since the Unix epoch on this computer, with the milliseconds as the fraction. Use it with the game's variables that store a moment, such as varp 892, the minute of the last home teleport.

Example:
```luau
local Host = require("@lib/host")

local minutes = (Host.unix_time() / 60) - (Host.varp(892) or 0)
print("last home teleport", math.floor(minutes), "minutes ago")
```

## Host.clock

Definition:
```luau
Host.clock: () -> number
```
Seconds since local midnight on this computer, with the milliseconds as the fraction. Unlike `Host.time`, it's the time of day, so use it to schedule things at a clock time (see `Antiban.sync_config`).

Example:
```luau
local Host = require("@lib/host")

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
local Host = require("@lib/host")

Host.report_counters({
	{ id = "games", label = "Games", value = 12 },
	{ id = "wins", label = "Wins", value = 9, percent_of = "games" },
	{ id = "points", label = "Points", value = 9000, per = "games" },
})
```

## Host.report_warning

Definition:
```luau
Host.report_warning: (text: string) -> ()
```
Writes a line to the loader's log in the warning color (yellow), for something the script wants noticed that isn't an error. The line is shown as written, so start it with the usual `[tag][time]:`; `Log.warn` does that. Works in any run.

Example:
```luau
local Host = require("@lib/host")

Host.report_warning("[Bank][00:01:02:003]: the bank is nearly full")
```

## Host.report_breaks

Definition:
```luau
Host.report_breaks: (plan: BreakPlan) -> ()
```
Shows the breaks and sleeps the script has scheduled in the loader's Breaks tab. Every time is in milliseconds, and the loader counts the times down itself, so send the plan when it changes, not every second. `breaks` and `sleeps` hold `{ remaining, length, at? }` (`at` is the time of day of a sleep, in seconds since local midnight), and `active` says which one is being taken right now and how long is left of it. `Antiban` sends this for you. Works in any run, and needs no store session.

Example:
```luau
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

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
local Host = require("@lib/host")

local menu = Host.menu_layout()
if menu then
	print(menu.x, menu.y, menu.width, menu.height, "lines from", menu.rows.y)
	for _, sub in ipairs(menu.submenus) do
		print("submenu of line", sub.row, "at", sub.x, sub.y, "with", #sub.entries, "lines")
	end
end
```
