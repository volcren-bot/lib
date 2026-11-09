--!strict
local Host = require("@lib/host")
local game_state = Host.game_state
local sub_interfaces = Host.sub_interfaces
local widget = Host.widget
local sleep = Host.sleep
local varbit = Host.varbit
type Widget = Host.Widget
local Biometrics = require("@lib/main/antiban/biometrics")
local GameVal = require("@lib/utils/game_val")
local Geometry = require("@lib/utils/math/geometry")
local Keyboard = require("@lib/utils/input/keyboard")
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Random = require("@lib/utils/math/random")
local Box = Geometry.Box
type Box = Geometry.Box
type Point = Geometry.Point

export type Slot = "modal" | "crm" | "floater"

export type Open = {
	group: number,
	slot: Slot,
}

local Toplevel = {}

Toplevel.SLOTS = {
	[161] = { modal = 16, crm = 17, floater = 18 },
	[164] = { modal = 16, crm = 17, floater = 18 },
	[165] = { modal = 14, crm = 15, floater = 41 },
	[548] = { modal = 41, crm = 42, floater = 43 },
}

Toplevel.LAYOUT = {
	[161] = { viewport = 91, blockers = { 95, 96, 97 } },
	[164] = { viewport = 88, blockers = { 92, 93, 96 } },
	[548] = { viewport = 26, blockers = {} },
}

local ORDER: { Slot } = { "modal", "floater", "crm" }

local function interfaces_of(root: number?): { Open }?
	if root == nil then
		return {}
	end
	local slots = Toplevel.SLOTS[root]
	if slots == nil then
		return nil
	end
	local open = sub_interfaces()
	if open == nil then
		return nil
	end
	local found: { Open } = {}
	for _, slot: Slot in ORDER do
		for _, s in open do
			if s.parent_group == root and s.parent_child == slots[slot] then
				table.insert(found, { group = s.group, slot = slot })
			end
		end
	end
	return found
end

local function root(): number?
	return game_state().root_interface
end

function Toplevel.interfaces(): { Open }?
	return interfaces_of(root())
end

function Toplevel.interface(): number?
	local open = Toplevel.interfaces()
	if open == nil then
		return nil
	end
	return if open[1] then open[1].group else nil
end

function Toplevel.interface_name(): string?
	local group = Toplevel.interface()
	if group == nil then
		return nil
	end
	return GameVal.interface(group)
end

function Toplevel.has_interface(): boolean
	local open = Toplevel.interfaces()
	if open == nil then
		return false
	end
	return #open > 0
end

local ESC_TO_CLOSE_VARBIT = 4681
local CLOSE_POLL_MS = 100
local CLOSE_TIMEOUT_MS = 1800
local CLOSE_CLEAR_MS = 600

local function wait_for(closed: () -> boolean, timeout_ms: number): boolean
	local waited = 0
	while waited < timeout_ms do
		sleep(CLOSE_POLL_MS)
		waited += CLOSE_POLL_MS
		if closed() then
			return true
		end
	end
	return false
end

Toplevel.ESCAPE_TRIES = 3
Toplevel.ESCAPE_PAUSE_MS = { 150, 400 }
local escape_disabled = false

function Toplevel.escape_enabled(): boolean
	return not escape_disabled
end

function Toplevel.reset_escape()
	escape_disabled = false
end

local function escape_close(closed: () -> boolean, timeout_ms: number, name: () -> string): boolean
	if escape_disabled then
		return false
	end
	for attempt = 1, Toplevel.ESCAPE_TRIES do
		Keyboard.key_press(Keyboard.keys.ESCAPE)
		if wait_for(closed, timeout_ms) then
			return true
		end
		if attempt < Toplevel.ESCAPE_TRIES then
			sleep(Random.range(Toplevel.ESCAPE_PAUSE_MS[1], Toplevel.ESCAPE_PAUSE_MS[2]))
		end
	end
	escape_disabled = true
	Log.warn(
		"Toplevel",
		`Escape to close has been disabled because it failed {Toplevel.ESCAPE_TRIES} times closing interface {name()}, only the mouse will close interfaces from now on`
	)
	return false
end

