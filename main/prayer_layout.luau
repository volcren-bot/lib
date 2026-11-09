--!strict
local Host = require("@lib/host")
type PrayerLayout = Host.PrayerLayout
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Prayer = require("@lib/main/interfaces/gametabs/prayer")
local Varbits = require("@lib/main/varbits")
local Widgets = require("@lib/main/interfaces/widgets")

local PrayerLayout = {}

export type Layout = PrayerLayout

PrayerLayout.CONFIRM_MS = 1200
PrayerLayout.ATTEMPTS = 3
PrayerLayout.MOUSE_PACE = 1.2

local POLL_MS = 50

local function infos(layout: Layout): { Prayer.Info }
	local list: { Prayer.Info } = {}
	for _, key in ipairs(layout.prayers) do
		local p = Prayer.prayer(key)
		if p then
			table.insert(list, p)
		end
	end
	return list
end

local function wanted_of(layout: Layout)
	local list = infos(layout)
	local wanted: { [string]: boolean } = {}
	for _, p in ipairs(list) do
		wanted[p.key] = true
	end
	return list, wanted
end

local function controlled(layout: Layout): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, key in ipairs(layout.locked or {}) do
		set[key] = true
	end
	return set
end

local function is_on(p: Prayer.Info): boolean
	return Varbits.get(p.varbit) == 1
end

local function replaced(p: Prayer.Info): boolean
	for _, other in ipairs(Prayer.PRAYERS) do
		if other.replaces == p.key and Prayer.is_unlocked(other) then
			return true
		end
	end
	return false
end

function PrayerLayout.from_client(name: string?, quick: boolean?): Layout
	local prayers: { string } = {}
	for _, p in ipairs(Prayer.PRAYERS) do
		local held = if quick
			then Prayer.is_quick_selected(p) and not replaced(p) and (p.replaces == nil or Prayer.is_unlocked(p))
			else is_on(p)
		if held then
			table.insert(prayers, p.key)
		end
	end
	return { name = name or "From client", prayers = prayers }
end

function PrayerLayout.is_active(layout: Layout): boolean
	local _, wanted = wanted_of(layout)
	local skip = controlled(layout)
	for _, p in ipairs(Prayer.PRAYERS) do
		if not skip[p.key] and is_on(p) ~= (wanted[p.key] == true) then
			return false
		end
	end
	return true
end

function PrayerLayout.is_quick(layout: Layout): boolean
	local wanted: { [string]: boolean } = {}
	for _, p in ipairs(infos(layout)) do
		wanted[p.replaces or p.key] = true
	end
	local skip = controlled(layout)
	for _, p in ipairs(Prayer.PRAYERS) do
		if p.replaces == nil and not skip[p.key] and Prayer.is_quick_selected(p) ~= (wanted[p.key] == true) then
			return false
		end
	end
	return true
end

local function click_all(list: { Prayer.Info }): boolean
	if not Prayer.open() then
		return false
	end
	local slots: { Host.Widget } = {}
	for _, p in ipairs(list) do
		local w = Prayer.widget(p)
		if w == nil or w.hidden then
			Log.log("PrayerLayout", `the {p.name} slot isn't visible, check the prayer filters`)
			return false
		end
		table.insert(slots, w)
	end
	local pace = Mouse.pace
	Mouse.pace = pace * PrayerLayout.MOUSE_PACE
	local at = Mouse.position()
	local queued = true
	while #slots > 0 do
		local nearest, best = 1, math.huge
		if at then
			for i, w in ipairs(slots) do
				local d = (w.x + w.width / 2 - at.x) ^ 2 + (w.y + w.height / 2 - at.y) ^ 2
				if d < best then
					nearest, best = i, d
				end
			end
		end
		local w = table.remove(slots, nearest)
		if not Mouse.click_async(w, nil, true) then
			queued = false
			break
		end
		at = { x = w.x + w.width / 2, y = w.y + w.height / 2 }
	end
	Mouse.pace = pace
	if not queued then
		Mouse.cancel()
		return false
	end
	return Mouse.wait()
end

local function wait_states(list: { Prayer.Info }, on: boolean)
	Widgets.wait_within(function(): boolean
		for _, p in ipairs(list) do
			if is_on(p) ~= on then
				return false
			end
		end
		return true
	end, PrayerLayout.CONFIRM_MS, POLL_MS)
end

local function names(list: { Prayer.Info }): string
	local out: { string } = {}
	for _, p in ipairs(list) do
		table.insert(out, p.name)
	end
	return table.concat(out, ", ")
end

function PrayerLayout.activate(layout: Layout): boolean
	local list, wanted = wanted_of(layout)
	local skip = controlled(layout)
	for attempt = 1, PrayerLayout.ATTEMPTS + 1 do
		if PrayerLayout.is_active(layout) then
			return true
		end
		local turn_on: { Prayer.Info } = {}
		for _, p in ipairs(list) do
			if not is_on(p) then
				table.insert(turn_on, p)
			end
		end
		local turn_off: { Prayer.Info } = {}
		if #turn_on == 0 then
			for _, p in ipairs(Prayer.PRAYERS) do
				if not wanted[p.key] and not skip[p.key] and is_on(p) then
					table.insert(turn_off, p)
				end
			end
		end
		if attempt > PrayerLayout.ATTEMPTS then
			if #turn_on > 0 then
				Log.log("PrayerLayout", `activate: {names(turn_on)} won't stay on`)
			else
				Log.log("PrayerLayout", `activate: {names(turn_off)} won't turn off`)
			end
			return false
		end
		for _, p in ipairs(turn_on) do
			if not Prayer.can_activate(p) then
				Log.log("PrayerLayout", `activate: can't turn on {p.name}`)
				return false
			end
		end
		local clicks = if #turn_on > 0 then turn_on else turn_off
		if not click_all(clicks) then
			return false
		end
		wait_states(clicks, #turn_on > 0)
	end
	return false
end

function PrayerLayout.deactivate(): boolean
	return Prayer.deactivate_all()
end

function PrayerLayout.set_quick(layout: Layout): boolean
	if PrayerLayout.is_quick(layout) then
		return true
	end
	local list = infos(layout)
	local skip = controlled(layout)
	for _, p in ipairs(Prayer.PRAYERS) do
		if p.replaces == nil and skip[p.key] and Prayer.is_quick_selected(p) then
			table.insert(list, p)
		end
	end
	return Prayer.set_quick_prayers(list) and PrayerLayout.is_quick(layout)
end

function PrayerLayout.quick(layout: Layout, active: boolean?): boolean
	if not PrayerLayout.set_quick(layout) then
		return false
	end
	return Prayer.set_quick_active(active ~= false)
end

return PrayerLayout
