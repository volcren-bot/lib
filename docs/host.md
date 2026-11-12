# Host

The sandbox globals the client gives every script: game state, input, overlay drawing and timing. The rest of `lib` is built on them. Functions that can fail return `nil` (and, where the signature says so, an error string).

```luau
local Host = require("@lib/host")
```

## Types

All are plain tables; see `host.luau` for every field.

| Type | Holds |
| --- | --- |
| `ClientState` | Position, name, skills, run energy, weight, camera, minimap zoom, destination. Any field may be `nil` (e.g. logged out). |
| `PositionData` | World tile `x`, `y`, `plane` (0 ground, `nil` if unreadable) and scene tile `local_x`, `local_y`. |
| `Skill` | `name`, boosted `level`, `real_level`, `xp`. |
| `LoginLayout` | Where the login screen's parts are drawn. |
| `CameraState` | Position, `pitch`, `yaw`, focal point, `zoom`. Positions in 128ths of a tile; angles 0 to 16383 per turn. |
| `MinimapState` | `zoom` in pixels per tile (2 to 8). |
| `Connection` | Client `version`, `protocol`, window `width`/`height`, mouse position. |
| `Widget` | One interface component: position, size, text, sprite, hidden, scroll, `item_id`/`item_quantity`. |
| `ItemSlot` | `slot`, item `id`, `quantity`. |
| `ItemChange` / `Packet` | What `Host.on_item_change` and `Host.on_packet` pass. |
| `Npc` / `PlayerInfo` | `index`, `name`, world and local tile. NPCs have `animation` (-1 none) and `head_icons`; players have `pose` and `movement` (their stand/turn/walk/run poses; a `pose` outside it is an obstacle, emote or ride). |
| `NpcModel` | On-screen outline of an actor or object this frame (box corners, hull, faces). |
| `Hitsplat` | `slot`, `kind`, `damage`, `cycle`. |
| `Collision` | Corner `x`, `y`, `width`, `height`, `plane`, per-tile `flags`. |
| `CacheLoc` / `CacheLocFilter` | An object the cache places on the map (`name`, tile, `plane`, size, `shape`, `rotation`, `actions`), and the filter for `Host.cache_locs`. |
| `Loc` / `LocView` | A scene object with tile, size, shape and `clickable`; how an object id looks now (`name`, `actions`). |
| `GroundItem` | An item on the ground. |
| `Projectile` | Graphic `id`, endpoints, start/end `cycle`, current position. See [Projectiles](main/entities/projectiles.md). |
| `SpotAnim` | Graphic `id`, tile, `plane`, start. See [Spot animations](main/entities/spot_anims.md). |
| `ChatMessage` | `uid` (increasing), `kind`, `name`, `sender`, `text`, `time` (ms since 1970), `age` (ms), `cycle`, `time_utc`/`time_local` ("HH:MM"). |
| `MenuEntry` / `MenuClick` | A right-click line (`submenu` true if it opens one); the line the client last acted on. |
| `MenuLayout` / `MenuSubmenu` / `MenuRect` | Open menu geometry (`Host.menu_layout`). |
| `EntrySwaps` / `EntrySwap` | The client's entry swaps (`Host.entry_swaps`). |
| `SelectedWidget` | A selected spell or item awaiting a target: `verb`, `name`, component, `item`, `targets` bitmask (1 ground items, 2 NPCs, 4 objects, 8 players, 16 self, 32 components). |
| `EnumDef` / `CacheValue` | A cache enum and one value (number or string). |
| `SubInterface` | An interface opened inside another. |
| `World` / `WorldSelect` | World list and switcher state. |
| `Tile` / `NavTile` / `Area` / `Corners` / `ScreenPoint` / `FinePoint` | Coordinate shapes. |
| `SceneRoute` / `WorldRoute` / `NavPlan` / `NavOptions` / `SceneRouteOptions` | Pathing results and options. |
| `Shape` | A `rect`, `line` or `clear` for `Host.draw_batch`. |
| `FormSpec` / `FormField` | A settings window. |
| `LayoutItem` | An item of a layout: `id`, `ids`, `name`, `stackable`, `min`/`max` (equal: exact, both 0: any), `doses`, `locked`. See [LayoutItem](main/layout_item.md). |
| `EquipmentLayout` / `EquipmentLayoutSlot` / `EquipmentSpell` | An `equipment` field's value. See [EquipmentLayout](main/equipment_layout.md). |
| `InventoryLayout` / `InventoryLayoutSlot` | An `inventory` field's value, with rune pouch `pouch`. See [InventoryLayout](main/inventory_layout.md). |
| `PrayerLayout` | A `prayer` field's value. See [PrayerLayout](main/prayer_layout.md). |
| `LayoutRequirement` | A `required` entry: `ids`, `slot`, `min`, `max`, `doses`. |
| `WindMouseOptions` | Mouse movement tuning. |
| `HttpRequest` / `HttpResponse` | `Host.http_request` input and output. |
| `ItemPrice` | `id`, `name`, `members`, `value`, `high_alch`, `low_alch`, `limit`, `high`/`low` with `high_time`/`low_time`. |

## Host.game_state

Definition:
```luau
Host.game_state: () -> ClientState
```
Snapshot of the player and client. Always returns a table; raises if the client or agent is gone.

Example:
```luau
local state = Host.game_state()
if state.position then
	print(state.position.x, state.position.y)
end
```

## Host.connection

Definition:
```luau
Host.connection: () -> Connection
```
Client version, window size and mouse position. Never nil; raises if the client or agent goes away.

Example:
```luau
local info = Host.connection()
print(`{info.width}x{info.height}`)
```

## Host.widget

Definition:
```luau
Host.widget: (group: number, child: number) -> Widget?
```
One interface component. `item_id` (-1 for none) and `item_quantity` are the item a cell shows; a bank placeholder shows quantity 0 here but 1 in the bank container.

