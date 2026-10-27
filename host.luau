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
	kind: ("label" | "check" | "number" | "text" | "choice")?,
	label: string?,
	text: string?,
	default: any?,
	options: { string }?,
	min: number?,
	max: number?,
	step: number?,
	integer: boolean?,
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

export type Npc = {
	index: number,
	id: number,
	name: string,
	x: number,
	y: number,
	local_x: number,
	local_y: number,
	animation: number,
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

local g = _G :: any

return {
	game_state = g.game_state :: () -> ClientState,
	connection = g.connection :: () -> Connection,
	widget = g.widget :: (group: number, child: number) -> Widget?,
	widget_children = g.widget_children :: (group: number, child: number) -> { Widget }?,
	item_container = g.item_container :: (id: number) -> { ItemSlot }?,
	project = g.project :: (
		points: { FinePoint },
		via: ("auto" | "local" | "client")?,
		shift: { x: number, y: number }?
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
	locs = g.locs :: () -> { Loc }?,
	cache_locs = g.cache_locs :: (area: Corners, filter: CacheLocFilter?) -> { CacheLoc }?,
	ground_items = g.ground_items :: () -> { GroundItem }?,
	map_regions = g.map_regions :: () -> { { number } }?,
	in_instance = g.in_instance :: () -> boolean?,
	chat_messages = g.chat_messages :: () -> { ChatMessage }?,
	find_path = g.find_path :: (from: Tile, to: Tile, plane: number?, max_tiles: number?) -> { Tile }?,
	scene_route = g.scene_route :: (from: Tile, to: Tile, options: SceneRouteOptions?) -> SceneRoute?,
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
