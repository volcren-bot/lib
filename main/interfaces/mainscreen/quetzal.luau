--!strict
local Host = require("@lib/host")
local menu = Host.menu
local widget = Host.widget
local widget_children = Host.widget_children
local sleep = Host.sleep
local time = Host.time
type Widget = Host.Widget
type Npc = Host.Npc
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Log = require("@lib/utils/log")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Mouse = require("@lib/utils/input/mouse")
local Npcs = require("@lib/main/entities/npcs")
local Random = require("@lib/utils/math/random")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Walker = require("@lib/main/walker")
local Widgets = require("@lib/main/interfaces/widgets")

local Quetzal = {}

Quetzal.GROUP = 874
Quetzal.WHISTLE_GROUP = 949
Quetzal.MARKERS = 12
Quetzal.HERE = 13
Quetzal.CLOSE = 18
Quetzal.NPC = "Renu"
Quetzal.OPTION = "Travel"
Quetzal.WHISTLES = { 29271, 29273, 29275, 33120 }
Quetzal.WHISTLE_OPTION = "Signal"
Quetzal.INVENTORY = 93
Quetzal.LAST_OPTION = "Last-destination"
Quetzal.LAST_VARBIT = 9950

Quetzal.OPEN_TIMEOUT_MS = 3000
Quetzal.HOVER_TIMEOUT_MS = 800
Quetzal.CONFIRM_TIMEOUT_MS = 4000
Quetzal.POLL_MS = 50
Quetzal.SETTLE_MS = 150
Quetzal.OPEN_SETTLE_MS = { 250, 500 }

export type Site =
	"Civitas illa Fortis"
	| "The Teomat"
	| "Sunset Coast"
	| "Hunter Guild"
	| "Cam Torum Entrance"
	| "Colossal Wyrm Remains"
	| "Outer Fortis"
	| "Fortis Colosseum"
	| "Aldarin"
	| "Quetzacalli Gorge"
	| "Salvager Overlook"
	| "Tal Teklan"
	| "Auburnvale"
	| "Kastori"

Quetzal.Site = table.freeze({
	CivitasillaFortis = "Civitas illa Fortis",
	TheTeomat = "The Teomat",
	SunsetCoast = "Sunset Coast",
	HunterGuild = "Hunter Guild",
	CamTorumEntrance = "Cam Torum Entrance",
	ColossalWyrmRemains = "Colossal Wyrm Remains",
	OuterFortis = "Outer Fortis",
	FortisColosseum = "Fortis Colosseum",
	Aldarin = "Aldarin",
	QuetzacalliGorge = "Quetzacalli Gorge",
	SalvagerOverlook = "Salvager Overlook",
	TalTeklan = "Tal Teklan",
	Auburnvale = "Auburnvale",
	Kastori = "Kastori",
}) :: {
	CivitasillaFortis: "Civitas illa Fortis",
	TheTeomat: "The Teomat",
	SunsetCoast: "Sunset Coast",
	HunterGuild: "Hunter Guild",
	CamTorumEntrance: "Cam Torum Entrance",
	ColossalWyrmRemains: "Colossal Wyrm Remains",
	OuterFortis: "Outer Fortis",
	FortisColosseum: "Fortis Colosseum",
	Aldarin: "Aldarin",
	QuetzacalliGorge: "Quetzacalli Gorge",
	SalvagerOverlook: "Salvager Overlook",
	TalTeklan: "Tal Teklan",
	Auburnvale: "Auburnvale",
	Kastori: "Kastori",
}

local SITE_ORDER: { Site } = {
	"Civitas illa Fortis",
	"The Teomat",
	"Sunset Coast",
	"Hunter Guild",
	"Cam Torum Entrance",
	"Colossal Wyrm Remains",
	"Outer Fortis",
	"Fortis Colosseum",
	"Aldarin",
	"Quetzacalli Gorge",
	"Salvager Overlook",
	"Tal Teklan",
	"Auburnvale",
	"Kastori",
}

export type Marker = {
	index: number,
	area: Widget,
	here: boolean,
}

local function open_group(): number?
	local open = Toplevel.interfaces()
	if open == nil then
		return nil
	end
	for _, o in ipairs(open) do
		if o.group == Quetzal.GROUP then
			return Quetzal.GROUP
		end
	end
	for _, o in ipairs(open) do
		if o.group == Quetzal.WHISTLE_GROUP then
			return Quetzal.WHISTLE_GROUP
		end
	end
	return nil
end

function Quetzal.is_open(): boolean
	return open_group() ~= nil
end

