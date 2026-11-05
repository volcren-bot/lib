--!strict
-- Prayer layouts: what a `prayer` form field gives a script (a set of prayers the user put together in the loader), turned on as the
-- regular prayers or made the quick prayers. The script picks which; the layout itself is only the set.
local Host = require("@lib/host")
local sleep = Host.sleep
local time = Host.time
type PrayerLayout = Host.PrayerLayout
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Prayer = require("@lib/main/interfaces/gametabs/prayer")
local Varbits = require("@lib/main/varbits")

local PrayerLayout = {}

export type Layout = PrayerLayout

-- After clicking prayers in `activate`: how long they get to show the change, how many rounds of clicks they get, and how many times
-- faster than `Mouse.pace` the mouse moves while it clicks.
PrayerLayout.CONFIRM_MS = 1200
PrayerLayout.ATTEMPTS = 3
PrayerLayout.MOUSE_PACE = 1.2

local POLL_MS = 50

-- The layout's prayers as the prayer tab knows them, skipping keys it doesn't (a layout from a newer loader).
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

-- Whether the prayer itself is on: unlike `Prayer.is_on`, a base prayer doesn't count as on while its upgrade is.
local function is_on(p: Prayer.Info): boolean
	return Varbits.get(p.varbit) == 1
end

-- A base prayer the account has upgraded is shown and selected as its upgrade.
local function replaced(p: Prayer.Info): boolean
	for _, other in ipairs(Prayer.PRAYERS) do
		if other.replaces == p.key and Prayer.is_unlocked(other) then
			return true
		end
	end
	return false
end

-- A layout of the prayers on now, or with `quick` of the quick prayer selection (an upgrade's bit is its base's: it counts as the upgrade once unlocked).
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

-- Whether exactly the layout's prayers are on: all of them, and no other.
function PrayerLayout.is_active(layout: Layout): boolean
	local wanted: { [string]: boolean } = {}
	for _, p in ipairs(infos(layout)) do
		wanted[p.key] = true
	end
	for _, p in ipairs(Prayer.PRAYERS) do
		if is_on(p) ~= (wanted[p.key] == true) then
			return false
		end
	end
	return true
end

-- Whether the quick prayers are exactly the layout's prayers, by their bits (an upgrade and its base share one).
function PrayerLayout.is_quick(layout: Layout): boolean
	local wanted: { [string]: boolean } = {}
	for _, p in ipairs(infos(layout)) do
		wanted[p.replaces or p.key] = true
	end
	for _, p in ipairs(Prayer.PRAYERS) do
		if p.replaces == nil and Prayer.is_quick_selected(p) ~= (wanted[p.key] == true) then
			return false
		end
	end
	return true
end

-- Queues a click on each prayer's slot, nearest the mouse first, with no wait between them, and waits for the mouse to finish.
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
	-- each queued move takes the pace it was queued with
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
		-- forced: the queue runs later, so where the mouse is now says nothing about where it will be
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

-- Waits for the prayers to show as `on` (or off); the game applies a click on its next tick.
local function wait_states(list: { Prayer.Info }, on: boolean)
	local deadline = time() + PrayerLayout.CONFIRM_MS
	while time() < deadline do
		local done = true
		for _, p in ipairs(list) do
			if is_on(p) ~= on then
				done = false
				break
			end
		end
		if done then
			return
		end
		sleep(POLL_MS)
	end
end

local function names(list: { Prayer.Info }): string
	local out: { string } = {}
	for _, p in ipairs(list) do
		table.insert(out, p.name)
	end
	return table.concat(out, ", ")
end

-- Turns the layout's prayers on and every other prayer off, through the prayer tab. The ones that are off are clicked with no wait between
-- them; the game turns off what they can't be used with, so the prayers still on that aren't in the layout are clicked off in a round after.
-- Each round waits up to `CONFIRM_MS` for the change, and whatever is still wrong gets more rounds, `ATTEMPTS` in all. True when exactly the layout's prayers are on.
function PrayerLayout.activate(layout: Layout): boolean
	local list = infos(layout)
	local wanted: { [string]: boolean } = {}
	for _, p in ipairs(list) do
		wanted[p.key] = true
	end
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
		-- only once the layout's are on: clicking one the game is about to turn off would turn it back on
		local turn_off: { Prayer.Info } = {}
		if #turn_on == 0 then
			for _, p in ipairs(Prayer.PRAYERS) do
				if not wanted[p.key] and is_on(p) then
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

-- Turns every prayer off. True when none is on afterwards.
function PrayerLayout.deactivate(): boolean
	return Prayer.deactivate_all()
end

-- Makes the layout's prayers the quick prayers, through the setup panel. True when the quick prayers are exactly them afterwards.
function PrayerLayout.set_quick(layout: Layout): boolean
	if PrayerLayout.is_quick(layout) then
		return true
	end
	return Prayer.set_quick_prayers(infos(layout)) and PrayerLayout.is_quick(layout)
end

-- Makes the layout the quick prayers and turns them on (or off with `active` false) with the orb.
function PrayerLayout.quick(layout: Layout, active: boolean?): boolean
	if not PrayerLayout.set_quick(layout) then
		return false
	end
	return Prayer.set_quick_active(active ~= false)
end

return PrayerLayout
