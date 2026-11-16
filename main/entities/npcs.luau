--!strict
local Host = require("@lib/host")
local npcs = Host.npcs
local npc_model = Host.npc_model
local menu = Host.menu
type Npc = Host.Npc
type MenuEntry = Host.MenuEntry
type NpcModel = Host.NpcModel
type Tile = Host.Tile
local Geometry = require("@lib/utils/math/geometry")
type Point = Geometry.Point
local Clickbox = require("@lib/main/clickbox")
local Mouse = require("@lib/utils/input/mouse")
local Projection = require("@lib/main/projection/projection")
type Clickbox = Clickbox.Clickbox
local Npcs = {}

function Npcs.clean_name(name: string): string
	return (string.gsub(name, "<[^>]*>", ""))
end

local function matches(npc: Npc, what: string | number): boolean
	if type(what) == "number" then
		return npc.id == what
	end
	return string.lower(Npcs.clean_name(npc.name)) == string.lower(what)
end

local FIXED_FIELDS: { [number]: number } = {
	[12] = 1,
	[13] = 2,
	[14] = 2,
	[15] = 2,
	[16] = 2,
	[17] = 8,
	[18] = 2,
	[74] = 2,
	[75] = 2,
	[76] = 2,
	[77] = 2,
	[78] = 2,
	[79] = 2,
	[93] = 0,
	[95] = 2,
	[97] = 2,
	[98] = 2,
	[99] = 0,
	[100] = 1,
	[101] = 1,
	[103] = 2,
	[107] = 0,
	[109] = 0,
	[111] = 0,
	[114] = 2,
	[115] = 8,
	[116] = 2,
	[117] = 8,
	[122] = 0,
	[123] = 0,
	[124] = 2,
	[125] = 1,
	[126] = 2,
	[128] = 1,
	[129] = 0,
	[130] = 0,
	[145] = 0,
	[146] = 2,
	[147] = 0,
}
local LIST_FIELDS: { [number]: number } = { [1] = 2, [40] = 4, [41] = 4, [60] = 2, [61] = 4, [62] = 4 }
local options_by_id: { [number]: { string } } = {}