Example:
```luau
local w = Host.widget(149, 0)
if w then
	print(w.x, w.y, w.width, w.height)
end
```

## Host.widget_children

Definition:
```luau
Host.widget_children: (group: number, child: number) -> { Widget }?
```
The child components of a component.

Example:
```luau
print(#(Host.widget_children(149, 0) or {}))
```

## Host.widget_model

Definition:
```luau
Host.widget_model: (group: number, child: number) -> { kind: number, id: number }?
```
The model a component draws (`kind` 1 is a model id; `id` -1 for none). Nil for no such component. Slower than `Host.widget`.

Example:
```luau
print((Host.widget_model(184, 7) or { id = -1 }).id)
```

## Host.item_container

Definition:
```luau
Host.item_container: (id: number) -> { ItemSlot }?
```
Contents of an item container: inventory `93`, worn `94`, bank `95`.

Example:
```luau
for _, slot in ipairs(Host.item_container(93) or {}) do
	print(slot.slot, slot.id, slot.quantity)
end
```

## Host.on_item_change

Definition:
```luau
Host.on_item_change: (callback: (change: ItemChange) -> ()) -> number
```
Calls `callback` for every item container slot write from now on and returns an id for `Host.off_item_change`. A change has `container`, `slot`, `tick`, `old_item`, `old_quantity`, `new_item`, `new_quantity` (empty is `-1`) and `old_known` (false when the write created the container). Callbacks run only inside `Host.sleep`, `Host.wait_item_change` and `Host.wait_packet`; a script that never sleeps sees none. A callback error ends the script. One tick's changes arrive together (a bank opening is hundreds).

Example:
```luau
Host.on_item_change(function(change)
	if change.container == 93 then
		print(change.slot, change.old_item, "->", change.new_item)
	end
end)
Host.sleep(10000)
```

## Host.off_item_change

Definition:
```luau
Host.off_item_change: (id: number) -> boolean
```
Removes a callback from `Host.on_item_change`; returns whether it existed.

## Host.wait_item_change

Definition:
```luau
Host.wait_item_change: (ms: number) -> boolean
```
Waits up to `ms` for an item container change, runs the callbacks and returns true; false on timeout. Without an `on_item_change` callback it only sleeps.

Example:
```luau
Host.on_item_change(function() end)
print(Host.wait_item_change(30000))
```

## Host.on_packet

Definition:
```luau
Host.on_packet: (opcodes: { number }, callback: (packet: Packet) -> (), sent: boolean?) -> number
```
Calls `callback` for each received server packet with an opcode (0 to 255) in `opcodes`, or each sent client packet when `sent` is true; returns an id for `Host.off_packet`. A packet has `opcode`, `sent`, `length`, `payload` (first 104 bytes as a string), `time_ms`, `sequence`. Callbacks run only while sleeping or waiting; the client keeps the last 4096 packets, so long busy stretches drop some. Server packet 2 is the game tick.

Example:
```luau
local ticks = 0
Host.on_packet({ 2 }, function()
	ticks += 1
end)
Host.sleep(6000)
print(ticks) -- about 10
```

## Host.off_packet

Definition:
```luau
Host.off_packet: (id: number) -> boolean
```
Removes a callback from `Host.on_packet`; returns whether it existed.

## Host.wait_packet

Definition:
```luau
Host.wait_packet: (opcodes: { number }, ms: number, sent: boolean?) -> Packet?
```
Waits up to `ms` for a packet in `opcodes` that arrives after the call and returns it; nil on timeout. Runs pending callbacks while waiting.

Example:
```luau
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
Projects fine world points to the screen. `shift` (fine units, optional landing `plane`) projects as the camera will be once the player has moved that far; only the local calculation supports it, so `via = "client"` with `shift` errors.

Example:
```luau
local cam = Host.game_state().camera
if cam then
	local p = Host.project({ { x = cam.focal_x, y = cam.focal_y } })
	print(p and p[1].x, p and p[1].y)
end
```

## Host.form

Definition:
```luau
Host.form: (spec: FormSpec) -> { [string]: any }?
```
Shows a settings window and blocks until submitted; returns values by field id, or `nil, "cancelled"`. `title` is not shown but keys remembered values and layouts, so make it unique per script.

Field kinds: `label`, `check`, `number`, `text`, `choice`, `list` (ticked rows, `items = { { id, label, default } }` giving `{ id = true }`), `equipment`, `inventory`, `prayer`. The last three add a loader tab where the user captures and edits layouts; the value is the chosen `EquipmentLayout`, `InventoryLayout` or `PrayerLayout`, or nil. `equipment`/`inventory` take `required` (`LayoutRequirement`s padlocked into every layout); `prayer` takes `locked` (keys the script controls, excluded from layouts).

Field options: `enabled_by`/`disabled_by` (a check id); `row` (fields with the same name share a line, `row_gap` apart, default 24, max 500); `box_first` for `number`; `heading = 1 | 2` for `label` (spaced by `heading_gap`, default 12, max 500); `visible_when = { id, equals }` or a list of them (`equals` may be a list). Hidden fields keep and return their values.

Example:
```luau
local values = Host.form({
	title = "My script",
	submit = "Start",
	fields = {
		{ id = "loops", kind = "number", label = "Loops", default = 5, min = 1, max = 100, integer = true },
		{ id = "fast", kind = "check", label = "Go fast", default = false },
	},
})
if not values then
	return
end
print(values.loops, values.fast)
```

## Host.form_update

Definition:
```luau
Host.form_update: () -> { [string]: any }?
```
After submit the form stays in the loader with an Update button; this returns the full new values (same shape as `Host.form`) when the user pressed it since the last call, else nil.

Example:
```luau
local new = Host.form_update()
if new then
	values = new
