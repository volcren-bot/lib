--!strict
local Host = require("../../host")
local npcs = Host.npcs
local npc_model = Host.npc_model
local menu = Host.menu
type Npc = Host.Npc
type MenuEntry = Host.MenuEntry
type NpcModel = Host.NpcModel
type Tile = Host.Tile
local Geometry = require("../../utils/math/geometry")
type Point = Geometry.Point
local Mouse = require("../../utils/input/mouse")
local Clickbox = require("../clickbox")
local Projection = require("../projection/projection")
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
	local model = npc_model(npc.index)
	if model == nil then
		return nil
	end
	return model
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
	return Clickbox.target(box, npc.name)
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

local function tile_of(npc: Npc): () -> Tile?
	return function()
		local now = Npcs.refresh(npc)
		return if now then { x = now.x, y = now.y } else nil
	end
end

function Npcs.hover(npc: Npc): boolean
	return Clickbox.hover(clickbox_of(npc), hovered_by(npc), npc.name, tile_of(npc))
end

function Npcs.hover_async(npc: Npc): boolean
	return Clickbox.hover_async(clickbox_of(npc), npc.name)
end

function Npcs.click(npc: Npc, button: Mouse.Button?): boolean
	return Clickbox.click(clickbox_of(npc), hovered_by(npc), npc.name, button, tile_of(npc))
end

function Npcs.interact(npc: Npc, option: string | { string }, walk_timeout_ms: (number | false)?): boolean
	local function owns(entry: MenuEntry): boolean
		return Npcs.owns(npc, entry)
	end
	return Clickbox.interact(clickbox_of(npc), hovered_by(npc), npc.name, option, owns, tile_of(npc), walk_timeout_ms)
end

function Npcs.approach(npc: Npc, options: string | { string }, opts: Clickbox.Approach?): boolean
	local function owns(entry: MenuEntry): boolean
		return Npcs.owns(npc, entry)
	end
	return Clickbox.approach(clickbox_of(npc), hovered_by(npc), npc.name, options, owns, tile_of(npc), opts)
end

return Npcs
