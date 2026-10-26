--!strict
local Host = require("../../host")
local ground_items = Host.ground_items
local loc_model = Host.loc_model
local menu = Host.menu
type GroundItem = Host.GroundItem
type MenuEntry = Host.MenuEntry
type NpcModel = Host.NpcModel
type Tile = Host.Tile
local Mouse = require("../../utils/input/mouse")
local Clickbox = require("../clickbox")
local Projection = require("../projection/projection")
type Clickbox = Clickbox.Clickbox

local GroundItems = {}

GroundItems.ITEM_PILE = 4

local function matches(item: GroundItem, what: string | number): boolean
	if type(what) == "number" then
		return item.id == what
	end
	return item.name ~= nil and string.lower(item.name) == string.lower(what)
end

function GroundItems.distance(item: GroundItem, from: Tile): number
	return math.max(math.abs(item.x - from.x), math.abs(item.y - from.y))
end

function GroundItems.find(what: (string | number)?): { GroundItem }?
	local all = ground_items()
	if all == nil then
		return nil
	end
	if what == nil then
		return all
	end
	local found: { GroundItem } = {}
	for _, item in ipairs(all) do
		if matches(item, what) then
			table.insert(found, item)
		end
	end
	return found
end

function GroundItems.nearest(what: (string | number)?, from: Tile): GroundItem?
	local found = GroundItems.find(what)
	if found == nil then
		return nil
	end
	local best: GroundItem? = nil
	local best_distance = math.huge
	for _, item in ipairs(found) do
		local d = GroundItems.distance(item, from)
		if d < best_distance then
			best, best_distance = item, d
		end
	end
	return best
end

function GroundItems.refresh(item: GroundItem): GroundItem?
	local all = ground_items()
	if all == nil then
		return nil
	end
	for _, other in ipairs(all) do
		if other.id == item.id and other.x == item.x and other.y == item.y and other.plane == item.plane then
			return other
		end
	end
	return nil
end

function GroundItems.model(item: GroundItem): NpcModel?
	local pile = { kind = GroundItems.ITEM_PILE, scene_x = item.scene_x, scene_y = item.scene_y, id = item.id }
	local model = loc_model(pile :: any)
	if model == nil then
		return nil
	end
	return model
end

function GroundItems.clickbox(item: GroundItem): Clickbox?
	local model = GroundItems.model(item)
	if model == nil then
		return nil
	end
	return Clickbox.from_model(model, item.name or tostring(item.id))
end

local MENU_GROUND_ITEM = 4

function GroundItems.owns(item: GroundItem, entry: MenuEntry): boolean
	return entry.kind == MENU_GROUND_ITEM and entry.id == item.id
end

function GroundItems.hovered(item: GroundItem): boolean
	for _, entry in ipairs(menu() or {}) do
		if GroundItems.owns(item, entry) then
			return true
		end
	end
	return false
end

GroundItems.PILE_HEIGHT = 40

local function clickbox_of(item: GroundItem): Clickbox.Aim
	local anchor: Clickbox.Anchor = {
		x = item.scene_x * Projection.TILE + Projection.TILE / 2,
		y = item.scene_y * Projection.TILE + Projection.TILE / 2,
		height = GroundItems.PILE_HEIGHT,
	}
	return Clickbox.walking(function()
		return GroundItems.clickbox(item)
	end, function()
		return anchor
	end, item.name or tostring(item.id))
end

local function hovered_by(item: GroundItem): () -> boolean
	return function()
		return GroundItems.hovered(item)
	end
end

local function tile_of(item: GroundItem): () -> Tile?
	local tile = { x = item.x, y = item.y }
	return function()
		return tile
	end
end

local function what(item: GroundItem): string
	return item.name or tostring(item.id)
end

function GroundItems.hover(item: GroundItem): boolean
	return Clickbox.hover(clickbox_of(item), hovered_by(item), what(item), tile_of(item))
end

function GroundItems.hover_async(item: GroundItem): boolean
	return Clickbox.hover_async(clickbox_of(item), what(item))
end

function GroundItems.click(item: GroundItem, button: Mouse.Button?): boolean
	return Clickbox.click(clickbox_of(item), hovered_by(item), what(item), button, tile_of(item))
end

function GroundItems.interact(item: GroundItem, option: string, walk_timeout_ms: (number | false)?): boolean
	local function owns(entry: MenuEntry): boolean
		return GroundItems.owns(item, entry)
	end
	return Clickbox.interact(
		clickbox_of(item),
		hovered_by(item),
		what(item),
		option,
		owns,
		tile_of(item),
		walk_timeout_ms
	)
end

return GroundItems