end
```

## Host.menu

Definition:
```luau
Host.menu: () -> { MenuEntry }?
```
Right-click menu lines. Open: the rows shown, top to bottom, without client-hidden entries. Closed: what hovering offers, first being the left-click action. Submenu lines are in `Host.menu_layout().submenus`. Cancels async input.

Example:
```luau
for _, entry in ipairs(Host.menu() or {}) do
	print(entry.option, entry.target)
end
```

## Host.menu_click

Definition:
```luau
Host.menu_click: () -> MenuClick?
```
The menu line the client last acted on, the mouse position and `age` in frames. Nil when unavailable.

Example:
```luau
local click = Host.menu_click()
if click then
	print(click.entry.option, click.age)
end
```

## Host.entry_swaps

Definition:
```luau
Host.entry_swaps: () -> EntrySwaps?
```
The account's client entry swaps from `entryswaps.dat` and `entryswapsalt.dat`: `swaps` and `alt` (alternate key held), each `{ target, options }` with options best first. The client applies them on left click without changing the menu, so `Host.menu` shows the unswapped order. Nil when not logged in. Files are reread each call.

Example:
```luau
for _, swap in ipairs((Host.entry_swaps() or { swaps = {} }).swaps) do
	print(swap.target, table.concat(swap.options, ", "))