function Quetzal.wait_open(timeout_ms: number?): boolean
	return Widgets.wait_for(Quetzal.is_open, timeout_ms or Quetzal.OPEN_TIMEOUT_MS, Quetzal.POLL_MS)
end

local known: { [number]: string } = {}

function Quetzal.markers(): { Marker }?
	local group = open_group()
	if group == nil then
		return nil
	end
	local children = widget_children(group, Quetzal.MARKERS)
	if children == nil then
		return nil
	end
	local mark = widget(group, Quetzal.HERE)
	local found: { Marker } = {}
	for _, child in ipairs(children) do
		if not child.hidden then
			if child.action ~= nil and child.action ~= "" then
				known[child.index] = child.action
			end
			table.insert(found, {
				index = child.index,
				area = child,
				here = mark ~= nil and not mark.hidden and mark.x == child.x and mark.y == child.y,
			})
		end
	end
	return found
end

local function menu_name(): string?
	local deadline = time() + Quetzal.HOVER_TIMEOUT_MS
	while true do
		for _, entry in ipairs(menu() or {}) do
			if entry.option ~= "Cancel" and entry.option ~= "Close" then
				return entry.option
			end
		end
		if time() >= deadline then
			return nil
		end
		sleep(Quetzal.POLL_MS)
	end
end

function Quetzal.hover_name(marker: Marker): string?
	Mouse.move(marker.area)
	sleep(Quetzal.SETTLE_MS)
	return menu_name()
end

local function learn(marker: Marker): string?
	for _ = 1, 2 do
		local name = Quetzal.hover_name(marker)
		if name == nil then
			return nil
		end
		local taken = false
		for index, other in pairs(known) do
			if other == name and index ~= marker.index then
				taken = true
				break
			end
		end
		if not taken then
			known[marker.index] = name
			return name
		end
		sleep(Quetzal.SETTLE_MS)
	end
	return nil
end

function Quetzal.names(): { [number]: string }?
	local markers = Quetzal.markers()
	if markers == nil then
		return nil
	end
	local names: { [number]: string } = {}
	for _, marker in ipairs(markers) do
		local name = known[marker.index] or learn(marker)
		if name ~= nil then
			names[marker.index] = name
		end
		if known[marker.index] == nil then
			Random.sleep(40, 160)
		end
	end
	return names
end

function Quetzal.find(name: string): Marker?
	local markers = Quetzal.markers()
	if markers == nil then
		return nil
	end
	local wanted = string.lower(name)
	local loose: Marker? = nil
	local loose_count = 0
	local function check(marker: Marker, have: string): Marker?
		have = string.lower(have)
		if have == wanted then
			return marker
		elseif string.find(have, wanted, 1, true) or string.find(wanted, have, 1, true) then
			loose = marker
			loose_count += 1
		end
		return nil
	end
	local unread: { Marker } = {}
	for _, marker in ipairs(markers) do
		local have = known[marker.index]
		if have == nil then
			table.insert(unread, marker)
		else
			local exact = check(marker, have)
			if exact then
				return exact
			end
		end
	end
	if loose_count == 0 or #unread > 0 then
		for _, marker in ipairs(unread) do
			local have = learn(marker)
			if have ~= nil then
				local exact = check(marker, have)
				if exact then
					return exact
				end
			end
			Random.sleep(40, 160)
		end
	end
	return if loose_count == 1 then loose else nil
end

local function gone(): boolean
	return Widgets.wait_for(function()
		return not Quetzal.is_open()
	end, Quetzal.CONFIRM_TIMEOUT_MS, Quetzal.POLL_MS)
end

function Quetzal.select(site: Site): boolean
	local marker = Quetzal.find(site)
	if marker == nil then
		return false
	end
	local expected = known[marker.index]
	Mouse.move(marker.area)
	sleep(Quetzal.SETTLE_MS)
	if expected == nil or menu_name() ~= expected then
		return false
	end
	Mouse.click()
	if gone() then
		return true
	end
	Log.log("Quetzal", `clicking {expected} left the map open`)
	return false
end

function Quetzal.close_button(): Widget?
	local group = open_group()
	if group == nil then
		return nil
	end
	local w = widget(group, Quetzal.CLOSE)
	return if w == nil or w.hidden then nil else w
end

function Quetzal.close(key_probability: number?): boolean
	local group = open_group()
	if group == nil then
		return true
	end
	return Toplevel.close(
		group,
		Quetzal.close_button,
		if key_probability ~= nil and key_probability > 0 then key_probability else nil
	)
end

