--!strict
local Host = require("../../host")
local game_state = Host.game_state
local players = Host.players
local player_model = Host.player_model
local menu = Host.menu
type PlayerInfo = Host.PlayerInfo
type MenuEntry = Host.MenuEntry
type NpcModel = Host.NpcModel
type Tile = Host.Tile
local Mouse = require("../../utils/input/mouse")
local Clickbox = require("../clickbox")
type Clickbox = Clickbox.Clickbox
local Players = {}

function Players.distance(a: Tile, b: Tile): number
	return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

function Players.find(name: string?): { PlayerInfo }?
	local all = players()
	if all == nil then
		return nil
	end
	if name == nil then
		return all
	end
	local found: { PlayerInfo } = {}
	for _, player in ipairs(all) do
		if string.lower(player.name) == string.lower(name) then
			table.insert(found, player)
		end
	end
	return found
end

function Players.me(): PlayerInfo?
	local state = game_state()
	local name = state.player_name
	if name == nil then
		return nil
	end
	local found = Players.find(name)
	if found == nil then
		return nil
	end
	return found[1]
end

function Players.nearest(from: Tile): PlayerInfo?
	local all = players()
	if all == nil then
		return nil
	end
	local state = game_state()
	local me = state.player_name
	local best: PlayerInfo? = nil
	local best_distance = math.huge
	for _, player in ipairs(all) do
		local d = Players.distance(player, from)
		if player.name ~= me and d < best_distance then
			best, best_distance = player, d
		end
	end
	return best
end

function Players.refresh(player: PlayerInfo): PlayerInfo?
	local all = players()
	if all == nil then
		return nil
	end
	for _, other in ipairs(all) do
		if other.index == player.index then
			return other
		end
	end
	return nil
end

function Players.model(player: PlayerInfo): NpcModel?
	local model = player_model(player.index)
	if model == nil then
		return nil
	end
	return model
end

function Players.clickbox(player: PlayerInfo): Clickbox?
	local model = Players.model(player)
	if model == nil then
		return nil
	end
	return Clickbox.from_model(model, player.name)
end

local MENU_NPC = 2
local MENU_LOC = 3

function Players.owns(player: PlayerInfo, entry: MenuEntry): boolean
	local name = string.lower(player.name)
	local target = string.lower(entry.target)
	local after = string.sub(target, #name + 1, #name + 1)
	return entry.kind ~= MENU_NPC
		and entry.kind ~= MENU_LOC
		and string.sub(target, 1, #name) == name
		and (after == "" or after == " ")
end

function Players.hovered(player: PlayerInfo): boolean
	for _, entry in ipairs(menu() or {}) do
		if Players.owns(player, entry) then
			return true
		end
	end
	return false
end

local function clickbox_of(player: PlayerInfo): Clickbox.Aim
	return Clickbox.walking(function()
		return Players.clickbox(player)
	end, function()
		local now = Players.refresh(player)
		return if now then { x = now.local_x, y = now.local_y } else nil
	end, player.name)
end

local function hovered_by(player: PlayerInfo): () -> boolean
	return function()
		return Players.hovered(player)
	end
end

local function tile_of(player: PlayerInfo): () -> Tile?
	return function()
		local now = Players.refresh(player)
		return if now then { x = now.x, y = now.y } else nil
	end
end

function Players.hover(player: PlayerInfo): boolean
	return Clickbox.hover(clickbox_of(player), hovered_by(player), player.name, tile_of(player))
end

function Players.hover_async(player: PlayerInfo): boolean
	return Clickbox.hover_async(clickbox_of(player), player.name)
end

function Players.click(player: PlayerInfo, button: Mouse.Button?): boolean
	return Clickbox.click(clickbox_of(player), hovered_by(player), player.name, button, tile_of(player))
end

function Players.interact(player: PlayerInfo, option: string, walk_timeout_ms: (number | false)?): boolean
	local timeout = walk_timeout_ms
	if timeout == nil and string.lower(option) == "follow" then
		timeout = false
	end
	local function owns(entry: MenuEntry): boolean
		return Players.owns(player, entry)
	end
	return Clickbox.interact(
		clickbox_of(player),
		hovered_by(player),
		player.name,
		option,
		owns,
		tile_of(player),
		timeout
	)
end

return Players