end
```

## Host.menu_open

Definition:
```luau
Host.menu_open: () -> boolean
```
Whether the right-click menu is open. Errors when the agent hasn't found the flag. Cancels async input.

Example:
```luau
print(Host.menu_open())
```

## Host.menu_layout

Definition:
```luau
Host.menu_layout: () -> MenuLayout?
```
The open menu as the client's own layout routine places it, in interface units (multiply by `game_state().ui_scale` for pixels): menu `x`, `y`, `width`, `height`, line area `rows`, `header_height`, `row_height`, `scroll`, and `margin` (how far outside the mouse may go before it closes). `submenus` (up to 4 deep, outermost first) have the same fields plus `row` (1-based opener line) and `entries`. Nil when closed. Cancels async input.

Example:
```luau
local menu = Host.menu_layout()
if menu then
	print(menu.x, menu.y, menu.width, menu.height, #menu.submenus)
end
```

## Host.selected_widget

Definition:
```luau
Host.selected_widget: () -> SelectedWidget?
```
What is waiting for a target, like a selected spell. Nil when nothing is. See [Magic](main/interfaces/gametabs/magic.md).

Example:
```luau
local s = Host.selected_widget()
if s then
	print(s.verb, s.name)
end
```

## Host.sub_interfaces

Definition:
```luau
Host.sub_interfaces: () -> { SubInterface }?
```
Interfaces open inside other interfaces.

Example:
```luau
for _, sub in ipairs(Host.sub_interfaces() or {}) do
	print(sub.group, "inside", sub.parent_group)
end
```

## Host.game_val_name

Definition:
```luau
Host.game_val_name: (kind: number, id: number) -> string?
```
Readable name of a game value of `kind` (see [GameVal](utils/game_val.md)).

Example:
```luau
print(Host.game_val_name(0, 1))
```

## Host.game_val_names

Definition:
```luau
Host.game_val_names: (kind: number, ids: { number }) -> { string? }?
```
Batch `Host.game_val_name`.

Example:
```luau
print(#(Host.game_val_names(0, { 1, 2, 3 }) or {}))
```

## Host.item_name

Definition:
```luau
Host.item_name: (id: number) -> string?
```
An item's name.

Example:
```luau
print(Host.item_name(995))
```

## Host.item_names

Definition:
```luau
Host.item_names: (ids: { number }) -> { string? }?
```
Batch `Host.item_name`.

Example:
```luau
print((Host.item_names({ 995, 554 }) or {})[2])
```

## Host.varc

Definition:
```luau
Host.varc: (id: number) -> number?
```
A client variable (varc).

Example:
```luau
print(Host.varc(74))
```

## Host.varp

Definition:
```luau
Host.varp: (id: number) -> number?
```
A player variable (varp). See [Varps](main/varps.md).

Example:
```luau
print(Host.varp(173))
```

## Host.varps

Definition:
```luau
Host.varps: () -> { number }?
```
Every varp; id `n` is at index `n + 1`.

Example:
```luau
print(#(Host.varps() or {}))
```

## Host.varbit

Definition:
```luau
Host.varbit: (id: number) -> number?
```
A varbit; its varp and bit range are read from the cache once per script. See [Varbits](main/varbits.md).

Example:
```luau
print(Host.varbit(4070))
```

## Host.enum_def

Definition:
```luau
Host.enum_def: (id: number) -> EnumDef?
```
A cache enum (`key_type`, `value_type`, `default`, `entries`). Nil when it doesn't exist.

Example:
```luau
for _, e in ipairs((Host.enum_def(1981) or { entries = {} }).entries) do
	print(e.key, e.value)
end
```

## Host.world_route

Definition:
```luau
Host.world_route: (from: NavTile, to: NavTile, allow_climbs: { string }?) -> WorldRoute?
```
Whether `to` is reachable from `from` anywhere on the map, across planes and underground, via the map's climbs and links plus gated ones in `allow_climbs` (`Transports.allowed_climbs`). `known` is false when either point is on no landmass; `from`/`to` of the result are the first climb, absent when both points share a landmass. The first call builds the map (under a second once the collision file exists).

Example:
```luau
local Transports = require("@lib/main/transports")

local way = Host.world_route({ x = 3222, y = 3218, plane = 0 }, { x = 2884, y = 9798, plane = 0 }, Transports.allowed_climbs())
print(way and way.reachable)
```

## Host.transport_settings

Definition:
```luau
Host.transport_settings: () -> { off: { string } }
```
Transport types the user disabled in the loader settings; can change mid-run. Use `Transports.is_enabled` / `Transports.require_enabled`.

Example:
```luau
print(#Host.transport_settings().off)
```

## Host.landmasses

Definition:
```luau
Host.landmasses: (points: { { x: number, y: number, plane: number } }) -> ({ number }?, string?)
```
Landmass number per point, from a flood fill of the cache collision on every plane (closed doors open, climbs not followed): equal numbers are walkable between. 0 means no standable tile within 3 tiles. The first call after a game update takes a few seconds.

Example:
```luau
local n = Host.landmasses({ { x = 3213, y = 3424, plane = 0 }, { x = 2797, y = 3175, plane = 0 } })
print(n and n[1] == n[2])
```

## Host.cache_file

Definition:
```luau
Host.cache_file: (index: number, archive: number, file: number) -> (string?, string?)
```
One cache file's bytes, nil if missing. Scripts are index 12 (archive = script id, file 0); configs index 2.

Example:
```luau
print(#(Host.cache_file(12, 4024, 0) or ""))
```

## Host.cache_files

Definition:
```luau
Host.cache_files: (index: number, files: { { number } }) -> ({ string | boolean }?, string?)
```
Batch `Host.cache_file` over `{ archive, file }` pairs; `false` for missing files. Much faster than separate calls.

Example:
```luau
print(#(Host.cache_files(2, { { 38, 17 }, { 38, 18 } }) or {}))
```

## Host.item_params

Definition:
```luau
Host.item_params: (ids: { number }) -> { { [number]: CacheValue }? }?
```
Each item's cache params by param id; nil for unknown items.

Example:
```luau
print(((Host.item_params({ 3281 }) or {})[1] or {})[601])
```

## Host.item_stackable

Definition:
```luau
Host.item_stackable: (ids: { number }) -> { boolean? }?
```
Whether each item stacks in the inventory, from the cache; nil for unknown ids.

Example:
```luau
print((Host.item_stackable({ 995, 1127 }) or {})[1]) -- true
```

## Host.npcs

Definition:
```luau
Host.npcs: () -> { Npc }?
```
Loaded NPCs. `head_icons` are `{ archive, sprite }` pairs (archive 440 is prayers; `Npcs.overhead` names them).

Example:
```luau
for _, npc in ipairs(Host.npcs() or {}) do
	print(npc.name, npc.x, npc.y)
end
```

## Host.npc_model

Definition:
```luau
Host.npc_model: (index: number) -> NpcModel?
```
On-screen outline of an NPC by `index`.

Example:
```luau
local npc = (Host.npcs() or {})[1]
print(npc and Host.npc_model(npc.index))
```

## Host.npc_type_model

Definition:
```luau
Host.npc_type_model: (
	id: number,
	animation: number,
	frame: number,
	fine_x: number,
	fine_y: number,
	orientation: number
) -> NpcModel?
```
Builds an NPC type's model posed at `frame` of `animation` (-1 for none) and returns its outline as if standing at local fine `fine_x`, `fine_y` facing `orientation` (0 to 2047). Adds nothing to the game. `frame_count` is the animation's frame count. Nil for an id without a model; errors for a missing frame or a skeletal animation. See `examples/show_npc_animation.luau`.

Example:
```luau
local pos = assert(Host.game_state().position)
local model = Host.npc_type_model(2042, 5069, 0, pos.local_x + 256, pos.local_y, 0)
print(model and model.frame_count)
```

## Host.npc_sizes

Definition:
```luau
Host.npc_sizes: (indices: { number }) -> { [number]: number }?
```
Tile size of each NPC by index; gone NPCs are omitted. Used by [SafeSpot](main/safespot.md).

Example:
```luau
local npc = (Host.npcs() or {})[1]
print(npc and (Host.npc_sizes({ npc.index }) or {})[npc.index])
```

## Host.npc_hitsplats

Definition:
```luau
Host.npc_hitsplats: (indices: { number }) -> { [number]: { Hitsplat } }?
```
Hitsplats per NPC index; gone NPCs are omitted. An actor keeps its last four (`slot` 0 to 3), a new hit replacing the oldest, so poll at least once a tick. `kind` 16 is damage and 12 a block for hits involving you; `cycle` is when it stops showing (about 50 cycles after landing; compare with `Host.client_cycle`). [NpcHealth](main/entities/npc_health.md) builds on this.

Example:
```luau
local npc = (Host.npcs() or {})[1]
if npc then
	for _, s in ipairs((Host.npc_hitsplats({ npc.index }) or {})[npc.index] or {}) do
		print(s.damage, s.cycle)
	end
end
```

## Host.player_hitsplats

Definition:
```luau
Host.player_hitsplats: (indices: { number }) -> { [number]: { Hitsplat } }?
```
`Host.npc_hitsplats` for players by `PlayerInfo.index`. On yourself, kind 16 is damage taken and 12 a miss.

Example:
```luau
local Players = require("@lib/main/entities/players")

local me = assert(Players.me())
print(#((Host.player_hitsplats({ me.index }) or {})[me.index] or {}))
```

## Host.client_cycle

Definition:
```luau
Host.client_cycle: () -> number?
```
The client cycle counter (50 per second) that hitsplat, projectile and spot animation cycles use.

Example:
```luau
print(Host.client_cycle())
```

## Host.locs

Definition:
```luau
Host.locs: (plane: number?) -> { Loc }?
```
Scene objects on a plane (default yours). `clickable` is the client's flag, which also makes the minimap draw a wall red: a clickable wall is a door, gate or curtain.

Example:
```luau
for _, loc in ipairs(Host.locs() or {}) do
	if loc.name == "Bank booth" then
		print(loc.x, loc.y)
	end
end
```

## Host.loc_shown

Definition:
```luau
Host.loc_shown: (ids: { number }) -> { LocView }?
```
How each object id looks now (`name`, `actions`), resolving multi-state objects by their current varbit/varp. Pass the placed ids (from `Host.cache_locs`). Unknown ids give an empty name; nil when the cache can't be read.

Example:
```luau
local v = Host.loc_shown({ 26261 })
print(v and v[1].name)
```

## Host.cache_locs

Definition:
```luau
Host.cache_locs: (area: Corners, filter: CacheLocFilter?) -> { CacheLoc }?
```
Objects the cache places inside `area` (corners included) on every plane, loaded or not. The filter matches `plane`, substrings of `names` and whole `actions` (case-insensitive). At most 64 map squares. Reflects the cache only: no runtime changes, transforming objects as their first form. 80 x 80 tiles takes about 50 ms.

Example:
```luau
local me = Host.game_state().position
if me then
	local area = { x1 = me.x - 40, y1 = me.y - 40, x2 = me.x + 40, y2 = me.y + 40 }
	for _, loc in ipairs(Host.cache_locs(area, { actions = { "Climb-up" } }) or {}) do
		print(loc.name, loc.x, loc.y, loc.plane)
	end
end
```

## Host.loc_model

Definition:
```luau
Host.loc_model: (loc: Loc) -> NpcModel?
```
On-screen outline of a scene object.

Example:
```luau
local loc = (Host.locs() or {})[1]
print(loc and Host.loc_model(loc))
```

## Host.ground_items

Definition:
```luau
Host.ground_items: () -> { GroundItem }?
```
Ground items on your plane.

Example:
```luau
for _, item in ipairs(Host.ground_items() or {}) do
	print(item.name, item.quantity, item.x, item.y)
end
```

## Host.projectiles

Definition:
```luau
Host.projectiles: () -> { Projectile }?
```
Projectiles in flight, plus sent ones not yet launched. Helpers in [Projectiles](main/entities/projectiles.md).

Example:
```luau
for _, p in ipairs(Host.projectiles() or {}) do
	print(p.id, p.end_cycle - p.cycle)
end
```

## Host.spot_anims

Definition:
```luau
Host.spot_anims: () -> { SpotAnim }?
```
Spot animations placed on tiles. Effects on an actor are its `graphic` instead. Helpers in [Spot animations](main/entities/spot_anims.md).

Example:
```luau
for _, s in ipairs(Host.spot_anims() or {}) do
	print(s.id, s.x, s.y)
end
```

## Host.map_regions

Definition:
```luau
Host.map_regions: () -> { { number } }?
```
The 64x64 map squares (`{ x, y }`, tile / 64) the scene is built from; in an instance, the copied source squares. Wrapped by `Player.map_chunks`.

Example:
```luau
for _, r in ipairs(Host.map_regions() or {}) do
	print(r[1], r[2])
end
```

## Host.in_instance

Definition:
```luau
Host.in_instance: () -> boolean?
```
The client's instance flag; nil when unreadable. Wrapped by `Player.in_instance`.

Example:
```luau
print(Host.in_instance())
```

## Host.server_tile

Definition:
```luau
Host.server_tile: () -> ServerTile?
```
The tile the server last put you on, up to a tick or two ahead of `game_state().position`; `steps` is how many path steps are left to animate. Nil when logged out.

Example:
```luau
local t = Host.server_tile()
print(t and t.x, t and t.y, t and t.steps)
```

## Host.movement

Definition:
```luau
Host.movement: () -> MovementState?
```
Your server tile and whether the server moved you this tick, tracked per packet so no tick is missed. `moving` is true from the tick that moves you until the next tick ends. Teleports, logins and hops count as one move; `from_x`, `from_y`, `from_plane` give the distance (walking 1 tile per tick, running 2). Nil when logged out. Wrapped by `Player.is_moving`.

Example:
```luau
while Host.wait_packet({ 2 }, 1200) do
	print((Host.movement() or {}).moving)
end
```

## Host.chat_messages

Definition:
```luau
Host.chat_messages: () -> { ChatMessage }?
```
Chat history, oldest first, read from memory: up to 100 per type, including filtered messages and dialogue lines, chatbox open or not. `time` is accurate to the second. `Chat.messages` gives a cleaned version.

Example:
```luau
for _, m in ipairs(Host.chat_messages() or {}) do
	print(m.time_utc, m.name, m.text)
end
```

## Host.players

Definition:
```luau
Host.players: () -> { PlayerInfo }?
```
Other loaded players. `table.find(p.movement, p.pose) == nil` means something other than standing or moving holds the player.

Example:
```luau
for _, p in ipairs(Host.players() or {}) do
	print(p.name, p.x, p.y)
end
```

## Host.player_model

Definition:
```luau
Host.player_model: (index: number) -> NpcModel?
```
On-screen outline of a player.

Example:
```luau
local p = (Host.players() or {})[1]
print(p and Host.player_model(p.index))
```

## Host.find_path

Definition:
```luau
Host.find_path: (from: Tile, to: Tile, plane: number?, max_tiles: number?) -> { Tile }?
```
Walking route on one plane (default yours) over the whole map's collision, both ends included. Ignores climbs and treats closed doors as walls. `max_tiles` caps the search, which otherwise floods everything reachable for an unreachable target. The first call after a game update takes about ten seconds.

Example:
```luau
local me = Host.game_state().position
if me then
	print(#(Host.find_path({ x = me.x, y = me.y }, { x = me.x + 10, y = me.y }) or {}))
end
```

## Host.nav_plan

Definition:
```luau
Host.nav_plan: (from: Tile | NavTile, to: Tile | NavTile, options: NavOptions?) -> (NavPlan?, string?)
```
Plans a walk across all planes, through closed doors and climbs. A tile without `plane` is on yours.

- **Doors**: closed, clickable, blocking walls with one of `door_options`; passing costs `door_cost`.
- **Climbs**: plane changes from the Shortest Path `transports.tsv` (stairs, ladders, ropes, caves; may land on any plane or underground, 6400 tiles north), tied to the clickable object offering the row's option (row id first, else nearest within 2 tiles); cost `climb_cost`. Gated rows need their name in `allow_climbs`.
- **Links**: same-plane rows up to 15 tiles (stiles, object doors), treated as climbs. A one-tile "Open" hop is a wall door. Longer rows are `Transports.ride`. Wilderness rows are used only when the plan starts or ends there.
- **Agility shortcuts**: `agility_shortcuts.tsv` rows, costing `climb_cost` + 4 per tick of `Duration` + `shortcut_saving`.

`tiles` are every tile walked with its plane; `actions` the doors and climbs in order, `at` being the index of the tile used from. Beyond the scene the plan uses cache collision (doors open) up to about 400 tiles, then plans to `goal` on the world path with `reached` false. Unreachable targets plan to the closest tile, `reached` false. Instances use only the scene.

Options: `near` (end within this many tiles, 0), `door_options` (`{ "Open" }`; `{}` disables doors), `climbs` (`true`), `shortcut_saving` (10 tiles), `allow_climbs` (`"x,y,plane>x,y,plane|menu"`, see `Transports.allowed_climbs`), `avoid` (locs to skip), `seed` and `rnd` (with a seed each tile cost scales by 1 ± `rnd`/2, default 0.6), `door_cost` (8), `climb_cost` (50). Costs are in tenths of a tile.

Example:
```luau
local me = Host.game_state().position
if me then
	local plan = Host.nav_plan({ x = me.x, y = me.y }, { x = me.x, y = me.y, plane = 0 })
	for _, a in ipairs(plan and plan.actions or {}) do
		print(a.kind, a.loc.option, a.to_plane)
	end
end
```

## Host.scene_route

Definition:
```luau
Host.scene_route: (from: Tile, to: Tile, options: SceneRouteOptions?) -> SceneRoute?
```
The route the game walks when clicking `to` from `from`, start first, using the game's route finder on the live scene (works in instances, knows opened doors). Unreachable: `reached` false and the route ends at the nearest reachable tile within 10.

With `options` (even `{}`) the route is randomized over a jittered lattice of walkable nodes with noisy edge costs; short, unreachable or over-`max_detour` routes fall back to the game's. `to` may be outside the scene: the route then spans map squares (up to about 400 tiles) using live collision for seen tiles and cache collision elsewhere; if unreachable within that, nil (use `Host.find_path`).

Options: `seed` (random), `rnd` (0.8 = ±40%), `spacing` (8 tiles), `jitter` (2), `max_detour` (1.3x), `offset` (per-call node shift, 2; 0 makes a seed repeatable).

Example:
```luau
local me = Host.game_state().position
if me then
	local route = Host.scene_route({ x = me.x, y = me.y }, { x = me.x + 8, y = me.y - 4 }, {})
	print(route and #route.tiles, route and route.reached)
end
```

## Host.collision

Definition:
```luau
Host.collision: (area: Corners?) -> Collision?
```
Live collision flags of your plane for the scene or `area`. Tile (`x + i`, `y + j`) is `flags[i * height + j + 1]`; [SafeSpot](main/safespot.md) names the flags. The outer ring has every flag set. About 2 ms.

Example:
```luau
local me = Host.game_state().position
if me then
	local c = Host.collision({ x1 = me.x, y1 = me.y, x2 = me.x, y2 = me.y + 1 })
	print(c and string.format("%x", c.flags[2]))
end
```

## Host.world_select

Definition:
```luau
Host.world_select: () -> WorldSelect?
```
World switcher state: `open` and `worlds`.

Example:
```luau
local ws = Host.world_select()
print(ws and ws.open, ws and #ws.worlds)
```

## Host.click

Definition:
```luau
Host.click: (x: number, y: number, button: string?, hold_ms: number?) -> ()
```
Teleports the mouse and clicks, holding `hold_ms` (default 60). Prefer [Mouse](utils/input/mouse.md).

Example:
```luau
Host.click(100, 100)
```

## Host.move

Definition:
```luau
Host.move: (x: number, y: number) -> ()
```
Teleports the mouse.

Example:
```luau
Host.move(200, 150)
```

## Host.wind_mouse

Definition:
```luau
Host.wind_mouse: (x: number, y: number, options: WindMouseOptions?) -> ()
```
Moves along a curved human-like path. Options: `speed`, `wind`, `gravity`, `timeout`, `pace` (default 1; 1.2 is 20% faster, hesitation pauses unchanged).

Example:
```luau
Host.wind_mouse(300, 200, { speed = 12 })
```

## Host.mouse_down

Definition:
```luau
Host.mouse_down: (button: string?) -> ()
```
Presses and holds a mouse button.

Example:
```luau
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
Host.mouse_up()
```

## Host.scroll

Definition:
```luau
Host.scroll: (notches: number) -> ()
```
Turns the wheel by `notches`.

Example:
```luau
Host.scroll(-3)
```

## Host.key_down

Definition:
```luau
Host.key_down: (key: number) -> ()
```
Presses and holds a key (virtual key code).

Example:
```luau
Host.key_down(0x25)
Host.sleep(300)
Host.key_up(0x25)
```

## Host.key_up

Definition:
```luau
Host.key_up: (key: number) -> ()
```
Releases a key.

Example:
```luau
Host.key_up(0x25)
```

## Host.type_text

Definition:
```luau
Host.type_text: (text: string, hold_ms: number?) -> ()
```
Types text, holding each key `hold_ms`. Common characters use US layout keys (the client reads key codes as US); others ask the system layout, and an unmappable character errors.

Example:
```luau
Host.type_text("hello")
```

## Async input

The `_async` functions take the same arguments as their blocking versions but queue input on a worker thread and return immediately; queued input runs in order. The queue is cancelled and dropped by blocking input, `Host.input_cancel`, `Host.menu`/`menu_open`/`menu_layout`, or script end. Cancelled clicks and typing still release their buttons and keys; a cancelled move stops where it is; buttons and keys held by `mouse_down_async`/`key_down_async` are released last-pressed first. Prefer [Mouse](utils/input/mouse.md).

## Host.click_async

Definition:
```luau
Host.click_async: (x: number, y: number, button: string?, hold_ms: number?) -> ()
```
Queues `Host.click`.

Example:
```luau
Host.click_async(100, 100)
```

## Host.move_async

Definition:
```luau
Host.move_async: (x: number, y: number) -> ()
```
Queues `Host.move`.

Example:
```luau
Host.move_async(200, 150)
```

## Host.wind_mouse_async

Definition:
```luau
Host.wind_mouse_async: (x: number, y: number, options: WindMouseOptions?) -> ()
```
Queues `Host.wind_mouse`, starting from wherever the mouse is when it runs.

Example:
```luau
Host.wind_mouse_async(300, 200, { speed = 12 })
```

## Host.type_text_async

Definition:
```luau
Host.type_text_async: (text: string, hold_ms: number?) -> ()
```
Queues `Host.type_text`.

Example:
```luau
Host.type_text_async("hello")
```

## Host.mouse_down_async

Definition:
```luau
Host.mouse_down_async: (button: string?) -> ()
```
Queues `Host.mouse_down`; released on cancel.

Example:
```luau
Host.mouse_down_async("middle")
Host.wind_mouse_async(400, 300)
Host.mouse_up_async("middle")
```

## Host.mouse_up_async

Definition:
```luau
Host.mouse_up_async: (button: string?) -> ()
```
Queues `Host.mouse_up`.

Example:
```luau
Host.mouse_up_async("middle")
```

## Host.scroll_async

Definition:
```luau
Host.scroll_async: (notches: number) -> ()
```
Queues `Host.scroll`.

Example:
```luau
Host.scroll_async(2)
```

## Host.key_down_async

Definition:
```luau
Host.key_down_async: (key: number) -> ()
```
Queues `Host.key_down`; released on cancel.

Example:
```luau
Host.key_down_async(0x25)
Host.sleep_async(300)
Host.key_up_async(0x25)
```

## Host.key_up_async

Definition:
```luau
Host.key_up_async: (key: number) -> ()
```
Queues `Host.key_up`.

Example:
```luau
Host.key_up_async(0x25)
```

## Host.sleep_async

Definition:
```luau
Host.sleep_async: (ms: number) -> ()
```
Queues a pause before the next queued input; cut short by cancel.

Example:
```luau
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
print(Host.input_busy())
```

## Host.input_wait

Definition:
```luau
Host.input_wait: () -> string?
```
Blocks until async input finishes; returns the error of a failed async input since the last check, or nil.

Example:
```luau
Host.move_async(200, 150)
print(Host.input_wait())
```

## Host.input_error

Definition:
```luau
Host.input_error: () -> string?
```
Non-blocking `Host.input_wait`: the error since the last check, or nil.

Example:
```luau
print(Host.input_error())
```

## Host.input_cancel

Definition:
```luau
Host.input_cancel: () -> ()
```
Cancels async input and drops the queue; returns once nothing is being sent.

Example:
```luau
Host.input_cancel()
```

## Host.bank_pin_enter

Definition:
```luau
Host.bank_pin_enter: () -> string
```
Enters the account's bank PIN on the open keypad inside the injector; the PIN comes from the loader by account name hash and never reaches the script. Returns `"entered"`, `"closed"`, `"no_pin"`, `"unavailable"`, `"locked"`, `"wrong"` or `"failed"`. Blocking input. Use [BankpinKeypad.enter](main/interfaces/mainscreen/bankpin_keypad.md).

## Host.lamp_skill

Definition:
```luau
Host.lamp_skill: () -> (string?, string?)
```
The lamp skill set in the loader for the logged-in account (looked up by name hash, so no other account is reachable). Nil when unset, logged out or no loader; nil and a reason when there is no client or the loader fails. Use `Randoms.lamp_skill`.

Example:
```luau
print(Host.lamp_skill())
```

## Host.http_request

Definition:
```luau
Host.http_request: (options: HttpRequest) -> (HttpResponse?, string?)
```
Blocking HTTP request made by the loader, only to hosts on its whitelist (Volcren and the wiki prices API are always allowed). Options: `url`, `method` (`"GET"`), `headers`, `body` (≤ 1 MB), `timeout` (15000 ms, max 60000, redirects included). Response: `ok` (2xx), `status`, `headers` (lowercase, repeats joined with `", "`), `body` (≤ 8 MB). Non-2xx is still a response; only a failed request returns an error. Redirects stay within the whitelist and drop `Authorization`/`Cookie` across hosts.

Example:
```luau
local res, err = Host.http_request({ url = "https://api.volcren.com/health" })
print(res and res.status, err)
```

## Host.item_prices

Definition:
```luau
Host.item_prices: (items: { number | string }) -> ({ ItemPrice? }?, string?)
```
Grand Exchange prices from the wiki prices API, in order of `items` (ids or case-insensitive names). Unlisted ids (noted, placeholders) resolve by client name. Nil for untradeable items; price fields nil when unknown. Data is cached per run: prices refresh after 10 minutes, the item list after a day; a failed refresh keeps old data and retries after a minute. The first call blocks on a ~1 MB download. Use [ItemData](utils/item_data.md).

Example:
```luau
local prices = Host.item_prices({ 4151, "Rune scimitar" })
print(prices and prices[1] and prices[1].high)
```

## Host.draw_rect

Definition:
```luau
Host.draw_rect: (x1: number, y1: number, x2: number, y2: number, r: number, g: number, b: number, a: number?) -> ()
```
Draws a rectangle on the overlay (colors 0 to 255).

Example:
```luau
Host.draw_rect(50, 50, 150, 100, 255, 0, 0)
```

## Host.draw_line

Definition:
```luau
Host.draw_line: (x1: number, y1: number, x2: number, y2: number, r: number, g: number, b: number, a: number?) -> ()
```
Draws a line on the overlay.

Example:
```luau
Host.draw_line(0, 0, 200, 200, 0, 255, 0)
```

## Host.draw_lines

Definition:
```luau
Host.draw_lines: (lines: { { number } }, r: number, g: number, b: number, a: number?) -> ()
```
Draws many `{ x1, y1, x2, y2 }` lines of one color.

Example:
```luau
Host.draw_lines({ { 0, 0, 100, 0 }, { 100, 0, 100, 100 } }, 255, 255, 0)
```

## Host.clear_overlay

Definition:
```luau
Host.clear_overlay: () -> ()
```
Clears the overlay.

Example:
```luau
Host.clear_overlay()
```

## Host.draw_batch

Definition:
```luau
Host.draw_batch: (shapes: { Shape }) -> ()
```
Draws shapes in order as one atomic overlay update. A shape is `{ kind = "rect" | "line", x1, y1, x2, y2, r, g, b, a? }` or `{ kind = "clear" }`. `Draw.batch` builds the list.

Example:
```luau
Host.draw_batch({
	{ kind = "clear" },
	{ kind = "rect", x1 = 50, y1 = 50, x2 = 150, y2 = 100, r = 255, g = 0, b = 0 },
})
```

## Host.sleep

Definition:
```luau
Host.sleep: (ms: number) -> ()
```
Pauses the script; item and packet callbacks run meanwhile.

Example:
```luau
Host.sleep(1000)
```

## Host.time

Definition:
```luau
Host.time: () -> number
```
Monotonic milliseconds since the script started.

Example:
```luau
local start = Host.time()
Host.sleep(500)
print(Host.time() - start)
```

## Host.unix_time

Definition:
```luau
Host.unix_time: () -> number
```
Seconds since the Unix epoch, fractional. Useful with varps that store a moment, such as varp 892 (minute of the last home teleport).

Example:
```luau
print((Host.unix_time() / 60) - (Host.varp(892) or 0))
```

## Host.clock

Definition:
```luau
Host.clock: () -> number
```
Seconds since local midnight, fractional; for scheduling at a time of day.

Example:
```luau
print(Host.clock() // 3600)
```

## Host.antiban_config

Definition:
```luau
Host.antiban_config: () -> AntibanConfig
```
The loader's break and sleep config (default when absent): `breaks_enabled`, `sleeps_enabled`, `breaks` (`interval`, `length`, `randomness?`, `logout_chance?`), `sleeps` (`time?`, `length?`, `randomness?`, `logout_chance?`), and `version`, bumped on each new config. Times in ms; omitted fields are Auto. Read via `Antiban.sync_config`.

Example:
```luau
print(#Host.antiban_config().breaks)
```

## Host.antiban_skips

Definition:
```luau
Host.antiban_skips: () -> { { kind: string, index: number } }
```
"Skip next" presses in the loader since the last call, oldest first; `kind` is `"break"` or `"sleep"`, `index` 0-based. Handled by `Antiban.sync_config`.

## Host.transports

Definition:
```luau
Host.transports: () -> TransportsData
```
The loader's parsed Shortest Path transport data (BSD-2-Clause, github.com/Skretzo/shortest-path). Copies thousands of rows, so read once. `source` is the commit (`, part bundled` if a file was damaged), `bundled` or `none`; `version` bumps on new data. Each `Transport` has `kind`, `origin?`, `destination?`, `name`, `duration` (ticks), `wilderness?` (max level), `skills`, `quests`, `varbits`, `varps` (`{ id, op, value }`), `items`, `consumable`. Read via `Transports`.

Example:
```luau
print(#Host.transports().transports)
```

## Host.murmur2a

Definition:
```luau
Host.murmur2a: (text: string, seed: number?) -> number
```
MurmurHash2A of `text` (seed 0 by default) as 0 to 2^32 - 1. Used by `Biometrics.murmur2a`.

## Host.biometrics_profile

Definition:
```luau
Host.biometrics_profile: (name: string) -> { number }
```
Deterministic 24-byte profile (0 to 255 each) for an account name. Used by `Biometrics.setup`.

## Host.report_counters

Definition:
```luau
Host.report_counters: (counters: { Counter }) -> ()
```
Shows script counters in the loader's XP Tracker. Send running totals; each call replaces the last. A counter is `{ id, label, value, hourly?, per?, percent_of? }`: shown per hour unless `hourly = false`, `per` divides by another counter's id ("750 per Games"), `percent_of` shows a share ("75% of Games"). Values must be finite. Works in any run.

Example:
```luau
Host.report_counters({
	{ id = "games", label = "Games", value = 12 },
	{ id = "wins", label = "Wins", value = 9, percent_of = "games" },
})
```

## Host.report_warning

Definition:
```luau
Host.report_warning: (text: string) -> ()
```
Writes a yellow line to the loader log as given; `Log.warn` adds the `[tag][time]:` prefix.

Example:
```luau
Host.report_warning("[Bank][00:01:02:003]: the bank is nearly full")
```

## Host.report_breaks

Definition:
```luau
Host.report_breaks: (plan: BreakPlan) -> ()
```
Shows scheduled breaks and sleeps in the loader's Breaks tab, which counts down itself, so send only on change. `breaks` and `sleeps` hold `{ remaining, length, at? }` (ms; `at` is a sleep's seconds since midnight); `active` is the one in progress. Sent by `Antiban`.

Example:
```luau
Host.report_breaks({ breaks = { { remaining = 600000, length = 120000 } }, sleeps = {} })
```

## Host.report_stats

Definition:
```luau
Host.report_stats: (experience: number, gold: number, custom: { number }?) -> ()
```
Reports gains since the last call (not totals) for the website stats; the loader sends them with its heartbeat. Experience ≥ 0, gold may be negative, `custom` follows the script's tracker order; rounded to integers. Reports exceeding the script's per-minute limits are refused; outside a store run they are dropped. Once a minute is enough; use `Utils.StatsReport`.

Example:
```luau
Host.report_stats(1250, 0)
```