Quetzal.ASK_LIMIT = 6
Quetzal.ASK_RANGE = 12
Quetzal.HOVER_MS = 350

function Quetzal.nearest(): Npc?
	local me = Walker.position()
	if me == nil then
		return nil
	end
	local all = Host.npcs() or {}
	local named: Npc? = nil
	local named_distance = math.huge
	local wanted = string.lower(Quetzal.NPC)
	for _, n in ipairs(all) do
		local d = Npcs.distance(n, me)
		if string.lower(Npcs.clean_name(n.name)) == wanted and d < named_distance then
			named, named_distance = n, d
		end
	end
	if named ~= nil then
		return named
	end
	local candidates: { { npc: Npc, distance: number } } = {}
	for _, n in ipairs(all) do
		local d = math.max(math.abs(n.x - me.x), math.abs(n.y - me.y))
		if Npcs.clean_name(n.name) == "" and d <= Quetzal.ASK_RANGE then
			table.insert(candidates, { npc = n, distance = d })
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	for i, c in ipairs(candidates) do
		if i > Quetzal.ASK_LIMIT then
			break
		end
		if Npcs.hover(c.npc) then
			sleep(Quetzal.HOVER_MS)
			for _, entry in ipairs(Minimenu.entries() or {}) do
				if entry.option == Quetzal.OPTION and string.find(string.lower(entry.target), "renu", 1, true) then
					return c.npc
				end
			end
		end
	end
	return nil
end

local function find_renu(npc: Npc?): Npc?
	if not Toplevel.escape_clear() then
		return nil
	end
	local target = npc or Quetzal.nearest()
	if target == nil then
		Log.log("Quetzal", `no {Quetzal.NPC} around`)
	end
	return target
end

local function use(target: Npc, walk: boolean?, option: string): boolean
	if walk ~= false then
		return Npcs.approach(target, option)
	end
	return Npcs.interact(target, option)
end

function Quetzal.open(npc: Npc?, walk: boolean?): boolean
	if Quetzal.is_open() then
		return true
	end
	local target = find_renu(npc)
	if target == nil then
		return false
	end
	if not use(target, walk, Quetzal.OPTION) then
		local uptext = Minimenu.uptext()
		if uptext == nil or not string.find(string.lower(uptext), string.lower(Quetzal.NPC), 1, true) then
			return false
		end
		if not Minimenu.select(Quetzal.OPTION) then
			return false
		end
	end
	if not Quetzal.wait_open() then
		return false
	end
	Random.sleep(Quetzal.OPEN_SETTLE_MS[1], Quetzal.OPEN_SETTLE_MS[2])
	return true
end

function Quetzal.last_destination(): Site?
	return SITE_ORDER[Host.varbit(Quetzal.LAST_VARBIT) or 0]
end

function Quetzal.is_last(name: string): boolean
	local last = Quetzal.last_destination()
	if last == nil then
		return false
	end
	local have, wanted = string.lower(last), string.lower(name)
	return string.find(have, wanted, 1, true) ~= nil or string.find(wanted, have, 1, true) ~= nil
end

function Quetzal.fly_last(npc: Npc?, walk: boolean?): boolean
	local target = find_renu(npc)
	if target == nil then
		return false
	end
	return use(target, walk, Quetzal.LAST_OPTION)
end

function Quetzal.whistle_slot(): number?
	for _, item in ipairs(Host.item_container(Quetzal.INVENTORY) or {}) do
		if table.find(Quetzal.WHISTLES, item.id) ~= nil then
			return item.slot
		end
	end
	return nil
end

function Quetzal.signal(): (boolean, string?)
	if Quetzal.is_open() then
		return true, nil
	end
	local slot = Quetzal.whistle_slot()
	if slot == nil then
		return false, "no whistle held"
	end
	if not Toplevel.escape_clear() then
		return false, "another interface is open"
	end
	if not Inventory.interact_slot(slot, Quetzal.WHISTLE_OPTION) then
		return false, `couldn't {Quetzal.WHISTLE_OPTION} the whistle`
	end
	if not Quetzal.wait_open() then
		return false, "the map didn't open (no charges?)"
	end
	Random.sleep(Quetzal.OPEN_SETTLE_MS[1], Quetzal.OPEN_SETTLE_MS[2])
	return true, nil
end

function Quetzal.signal_last(): boolean
	local slot = Quetzal.whistle_slot()
	if slot == nil or not Toplevel.escape_clear() then
		return false
	end
	return Inventory.interact_slot(slot, Quetzal.LAST_OPTION)
end

return Quetzal
