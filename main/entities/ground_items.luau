--!strict
local Host = require("@lib/host")
local ground_items = Host.ground_items
local loc_model = Host.loc_model
local menu = Host.menu
type GroundItem = Host.GroundItem
type MenuEntry = Host.MenuEntry
type NpcModel = Host.NpcModel
type Tile = Host.Tile
local Clickbox = require("@lib/main/clickbox")
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Log = require("@lib/utils/log")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Mouse = require("@lib/utils/input/mouse")
local Player = require("@lib/main/player")
local Projection = require("@lib/main/projection/projection")
local Random = require("@lib/utils/math/random")
local Widgets = require("@lib/main/interfaces/widgets")
type Clickbox = Clickbox.Clickbox

local GroundItems = {}

GroundItems.ITEM_PILE = 4

local function matches(item: GroundItem, what: string | number): boolean
	if type(what) == "number" then
		return item.id == what
	end
	return item.name ~= nil and string.lower(item.name) == what
end

local function what(item: GroundItem): string
	return item.name or tostring(item.id)
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
	local wanted = if type(what) == "string" then string.lower(what) else what
	local found: { GroundItem } = {}
	for _, item in ipairs(all) do
		if matches(item, wanted) then
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
	return (loc_model(pile :: any))
end

function GroundItems.clickbox(item: GroundItem): Clickbox?
	local model = GroundItems.model(item)
	if model == nil then
		return nil
	end
	return Clickbox.from_model(model, what(item))
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
	end, what(item))
end

local function hovered_by(item: GroundItem): () -> boolean
	return function()
		return GroundItems.hovered(item)
	end
end

local function owned_by(item: GroundItem): (MenuEntry) -> boolean
	return function(entry)
		return GroundItems.owns(item, entry)
	end
end

local function tile_of(item: GroundItem): () -> Tile?
	local tile = { x = item.x, y = item.y }
	return function()
		return tile
	end
end

function GroundItems.hover(item: GroundItem): boolean
	return Clickbox.hover(clickbox_of(item), hovered_by(item), what(item), tile_of(item))
end

function GroundItems.hover_async(item: GroundItem): boolean
	return Clickbox.hover_async(clickbox_of(item), what(item))
end

function GroundItems.click(item: GroundItem, button: Mouse.Button?, spam: number?): boolean
	return Clickbox.click(clickbox_of(item), hovered_by(item), what(item), button, tile_of(item), spam)
end

function GroundItems.interact(
	item: GroundItem,
	option: string,
	walk_timeout_ms: (number | false)?,
	spam: number?
): boolean
	return Clickbox.interact(
		clickbox_of(item),
		hovered_by(item),
		what(item),
		option,
		owned_by(item),
		tile_of(item),
		walk_timeout_ms,
		spam
	)
end

GroundItems.PILE_TAKE_MS = 2400
GroundItems.PILE_WALK_TILE_MS = 600
GroundItems.PILE_REACTION_MS = { 60, 250 }
GroundItems.PILE_ATTEMPTS = 3

local stackable: { [number]: boolean } = {}

function GroundItems.fits(item: GroundItem): boolean
	if (Inventory.free_slots() or 0) > 0 then
		return true
	end
	if stackable[item.id] == nil then
		stackable[item.id] = (Host.item_stackable({ item.id }) or {})[1] == true
	end
	return stackable[item.id] and Inventory.find(item.id) ~= nil
end

local function pile_at(tile: Tile): { GroundItem }
	local pile: { GroundItem } = {}
	for _, item in ipairs(ground_items() or {}) do
		if item.x == tile.x and item.y == tile.y then
			table.insert(pile, item)
		end
	end
	return pile
end

local function count_of(pile: { GroundItem }, id: number): number
	local n = 0
	for _, item in ipairs(pile) do
		if item.id == id then
			n += 1
		end
	end
	return n
end

local function left_click_item(pile: { GroundItem }): GroundItem?
	local top = (menu() or {})[1]
	if top == nil or string.lower(top.option) ~= "take" then
		return nil
	end
	for _, item in ipairs(pile) do
		if GroundItems.owns(item, top) then
			return item
		end
	end
	return nil
end

function GroundItems.take_pile(tile: Tile): (number, string?)
	local taken, misses = 0, 0
	while true do
		local pile = pile_at(tile)
		if #pile == 0 then
			return taken, nil
		end
		local item = left_click_item(pile)
		if item == nil then
			if not GroundItems.hover(pile[1]) then
				return taken, "failed"
			end
			item = left_click_item(pile)
		end
		if item == nil then
			Log.log("GroundItems", `the left click on the pile at {tile.x},{tile.y} isn't Take`)
			return taken, "failed"
		end
		if not GroundItems.fits(item) then
			return taken, "full"
		end
		local before, clicked = count_of(pile, item.id), Minimenu.clicked()
		local me = Player.position()
		local away = if me then GroundItems.distance(item, { x = me.x, y = me.y }) else 0
		Mouse.click()
		local left = false
		if clicked == nil or Minimenu.wait_click(clicked) ~= nil then
			left = Widgets.wait_within(function(): boolean
				return count_of(pile_at(tile), item.id) < before
			end, GroundItems.PILE_TAKE_MS + away * GroundItems.PILE_WALK_TILE_MS, 50)
		end
		if left then
			taken, misses = taken + 1, 0
			Random.sleep(GroundItems.PILE_REACTION_MS[1], GroundItems.PILE_REACTION_MS[2], "left")
		else
			misses += 1
			if misses >= GroundItems.PILE_ATTEMPTS then
				Log.log("GroundItems", `the {what(item)} at {tile.x},{tile.y} didn't leave the pile`)
				return taken, "failed"
			end
		end
	end
end

function GroundItems.approach(item: GroundItem, options: string | { string }, opts: Clickbox.Approach?): boolean
	return Clickbox.approach(
		clickbox_of(item),
		hovered_by(item),
		what(item),
		options,
		owned_by(item),
		tile_of(item),
		opts
	)
end

return GroundItems
