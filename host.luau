--!strict

export type PositionData = {
	local_x: number,
	local_y: number,
	x: number,
	y: number,
	plane: number?,
}

export type Skill = {
	name: string,
	level: number,
	real_level: number,
	xp: number,
}

-- Something a script counts: `value` is its total since the script started. The loader works out the rest.
export type Counter = {
	id: string,
	label: string,
	value: number,
	-- shown per hour of the run, unless false
	hourly: boolean?,
	-- the `id` of a counter to divide by, shown as "per" it
	per: string?,
	-- the `id` of a counter this is a share of, shown as a percent
	percent_of: string?,
}

export type PlannedBreak = {
	remaining: number,
	length: number,
	at: number?,
}

export type ActiveBreak = {
	kind: "break" | "sleep",
	remaining: number,
}

export type BreakPlan = {
	breaks: { PlannedBreak },
	sleeps: { PlannedBreak },
	active: ActiveBreak?,
}

-- A field left out is "Auto": the lib picks it from the account's biometrics.
export type BreakConfig = {
	interval: number,
	length: number,
	randomness: number?,
	logout_chance: number?,
}

export type SleepConfig = {
	time: string?,
	length: number?,
	randomness: number?,
	logout_chance: number?,
}

export type AntibanConfig = {
	version: number,
	breaks_enabled: boolean,
	sleeps_enabled: boolean,
	breaks: { BreakConfig },
	sleeps: { SleepConfig },
}

export type TransportSkill = { name: string, level: number }

