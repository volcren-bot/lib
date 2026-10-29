--!strict
local Host = require("../../host")
local spot_anims = Host.spot_anims
type SpotAnim = Host.SpotAnim
type Tile = Host.Tile
local SpotAnims = {}

-- the client cycle is 50 a second
SpotAnims.CYCLE_MS = 20

local function matches(spot: SpotAnim, what: number | { number }): boolean
	if type(what) == "number" then
		return spot.id == what
	end
	return table.find(what, spot.id) ~= nil
end

function SpotAnims.find(what: (number | { number })?): { SpotAnim }?
	local all = spot_anims()
	if all == nil then
		return nil
	end
	if what == nil then
		return all
	end
	local found: { SpotAnim } = {}
	for _, spot in ipairs(all) do
		if matches(spot, what) then
			table.insert(found, spot)
		end
	end
	return found
end

function SpotAnims.at(tile: Tile, what: (number | { number })?): { SpotAnim }?
	local found = SpotAnims.find(what)
	if found == nil then
		return nil
	end
	local at: { SpotAnim } = {}
	for _, spot in ipairs(found) do
		if spot.view_id == 0 and spot.x == tile.x and spot.y == tile.y then
			table.insert(at, spot)
		end
	end
	return at
end

function SpotAnims.tile(spot: SpotAnim): Tile
	return { x = spot.x, y = spot.y }
end

function SpotAnims.starts_in_ms(spot: SpotAnim): number
	return math.max(0, spot.start_cycle - spot.cycle) * SpotAnims.CYCLE_MS
end

function SpotAnims.age_ms(spot: SpotAnim): number
	return math.max(0, spot.cycle - spot.start_cycle) * SpotAnims.CYCLE_MS
end

return SpotAnims
