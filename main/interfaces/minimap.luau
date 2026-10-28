--!strict
local Host = require("../../host")
local game_state = Host.game_state
local widget = Host.widget
local sleep_async = Host.sleep_async
type ClientState = Host.ClientState
type CameraState = Host.CameraState
type MinimapState = Host.MinimapState
type Widget = Host.Widget
local Geometry = require("../../utils/math/geometry")
local Point = Geometry.Point
local Circle = Geometry.Circle
type Point = Geometry.Point
local Projection = require("../projection/projection")
type Tile = Projection.Tile
local Log = require("../../utils/log")
local Mouse = require("../../utils/input/mouse")
local Random = require("../../utils/math/random")

local Minimap = {}

local TURN = 16384

Minimap.ZOOM_MIN = 2
Minimap.ZOOM_MAX = 8

Minimap.COMPONENTS = {
	[161] = 30,
	[164] = 30,
	[548] = 22,
}

local function f32(x: number): number
	local value = string.unpack("<f", string.pack("<f", x))
	return value :: number
end

local function trunc(x: number): number
	return if x < 0 then math.ceil(x) else math.floor(x)
end

local SIN: { number } = {}
local COS: { number } = {}
do
	local step = f32(2 * math.pi / TURN)
	for i = 0, TURN - 1 do
		local radians = f32(i * step)
		SIN[i] = trunc(math.sin(radians) * 65536)
		COS[i] = trunc(math.cos(radians) * 65536)
	end
end

local function logged_in(): (ClientState?, CameraState?, MinimapState?)
	local state = game_state()
	if state.camera == nil or state.minimap == nil then
		return nil, nil, nil
	end
	return state, state.camera, state.minimap
end

function Minimap.state(): MinimapState?
	local _, _, minimap = logged_in()
	return minimap
end

function Minimap.zoom(): number?
	local minimap = Minimap.state()
	return if minimap then minimap.zoom else nil
end

function Minimap.widget(state: ClientState?): Widget?
	local s = state or game_state()
	local root = s.root_interface
	local child = if root then Minimap.COMPONENTS[root] else nil
	if child == nil then
		return nil
	end
	local w = widget(root :: number, child)
	if w == nil then
		return nil
	end
	return w
end

local function units(canvas: number, scale: number): number
	return math.ceil(canvas / scale - 1e-4)
end

function Minimap.fine_to_point(fine_x: number, fine_y: number): Point?
	local state, camera, minimap = logged_in()
	if state == nil or camera == nil or minimap == nil then
		return nil
	end
	local scale = state.ui_scale
	local w = Minimap.widget(state)
	if w == nil or scale == nil then
		return nil
	end

	local size = f32(f32(4 / minimap.zoom) * 32)
	local function pixels(fine: number): number
		return trunc(f32(f32(fine) / size))
	end
	local dx = pixels(fine_x) - pixels(camera.focal_x)
	local dy = pixels(fine_y) - pixels(camera.focal_y)
	local sin, cos = SIN[camera.yaw], COS[camera.yaw]
	local x = (cos * dx + sin * dy) // 65536
	local y = (cos * dy - sin * dx) // 65536

	local left, top = units(w.x, scale), units(w.y, scale)
	local width = units(w.x + w.width, scale) - left
	local height = units(w.y + w.height, scale) - top
	local ux = left + trunc(width / 2) + x
	local uy = top + trunc(height / 2) - y
	return Point.new(math.floor((ux + 0.5) * scale), math.floor((uy + 0.5) * scale))
end

function Minimap.tile_to_point(tile: Tile): Point?
	local base = Projection.base()
	if base == nil then
		return nil
	end
	local half = Projection.TILE // 2
	return Minimap.fine_to_point((tile.x - base.x) * Projection.TILE + half, (tile.y - base.y) * Projection.TILE + half)
end

-- Queues single scroll notches, one per level, towards `zoom` over the minimap and returns at once; open loop.
function Minimap.set_zoom_async(zoom: number): boolean
	local target = math.clamp(math.round(zoom), Minimap.ZOOM_MIN, Minimap.ZOOM_MAX)
	local state, _, minimap = logged_in()
	if state == nil or minimap == nil then
		return false
	end
	if minimap.zoom == target then
		return true
	end
	local w = Minimap.widget(state)
	if w == nil then
		return false
	end
	local area = Circle.new(w.x + w.width // 2, w.y + w.height // 2, w.width * 0.3)
	local here = Mouse.position()
	local over = if here == nil or not Circle.contains(area, here) then area else nil
	local down = minimap.zoom > target
	for i = 1, math.abs(minimap.zoom - target) do
		if i > 1 then
			sleep_async(Random.int(60, 140))
		end
		Mouse.scroll_async(1, down, if i == 1 then over else nil)
	end
	return true
end

function Minimap.set_zoom(zoom: number): boolean
	local target = math.clamp(math.round(zoom), Minimap.ZOOM_MIN, Minimap.ZOOM_MAX)
	local state, camera, minimap = logged_in()
	if state == nil or camera == nil or minimap == nil then
		return false
	end
	if minimap.zoom == target then
		return true
	end
	local w = Minimap.widget(state)
	if w == nil then
		return false
	end
	local center = Point.new(w.x + w.width // 2, w.y + w.height // 2)
	local area = Circle.new(center.x, center.y, w.width * 0.3)
	local here = Mouse.position()
	if here == nil or not Circle.contains(area, here) then
		Mouse.move(area)
	end

	local current, camera_zoom = minimap.zoom, camera.zoom
	local stuck = 0
	for _ = 1, 60 do
		if current == target then
			return true
		end
		Mouse.scroll(1, current > target)
		Random.sleep(60, 140)
		local now_state, now_camera, now_minimap = logged_in()
		if now_state == nil or now_camera == nil or now_minimap == nil then
			return false
		end
		if now_camera.zoom ~= camera_zoom then
			return false
		end
		stuck = if now_minimap.zoom == current then stuck + 1 else 0
		if stuck >= 8 then
			Log.log("Minimap", `the minimap zoom stopped at {now_minimap.zoom}`)
			return false
		end
		current = now_minimap.zoom
	end
	Log.log("Minimap", "the minimap didn't reach the zoom")
	return false
end

return Minimap