-- one varbit or varp test: `op` is "=", ">", "<", "&" (all bits of `value` set) or "@" (at least `value` minutes since the varp's value, in minutes since the Unix epoch)
export type TransportClause = { id: number, op: string, value: number }

export type TransportTile = { x: number, y: number, plane: number }

export type Transport = {
	-- the data file it came from, like "teleportation_spells"
	kind: string,
	-- where it is used from; nil means from anywhere
	origin: TransportTile?,
	-- where it leads; nil means it is an origin of a permutation (fairy rings and the like)
	destination: TransportTile?,
	-- the "Display info" column; a spell's name, with the destination or option for variants
	name: string,
	-- game ticks
	duration: number,
	-- the highest wilderness level it can be used at
	wilderness: number?,
	skills: { TransportSkill },
	quests: { string },
	varbits: { TransportClause },
	varps: { TransportClause },
	-- the "Items" column as written: any-of groups (`|`) of all-of items (`&`), like `COINS=2500` (`Transports.items_met` evaluates it)
	items: string,
	consumable: boolean,
	-- the "menuOption menuTarget objectID" column as written, like `Charter Trader Crewmember 1330`
	menu: string,
	-- the comment line above the row (without the `#`), which can hold a requirement the columns can't, like `Port Phasmatys (varbit:217=7?ECTO_TOKEN=2)`; nil when there is none
	note: string?,
}

-- a named group of items from the data's item-variations: any of the ids counts
export type TransportItemName = { name: string, ids: { number } }

export type TransportsData = {
	version: number,
	-- "online", "cache" or "bundled"; "none" when the loader sent nothing
	source: string,
	transports: { Transport },
	-- the named item groups the `items` column uses
	items: { TransportItemName },
}

export type LoginLayout = {
	screen: number,
	panel_x: number,
	box_x: number,
	center_x: number,
	y: number,
	scale: number,
}

export type CameraState = {
	x: number,
	y: number,
	z: number,
	pitch: number,
	yaw: number,
	focal_x: number,
	focal_y: number,
	focal_z: number,
	zoom: number?,
}

export type MinimapState = {
	zoom: number,
}

export type ClientState = {
	position: PositionData?,
	player_name: string?,
	game_state: number?,
	skills: { Skill }?,
	tick_count: number?,
	login: LoginLayout?,
	root_interface: number?,
	ui_scale: number?,
	run_energy: number?,
	weight: number?,
	camera: CameraState?,
	minimap: MinimapState?,
	destination: Tile?,
}

export type World = {
	id: number,
	types: number,
	players: number,
	location: number,
	activity: string,
}

export type WorldSelect = {
	open: boolean,
	current: number,
	offset: number,
	max_offset: number,
	hovered: number,
	background_height: number?,
	worlds: { World },
}

export type Connection = {
	version: string,
	protocol: number,
	width: number,
	height: number,
	mouse_x: number,
	mouse_y: number,
	offsets_found: boolean?,
}

export type ScreenPoint = {
	x: number,
	y: number,
}

export type FinePoint = {
	x: number,
	y: number,
	z: number?,
	tile: { x: number, y: number }?,
}

-- An item in an equipment or inventory layout: `stackable` says whether its `quantity` is a stack or one of several copies.
export type LayoutItem = {
	id: number,
	quantity: number,
	name: string,
	stackable: boolean,
}

-- One of the worn items slots in an equipment layout (`slot` is the container's: 0 head, 1 cape, 2 amulet, 3 weapon, 4 body, 5 shield, 7 legs, 9 hands, 10 feet, 12 ring, 13 ammo, and 14 for the secondary ammo of a bolt pouch or Dizana's quiver, which isn't in the container and is ignored without one): `item` wants that item worn there, `empty` wants nothing worn there and `any` doesn't care.
export type EquipmentLayoutSlot = {
	slot: number,
	mode: "item" | "empty" | "any",
	id: number?,
	quantity: number?,
	name: string?,
	stackable: boolean?,
}

-- The spell of an equipment layout: `autocast` when the weapon read from the client could autocast (the script sets it on the combat tab), else one the script casts by hand. `book` is "standard", "ancient" or "arceuus".
export type EquipmentSpell = {
	key: string,
	name: string,
	book: string,
	level: number,
	autocast: boolean,
}

-- What an `equipment` form field gives: the layout the user picked in the loader, every used slot listed once, and its spell when one was picked.
export type EquipmentLayout = {
	name: string,
	slots: { EquipmentLayoutSlot },
	spell: EquipmentSpell?,
}

-- An item of an inventory layout and the slot (0 to 27) it sits in.
export type InventoryLayoutSlot = {
	slot: number,
	id: number,
	quantity: number,
	name: string,
	stackable: boolean,
}

-- What an `inventory` form field gives: the layout the user picked in the loader, only the filled slots, and the rune pouch's runes when the layout holds a pouch.
export type InventoryLayout = {
	name: string,
	slots: { InventoryLayoutSlot },
	pouch: { LayoutItem }?,
}

-- What a `prayer` form field gives: the layout the user picked in the loader, a set of prayers by key (`Prayer.PRAYERS`: "thick_skin", "protect_from_melee", ...), in the prayer book's order.
export type PrayerLayout = {
	name: string,
	prayers: { string },
}

export type FormField = {
	id: string?,
	-- `equipment`, `inventory` and `prayer` (host API 10) add an Equipment, Inventory or Prayer tab to the script's page in the loader, where the user makes layouts (read from the client, or for prayers also clicked together) and keeps them per script; the value is the chosen `EquipmentLayout`, `InventoryLayout` or `PrayerLayout`, or nil when none is chosen
	kind: ("label" | "check" | "number" | "text" | "choice" | "list" | "equipment" | "inventory" | "prayer")?,
	label: string?,
	text: string?,
	default: any?,
	options: { string }?,
	min: number?,
	max: number?,
	step: number?,
	integer: boolean?,
	-- list: its rows, shown as ticked or not; the value is { [row id]: boolean }
	items: { { id: string, label: string?, default: boolean? } }?,
	-- the id of a check; the field is greyed out while that check is off
	enabled_by: string?,
	-- only shown while the field `id` has this value, or one of these when it is a list (a choice's option, a check's boolean, ...); a list of such rules needs all of them to hold; its value is still sent while hidden
	visible_when: ({ id: string, equals: any } | { { id: string, equals: any } })?,
}

export type FormSpec = {
	title: string?,
	submit: string?,
	-- the checks go in a column on the right, everything else on the left; stacked in a narrow window
	columns: boolean?,
	fields: { FormField },
}

export type MenuEntry = {
	option: string,
	target: string,
	raw_target: string,
	id: number,
	index: number,
	action: number,
	priority: number,
	kind: number,
	-- Whether the row opens a submenu. Only known for the rows of an open menu.
	submenu: boolean,
}

export type MenuClick = {
	entry: MenuEntry,
	x: number,
	y: number,
	age: number,
}

export type MenuRect = {
	x: number,
	y: number,
	width: number,
	height: number,
}

-- The open right-click menu in interface units; `scroll` is the row scroll, `margin` how far the mouse may leave it, `submenus` the open submenus.
export type MenuLayout = {
	x: number,
	y: number,
	width: number,
	height: number,
	rows: MenuRect,
	header_height: number,
	row_height: number,
	scroll: number,
	margin: number,
	submenus: { MenuSubmenu },
}

-- An open submenu: `row` is the row of the menu above that opened it (1 for the top), `entries` its rows top to bottom.
export type MenuSubmenu = {
	row: number,
	entries: { MenuEntry },
	x: number,
	y: number,
	width: number,
	height: number,
	rows: MenuRect,
	header_height: number,
	row_height: number,
	scroll: number,
	margin: number,
}

export type SelectedWidget = {
	verb: string,
	name: string,
	raw_name: string,
	id: number,
	group: number,
	child: number,
	index: number,
	item: number,
	targets: number,
}

export type CacheValue = number | string

export type EnumDef = {
	key_type: string,
	value_type: string,
	default: CacheValue?,
	entries: { { key: number, value: CacheValue } },
}

export type SubInterface = {
	group: number,
	parent: number,
	parent_group: number,
	parent_child: number,
}

-- Whether a tile can be reached by walking and climbing. `known` is false when one end has no landmass (an instance, say), and then `reachable` is true for lack of knowing better. `from` and `to` are the first climb on the way, when one is needed.
export type WorldRoute = {
	known: boolean,
	reachable: boolean,
	from: NavTile?,
	to: NavTile?,
}

export type Widget = {
	id: number,
	group: number,
	child: number,
	kind: number,
	x: number,
	y: number,
	width: number,
	height: number,
	parent: number,
	sprite: number,
	index: number,
	hidden: boolean,
	text: string?,
	text_color: number,
	scroll_x: number,
	scroll_y: number,
	scroll_width: number,
	scroll_height: number,
	-- the first menu option ("Close"; the port's name on a map marker), nil when it has none
	action: string?,
}

export type ItemSlot = {
	slot: number,
	id: number,
	quantity: number,
}

-- One write the client made to an item container slot that changed it. An empty slot is item -1, quantity 0.
export type ItemChange = {
	sequence: number,
	time_ms: number,
	tick: number?,
	container: number,
	slot: number,
	-- false when the write created the container
	old_known: boolean,
	old_item: number,
	old_quantity: number,
	new_item: number,
	new_quantity: number,
}

-- One packet the client received from the server, or sent to it.
export type Packet = {
	sequence: number,
	-- milliseconds since the agent started logging: only good for ordering and spacing packets
	time_ms: number,
	-- true for a packet the client sent
	sent: boolean,
	-- the server packet id (received) or the client packet id (sent)
	opcode: number,
	-- the whole payload length; `payload` has at most the first 104 bytes
	length: number,
	-- the payload's bytes, read with string.byte or buffer.fromstring
	payload: string,
}

-- The tile the server last put you on (world coordinates).
export type ServerTile = {
	x: number,
	y: number,
	plane: number?,
	-- steps of the path the client still has to animate, not what is left of your route
	steps: number,
}

-- Your server tile and when it last changed, as the agent saw it before taking each packet.
export type MovementState = {
	x: number,
	y: number,
	plane: number?,
	-- the tile before the last change
	from_x: number,
	from_y: number,
	from_plane: number?,
	-- the tile changed in the tick being received or in the last one that ended
	moving: boolean,
	-- the client's tick counter when the tile last changed; nil if it hasn't since the agent first saw you
	moved_tick: number?,
	-- the client's tick counter now
	tick: number,
}

export type Npc = {
	index: number,
	id: number,
	name: string,
	x: number,
	y: number,
	local_x: number,
	local_y: number,
	animation: number,
	-- the actor it interacts with: an npc index or a player index (-1 for the other kind or none)
	interacting_npc: number,
	interacting_player: number,
}

-- A hitsplat on an actor: its type, the damage it shows and the client cycle it was added on.
export type Hitsplat = {
	-- which of the four slots it is in
	slot: number,
	kind: number,
	damage: number,
	cycle: number,
}

export type NpcModel = {
	bounding_box: boolean,
	orientation: number,
	vertex_count: number,
	corners: { ScreenPoint },
	hull: { ScreenPoint },
	faces: { { ScreenPoint } },
}

export type Loc = {
	id: number,
	name: string?,
	kind: number,
	x: number,
	y: number,
	plane: number,
	scene_x: number,
	scene_y: number,
	size_x: number,
	size_y: number,
	shape: number?,
	rotation: number?,
	clickable: boolean,
}

-- A loc the game cache places on the map, whether or not its map square is loaded; `actions` are its menu options in order
-- An object as the player sees it now: a multi-state object (a farming patch, a door that opens) shows the form its varbit or varp picks. Empty for an id the cache doesn't know.
export type LocView = {
	name: string,
	-- its right-click options now, in menu order
	actions: { string },
}

export type CacheLoc = {
	id: number,
	name: string,
	x: number,
	y: number,
	plane: number,
	size_x: number,
	size_y: number,
	shape: number,
	rotation: number,
	actions: { string },
}

-- what `cache_locs` keeps; every field is optional
export type CacheLocFilter = {
	plane: number?,
	-- part of the name, any case
	names: { string }?,
	-- the whole menu option, any case: a loc with any of them is kept
	actions: { string }?,
}

export type GroundItem = {
	id: number,
	quantity: number,
	name: string?,
	x: number,
	y: number,
	plane: number,
	scene_x: number,
	scene_y: number,
}

export type ChatMessage = {
	uid: number,
	kind: number,
	name: string,
	sender: string,
	text: string,
	cycle: number,
	age: number,
	time: number,
	time_utc: string,
	time_local: string,
}

export type PlayerInfo = {
	index: number,
	name: string,
	x: number,
	y: number,
	local_x: number,
	local_y: number,
	-- the animation id (-1 when none), the pose (walk or stand) animation and the spot animation
	animation: number,
	pose: number,
	graphic: number,
	-- interaction target: state (0 npc, 1 loc, 2 gone, 3 done, -1 unknown), npc index, loc world tile (-1 if none)
	target_state: number,
	target_npc: number,
	target_x: number,
	target_y: number,
	-- the actor it interacts with (follow, talk, attack): an npc or player index, -1 for the other kind or none
	interacting_npc: number,
	interacting_player: number,
}

-- A projectile in flight (an arrow, a bolt, a spell). Tiles are world tiles; heights are fine units above the ground.
export type Projectile = {
	-- the spot animation (graphic) id
	id: number,
	-- where it flies from and to, as the server sent it
	source_x: number,
	source_y: number,
	source_plane: number,
	target_x: number,
	target_y: number,
	target_plane: number,
	-- the actors it flies from and at, -1 for none (the server often sends only a source tile); it follows a target actor
	source_npc: number,
	source_player: number,
	target_npc: number,
	target_player: number,
	start_height: number,
	end_height: number,
	slope: number,
	start_pos: number,
	-- client cycles (50 a second): when it starts moving, when it lands, and now
	start_cycle: number,
	end_cycle: number,
	cycle: number,
	-- false while it waits to leave; until then the position is the source tile's centre
	moving: boolean,
	-- world tile, local fine coordinates, raw z (negative is up), orientation (0-2047) and height above the ground
	x: number,
	y: number,
	local_x: number,
	local_y: number,
	z: number,
	orientation: number,
	height: number,
}

-- A spot animation (RuneLite: graphics object) on a tile: an impact, a splash, a teleport flash. Tiles are world tiles.
export type SpotAnim = {
	-- the spot animation (graphic) id
	id: number,
	-- the world tile and plane it is on (for a spot anim inside a boat, view_id ~= 0, the tile in the boat's own scene)
	x: number,
	y: number,
	plane: number,
	-- 0 for the main world; any other number is a moving sub-scene (a boat) whose coordinates are its own
	view_id: number,
	-- local fine coordinates (128 to a tile) and the client's raw z
	local_x: number,
	local_y: number,
	z: number,
	-- client cycles (50 a second): when it starts playing (later than now while it waits) and now
	start_cycle: number,
	cycle: number,
}

export type WindMouseOptions = {
	speed: number?,
	wind: number?,
	gravity: number?,
	timeout: number?,
	-- divides the wait between the move's points: 1.2 runs the same path 20% faster (host API 12)
	pace: number?,
}

export type Tile = {
	x: number,
	y: number,
}

export type SceneRoute = {
	tiles: { Tile },
	reached: boolean,
}

-- Part of the loaded scene's collision map: the flags of tile (x + i, y + j) are at `flags[i * height + j + 1]`.
export type Collision = {
	x: number,
	y: number,
	width: number,
	height: number,
	plane: number,
	flags: { number },
}

-- A tile and the plane it is on.
export type NavTile = {
	x: number,
	y: number,
	plane: number,
}

-- A loc a plan uses: a closed door to open or a ladder or staircase to climb, and the option that does it.
export type NavLoc = {
	id: number,
	x: number,
	y: number,
	plane: number,
	kind: number,
	size_x: number,
	size_y: number,
	option: string,
}

export type NavAction = {
	-- the index in `tiles` of the tile it is used from; the next tile is past it (on `to_plane` for a climb)
	at: number,
	kind: "door" | "climb",
	loc: NavLoc,
	to_plane: number,
}

export type NavPlan = {
	-- every tile walked, the start first
	tiles: { NavTile },
	-- in the order they come
	actions: { NavAction },
	-- false when it ends elsewhere: as close as it gets, or `goal` when the target is too far for one plan
	reached: boolean,
	goal: NavTile,
}

-- every field is optional (see docs/host.md)
export type NavOptions = {
	near: number?,
	door_options: { string }?,
	-- false stays on the plane (no ladders, stairs, ropes or cave mouths)
	climbs: boolean?,
	-- climbs that ask for something and that the player has what they ask for (see `Transports.allowed_climbs`); the ones that ask for nothing are always used
	allow_climbs: { string }?,
	-- the least (in tiles) an agility shortcut has to save over walking round (default 10)
	shortcut_saving: number?,
	avoid: { NavLoc }?,
	seed: number?,
	rnd: number?,
	door_cost: number?,
	climb_cost: number?,
}

-- passing these to `scene_route` randomizes the route (see docs/host.md); every field is optional
export type SceneRouteOptions = {
	seed: number?,
	rnd: number?,
	spacing: number?,
	jitter: number?,
	max_detour: number?,
	offset: number?,
}

export type Area = {
	x: number,
	y: number,
	width: number,
	height: number,
}

export type Corners = {
	x1: number,
	y1: number,
	x2: number,
	y2: number,
}

export type Shape =
	{
		kind: "rect" | "line",
		x1: number,
		y1: number,
		x2: number,
		y2: number,
		r: number,
		g: number,
		b: number,
		a: number?,
	}
	| { kind: "clear" }

-- What `Host.http_request` takes. Only hosts on the whitelist in the loader's settings can be reached.
export type HttpRequest = {
	url: string,
	-- "GET" when not given
	method: string?,
	headers: { [string]: string }?,
	body: string?,
	-- milliseconds the whole request may take, redirects included (15000 when not given, 60000 at most)
	timeout: number?,
}

export type HttpResponse = {
	-- true for a status from 200 to 299
	ok: boolean,
	status: number,
	-- lowercase names; a header sent more than once is joined with ", "
	headers: { [string]: string },
	body: string,
}

local g = _G :: any

return {
	game_state = g.game_state :: () -> ClientState,
	connection = g.connection :: () -> Connection,
	widget = g.widget :: (group: number, child: number) -> Widget?,
	widget_model = g.widget_model :: (group: number, child: number) -> { kind: number, id: number }?,
	widget_children = g.widget_children :: (group: number, child: number) -> { Widget }?,
	item_container = g.item_container :: (id: number) -> { ItemSlot }?,
	on_item_change = g.on_item_change :: ((change: ItemChange) -> ()) -> number,
	off_item_change = g.off_item_change :: (id: number) -> boolean,
	wait_item_change = g.wait_item_change :: (ms: number) -> boolean,
	on_packet = g.on_packet :: (opcodes: { number }, callback: (packet: Packet) -> (), sent: boolean?) -> number,
	off_packet = g.off_packet :: (id: number) -> boolean,
	wait_packet = g.wait_packet :: (opcodes: { number }, ms: number, sent: boolean?) -> Packet?,
	project = g.project :: (
		points: { FinePoint },
		via: ("auto" | "local" | "client")?,
		shift: { x: number, y: number, plane: number? }?
	) -> { ScreenPoint }?,
	form = g.form :: (spec: FormSpec) -> { [string]: any }?,
	form_update = g.form_update :: () -> { [string]: any }?,
	menu = g.menu :: () -> { MenuEntry }?,
	menu_click = g.menu_click :: () -> MenuClick?,
	menu_open = g.menu_open :: () -> boolean,
	menu_layout = g.menu_layout :: () -> MenuLayout?,
	sub_interfaces = g.sub_interfaces :: () -> { SubInterface }?,
	game_val_name = g.game_val_name :: (kind: number, id: number) -> string?,
	game_val_names = g.game_val_names :: (kind: number, ids: { number }) -> { string? }?,
	item_name = g.item_name :: (id: number) -> string?,
	item_names = g.item_names :: (ids: { number }) -> { string? }?,
	varc = g.varc :: (id: number) -> number?,
	varp = g.varp :: (id: number) -> number?,
	varps = g.varps :: () -> { number }?,
	varbit = g.varbit :: (id: number) -> number?,
	enum_def = g.enum_def :: (id: number) -> EnumDef?,
	-- the landmass number of each `{ x, y, plane }` (0: none, or not the surface plane): tiles with the same number can be walked between, with doors open (no stairs or shortcuts). The first call after a game update builds them from the map, which takes a few seconds
	landmasses = g.landmasses :: (points: { { x: number, y: number, plane: number } }) -> ({ number }?, string?),
	-- one file of the client's cache as a string of its bytes (nil when it doesn't exist): scripts are index 12 (archive = script id, file 0), config files index 2
	-- several files of one cache index at once, `{ { archive, file }, ... }`: a string of bytes for each that exists and false for each that doesn't
	cache_files = g.cache_files :: (index: number, files: { { number } }) -> ({ string | boolean }?, string?),
	cache_file = g.cache_file :: (index: number, archive: number, file: number) -> (string?, string?),
	item_params = g.item_params :: (ids: { number }) -> { { [number]: CacheValue }? }?,
	selected_widget = g.selected_widget :: () -> SelectedWidget?,
	npcs = g.npcs :: () -> { Npc }?,
	npc_model = g.npc_model :: (index: number) -> NpcModel?,
	npc_sizes = g.npc_sizes :: (indices: { number }) -> { [number]: number }?,
	npc_hitsplats = g.npc_hitsplats :: (indices: { number }) -> { [number]: { Hitsplat } }?,
	locs = g.locs :: (plane: number?) -> { Loc }?,
	-- how each object id looks to the player now (see `LocView`), in the order given; nil when the cache can't be read
	loc_shown = g.loc_shown :: (ids: { number }) -> { LocView }?,
	cache_locs = g.cache_locs :: (area: Corners, filter: CacheLocFilter?) -> { CacheLoc }?,
	ground_items = g.ground_items :: () -> { GroundItem }?,
	projectiles = g.projectiles :: () -> { Projectile }?,
	spot_anims = g.spot_anims :: () -> { SpotAnim }?,
	map_regions = g.map_regions :: () -> { { number } }?,
	in_instance = g.in_instance :: () -> boolean?,
	server_tile = g.server_tile :: () -> ServerTile?,
	movement = g.movement :: () -> MovementState?,
	chat_messages = g.chat_messages :: () -> { ChatMessage }?,
	find_path = g.find_path :: (from: Tile, to: Tile, plane: number?, max_tiles: number?) -> { Tile }?,
	collision = g.collision :: (area: Corners?) -> Collision?,
	scene_route = g.scene_route :: (from: Tile, to: Tile, options: SceneRouteOptions?) -> SceneRoute?,
	transport_settings = g.transport_settings :: () -> { off: { string } },
	world_route = g.world_route :: (from: NavTile, to: NavTile, allow_climbs: { string }?) -> WorldRoute?,
	nav_plan = g.nav_plan :: (from: Tile | NavTile, to: Tile | NavTile, options: NavOptions?) -> (NavPlan?, string?),
	loc_model = g.loc_model :: (loc: Loc) -> NpcModel?,
	players = g.players :: () -> { PlayerInfo }?,
	player_model = g.player_model :: (index: number) -> NpcModel?,
	world_select = g.world_select :: () -> WorldSelect?,

	click = g.click :: (x: number, y: number, button: string?, hold_ms: number?) -> (),
	move = g.move :: (x: number, y: number) -> (),
	wind_mouse = g.wind_mouse :: (x: number, y: number, options: WindMouseOptions?) -> (),
	mouse_down = g.mouse_down :: (button: string?) -> (),
	mouse_up = g.mouse_up :: (button: string?) -> (),
	scroll = g.scroll :: (notches: number) -> (),
	key_down = g.key_down :: (key: number) -> (),
	key_up = g.key_up :: (key: number) -> (),
	type_text = g.type_text :: (text: string, hold_ms: number?) -> (),
	click_async = g.click_async :: (x: number, y: number, button: string?, hold_ms: number?) -> (),
	move_async = g.move_async :: (x: number, y: number) -> (),
	wind_mouse_async = g.wind_mouse_async :: (x: number, y: number, options: WindMouseOptions?) -> (),
	type_text_async = g.type_text_async :: (text: string, hold_ms: number?) -> (),
	mouse_down_async = g.mouse_down_async :: (button: string?) -> (),
	mouse_up_async = g.mouse_up_async :: (button: string?) -> (),
	scroll_async = g.scroll_async :: (notches: number) -> (),
	key_down_async = g.key_down_async :: (key: number) -> (),
	key_up_async = g.key_up_async :: (key: number) -> (),
	sleep_async = g.sleep_async :: (ms: number) -> (),
	input_busy = g.input_busy :: () -> boolean,
	input_wait = g.input_wait :: () -> string?,
	input_error = g.input_error :: () -> string?,
	input_cancel = g.input_cancel :: () -> (),
	-- Enters the account's bank PIN on the open keypad; the PIN lives in the injector and is never shown to the script.
	bank_pin_enter = g.bank_pin_enter :: () -> string,
	lamp_skill = g.lamp_skill :: () -> (string?, string?),
	-- Makes an HTTP request through the loader, to a host on the loader's whitelist. Needs no client.
	http_request = g.http_request :: (options: HttpRequest) -> (HttpResponse?, string?),
	draw_rect = g.draw_rect :: (
		x1: number,
		y1: number,
		x2: number,
		y2: number,
		r: number,
		g: number,
		b: number,
		a: number?
	) -> (),
	draw_line = g.draw_line :: (
		x1: number,
		y1: number,
		x2: number,
		y2: number,
		r: number,
		g: number,
		b: number,
		a: number?
	) -> (),
	draw_lines = g.draw_lines :: (lines: { { number } }, r: number, g: number, b: number, a: number?) -> (),
	clear_overlay = g.clear_overlay :: () -> (),
	draw_batch = g.draw_batch :: (shapes: { Shape }) -> (),
	sleep = g.sleep :: (ms: number) -> (),
	time = g.time :: () -> number,
	clock = g.clock :: () -> number,
	unix_time = g.unix_time :: () -> number,
	antiban_skips = g.antiban_skips :: () -> { { kind: string, index: number } },
	antiban_config = g.antiban_config :: () -> AntibanConfig,
	transports = g.transports :: () -> TransportsData,
	murmur2a = g.murmur2a :: (text: string, seed: number?) -> number,
	biometrics_profile = g.biometrics_profile :: (name: string) -> { number },
	report_counters = g.report_counters :: (counters: { Counter }) -> (),
	report_warning = g.report_warning :: (text: string) -> (),
	report_breaks = g.report_breaks :: (plan: BreakPlan) -> (),
	report_stats = g.report_stats :: (experience: number, gold: number, custom: { number }?) -> (),
}
