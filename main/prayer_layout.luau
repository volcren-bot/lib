--!strict
-- Prayer layouts: what a `prayer` form field gives a script (a set of prayers the user put together in the loader), turned on as the
-- regular prayers or made the quick prayers. The script picks which; the layout itself is only the set.
local Host = require("@lib/host")
type PrayerLayout = Host.PrayerLayout
local Prayer = require("@lib/main/interfaces/gametabs/prayer")
local Varbits = require("@lib/main/varbits")

local PrayerLayout = {}

export type Layout = PrayerLayout

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

-- Turns the layout's prayers on and every other prayer off, through the prayer tab. True when exactly they are on afterwards.
function PrayerLayout.activate(layout: Layout): boolean
	if PrayerLayout.is_active(layout) then
		return true
	end
	local wanted: { [string]: boolean } = {}
	for _, p in ipairs(infos(layout)) do
		wanted[p.key] = true
	end
	local others: { Prayer.Info } = {}
	for _, p in ipairs(Prayer.PRAYERS) do
		if not wanted[p.key] and is_on(p) then
			table.insert(others, p)
		end
	end
	-- off first: turning a prayer on turns off the ones it can't be used with, so the order is otherwise unsafe
	if #others > 0 and not Prayer.deactivate(others) then
		return false
	end
	local list = infos(layout)
	if #list > 0 and not Prayer.activate(list) then
		return false
	end
	return PrayerLayout.is_active(layout)
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