function Toplevel.escape_clear(timeout_ms: number?): boolean
	if not Toplevel.has_interface() then
		return true
	end
	return escape_close(
		function()
			return not Toplevel.has_interface()
		end,
		timeout_ms or CLOSE_CLEAR_MS,
		function()
			return Toplevel.interface_name() or tostring(Toplevel.interface())
		end
	)
end

function Toplevel.close(
	group: number | string,
	button: () -> Widget?,
	key_probability: number?,
	timeout_ms: number?
): boolean
	if not Toplevel.is_open(group) then
		return true
	end
	local timeout = timeout_ms or CLOSE_TIMEOUT_MS
	local probability = key_probability or Biometrics.get_probability(Biometrics.ESCAPE)
	local function closed(): boolean
		return not Toplevel.is_open(group)
	end
	if varbit(ESC_TO_CLOSE_VARBIT) ~= 0 and not escape_disabled and Random.chance(probability) then
		local function name(): string
			if type(group) == "string" then
				return group
			end
			return GameVal.interface(group) or tostring(group)
		end
		if escape_close(closed, timeout, name) then
			return true
		end
	end

	for _ = 1, 3 do
		local close = button()
		if close == nil then
			Log.log("Toplevel", "the close button isn't available")
			return false
		end
		Mouse.click(close)
		if wait_for(closed, timeout) then
			return true
		end
	end
	Log.log("Toplevel", "the interface didn't close")
	return false
end

function Toplevel.is_open(interface: number | string): boolean
	local open = Toplevel.interfaces()
	if open == nil then
		return false
	end
	local wanted = if type(interface) == "string" then string.lower(interface) else nil
	for _, o in ipairs(open) do
		if o.group == interface then
			return true
		end
		if wanted then
			local name = GameVal.interface(o.group)
			if name and string.lower(name) == wanted then
				return true
			end
		end
	end
	return false
end

local function box_of(group: number, child: number): Box?
	local w = widget(group, child)
	return if w then Box.from_area(w) else nil
end

function Toplevel.viewport(): Box?
	local top = root()
	if top == nil then
		return nil
	end
	local layout = Toplevel.LAYOUT[top]
	if layout == nil then
		return nil
	end
	return box_of(top, layout.viewport)
end

local function panel_blockers_of(top: number?): { Box }?
	if top == nil then
		return nil
	end
	local layout = Toplevel.LAYOUT[top]
	if layout == nil then
		return nil
	end
	local boxes: { Box } = {}
	for _, child in ipairs(layout.blockers) do
		local b = box_of(top, child)
		if b then
			table.insert(boxes, b)
		end
	end
	return boxes
end

function Toplevel.panel_blockers(): { Box }?
	return panel_blockers_of(root())
end

function Toplevel.blockers(): { Box }?
	local top = root()
	local boxes = panel_blockers_of(top)
	if boxes == nil then
		return nil
	end
	local open = interfaces_of(top)
	for _, o in ipairs(open or {}) do
		local b = box_of(o.group, 0)
		if b then
			table.insert(boxes, b)
		end
	end
	return boxes
end

function Toplevel.is_visible(p: Point, viewport: Box?, blockers: { Box }?): boolean
	local view = viewport or Toplevel.viewport()
	if view == nil or not Box.contains(view, p) then
		return false
	end
	for _, b in ipairs(blockers or Toplevel.blockers() or {}) do
		if Box.contains(b, p) then
			return false
		end
	end
	return true
end

function Toplevel.visible_point(area: Box): Point?
	local view = Toplevel.viewport()
	if view == nil then
		return nil
	end
	local blockers = Toplevel.blockers() or {}
	local center = Box.center(area)
	local best: Point? = nil
	local best_distance = math.huge
	local steps = 6
	for i = 0, steps do
		for j = 0, steps do
			local p = Geometry.Point.new(
				math.round(area.x1 + (area.x2 - area.x1) * i / steps),
				math.round(area.y1 + (area.y2 - area.y1) * j / steps)
			)
			if Toplevel.is_visible(p, view, blockers) then
				local d = Geometry.Point.distance(p, center)
				if d < best_distance then
					best, best_distance = p, d
				end
			end
		end
	end
	return best
end

return Toplevel