local function read_options(data: string): { string }
	local found: { string } = {}
	local i = 1
	while i <= #data do
		local op = string.byte(data, i)
		i += 1
		if op == 0 then
			break
		elseif op == 2 or (op >= 30 and op <= 34) then
			local stop = string.find(data, "\0", i, true) or (#data + 1)
			if op ~= 2 then
				table.insert(found, string.sub(data, i, stop - 1))
			end
			i = stop + 1
		elseif FIXED_FIELDS[op] then
			i += FIXED_FIELDS[op]
		elseif LIST_FIELDS[op] then
			i += 1 + string.byte(data, i) * LIST_FIELDS[op]
		else
			break
		end
	end
	return found
end

function Npcs.options(id: number): { string }?
	local cached = options_by_id[id]
	if cached then
		return cached
	end
	local data = Host.cache_file(Npcs.CONFIG_INDEX, Npcs.CONFIG_ARCHIVE, id)
	if data == nil then
		return nil
	end
	local found = read_options(data)
	options_by_id[id] = found
	return found
end

Npcs.CONFIG_INDEX = 2
Npcs.CONFIG_ARCHIVE = 9
Npcs.PRAYER_ICONS = 440
Npcs.PRAYER_SPRITES = table.freeze({ [0] = "melee", [1] = "ranged", [2] = "magic" })

function Npcs.overhead(npc: Npc): string?
	for _, icon in ipairs(npc.head_icons or {}) do
		if icon.archive == Npcs.PRAYER_ICONS then
			return Npcs.PRAYER_SPRITES[icon.sprite]
		end
	end
	return nil
end

function Npcs.distance(a: Tile, b: Tile): number
	return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

function Npcs.find(what: (string | number)?): { Npc }?
	local all = npcs()
	if all == nil then
		return nil
	end
	if what == nil then
		return all
	end
	local found: { Npc } = {}
	for _, npc in ipairs(all) do
		if matches(npc, what) then
			table.insert(found, npc)
		end
	end
	return found
end

function Npcs.nearest(what: (string | number)?, from: Tile): Npc?
	local found = Npcs.find(what)
	if found == nil then
		return nil
	end
	local best: Npc? = nil
	local best_distance = math.huge
	for _, npc in ipairs(found) do
		local d = Npcs.distance(npc, from)
		if d < best_distance then
			best, best_distance = npc, d
		end
	end
	return best
end

function Npcs.refresh(npc: Npc): Npc?
	local all = npcs()
	if all == nil then
		return nil
	end
	for _, other in ipairs(all) do
		if other.index == npc.index then
			return other
		end
	end
	return nil
end

function Npcs.model(npc: Npc): NpcModel?
	return (npc_model(npc.index))
end

function Npcs.clickbox(npc: Npc): Clickbox?
	local model = Npcs.model(npc)
	if model == nil then
		return nil
	end
	return Clickbox.from_model(model, npc.name)
end

function Npcs.target(npc: Npc): Point?
	local box = Npcs.clickbox(npc)
	if box == nil then
		return nil
	end
	return (Clickbox.target(box, npc.name))
end

local MENU_NPC = 2

function Npcs.owns(npc: Npc, entry: MenuEntry): boolean
	return entry.kind == MENU_NPC and entry.index == npc.index
end

function Npcs.hovered(npc: Npc): boolean
	for _, entry in ipairs(menu() or {}) do
		if Npcs.owns(npc, entry) then
			return true
		end
	end
	return false
end

function Npcs.projected(npc: Npc, at: Tile): Clickbox?
	local cuboid = Projection.cuboid(npc.local_x, npc.local_y, 1, nil, at)
	if cuboid == nil then
		return nil
	end
	return Clickbox.from_cuboid(cuboid)
end

local function clickbox_of(npc: Npc): Clickbox.Aim
	return Clickbox.walking(function()
		return Npcs.clickbox(npc)
	end, function()
		local now = Npcs.refresh(npc)
		return if now then { x = now.local_x, y = now.local_y } else nil
	end, npc.name)
end

local function hovered_by(npc: Npc): () -> boolean
	return function()
		return Npcs.hovered(npc)
	end
end

local function owned_by(npc: Npc): (MenuEntry) -> boolean
	return function(entry)
		return Npcs.owns(npc, entry)
	end
end

local function tile_of(npc: Npc): () -> Tile?
	return function()
		local now = Npcs.refresh(npc)
		return if now then { x = now.x, y = now.y } else nil
	end
end

function Npcs.hover(npc: Npc): boolean
	return Clickbox.hover(clickbox_of(npc), hovered_by(npc), npc.name, tile_of(npc))
end

function Npcs.hover_async(npc: Npc, at: Tile?): boolean
	if at == nil then
		return Clickbox.hover_async(clickbox_of(npc), npc.name)
	end
	return Clickbox.hover_async(function()
		return Npcs.projected(npc, at)
	end, npc.name)
end

function Npcs.click(npc: Npc, button: Mouse.Button?, spam: number?): boolean
	return Clickbox.click(clickbox_of(npc), hovered_by(npc), npc.name, button, tile_of(npc), spam)
end

local function act_of(npc: Npc): Clickbox.ActTarget
	return { model = { target = "npc", index = npc.index }, entry = { kind = MENU_NPC, index = npc.index } }
end

function Npcs.interact(
	npc: Npc,
	option: string | { string },
	walk_timeout_ms: (number | false)?,
	spam: number?
): boolean
	return Clickbox.interact(
		clickbox_of(npc),
		hovered_by(npc),
		npc.name,
		option,
		owned_by(npc),
		tile_of(npc),
		walk_timeout_ms,
		spam,
		nil,
		act_of(npc)
	)
end

function Npcs.approach(npc: Npc, options: string | { string }, opts: Clickbox.Approach?): boolean
	return Clickbox.approach(
		clickbox_of(npc),
		hovered_by(npc),
		npc.name,
		options,
		owned_by(npc),
		tile_of(npc),
		opts,
		act_of(npc)
	)
end

return Npcs
