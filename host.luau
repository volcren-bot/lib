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

export type FormField = {
	id: string?,
	kind: ("label" | "check" | "number" | "text" | "choice" | "list")?,
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
}

export type FormSpec = {
	title: string?,
	submit: string?,
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
	climb_options: { [string]: number }?,
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
	item_params = g.item_params :: (ids: { number }) -> { { [number]: CacheValue }? }?,
	selected_widget = g.selected_widget :: () -> SelectedWidget?,
	npcs = g.npcs :: () -> { Npc }?,
	npc_model = g.npc_model :: (index: number) -> NpcModel?,
	npc_sizes = g.npc_sizes :: (indices: { number }) -> { [number]: number }?,
	npc_hitsplats = g.npc_hitsplats :: (indices: { number }) -> { [number]: { Hitsplat } }?,
	locs = g.locs :: (plane: number?) -> { Loc }?,
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
	report_counters = g.report_counters :: (counters: { Counter }) -> (),
	report_breaks = g.report_breaks :: (plan: BreakPlan) -> (),
	report_stats = g.report_stats :: (experience: number, gold: number, custom: { number }?) -> (),
}
