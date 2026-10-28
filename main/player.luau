--!strict
local Host = require("../host")
local game_state = Host.game_state
local sleep = Host.sleep
local time = Host.time
type Tile = Host.Tile
local GameState = require("./game_state")
local Log = require("../utils/log")
local Position = require("./position")
local Varps = require("./varps")

local Player = {}

function Player.is_logged_in(): boolean
	local s = game_state()
	return s.game_state == GameState.LOGGED_IN
end

function Player.name(): string?
	local s = game_state()
	return s.player_name
end

function Player.position(): Position.Position?
	local s = game_state()
	local p = s.position
	if p == nil then
		return nil
	end
	return Position.new(p.local_x, p.local_y, p.x, p.y, p.plane)
end

-- the 64x64 map chunks the scene around you is built from; nil when they can't be read
function Player.map_chunks(): { Position.Chunk }?
	local regions = Host.map_regions()
	if regions == nil then
		return nil
	end
	local chunks = {}
	for _, r in ipairs(regions) do
		table.insert(chunks, Position.Chunk.new(r[1], r[2]))
	end
	return chunks
end

function Player.in_instance(): boolean
	local flag = Host.in_instance()
	if flag ~= nil then
		return flag
	end
	-- an agent without the flag: instances sit far east of the overworld
	local pos = Player.position()
	return pos ~= nil and pos:in_instance()
end

-- the map chunks the instance you are in was copied from; nil outside instances or when unreadable
function Player.instance_chunks(): { Position.Chunk }?
	if not Player.in_instance() then
		return nil
	end
	return Player.map_chunks()
end

-- the id of the map chunk the instance was copied from, when it is a copy of a single chunk
function Player.instance_id(): number?
	local chunks = Player.instance_chunks()
	if chunks == nil or #chunks ~= 1 then
		return nil
	end
	return chunks[1]:id()
end

function Player.plane(): number?
	local s = game_state()
	local p = s.position
	if p == nil then
		return nil
	end
	if p.plane == nil then
		return nil
	end
	return p.plane
end

function Player.run_energy(): number?
	local s = game_state()
	local energy = s.run_energy
	if energy == nil then
		return nil
	end
	return energy / 100
end

function Player.weight(): number?
	local s = game_state()
	return s.weight
end

local function levels(name: string): (number?, number?)
	local s = game_state()
	for _, skill in ipairs(s.skills or {}) do
		if skill.name == name then
			return skill.level, skill.real_level
		end
	end
	return nil, nil
end

function Player.hitpoints(): (number?, number?)
	return levels("Hitpoints")
end

function Player.prayer(): (number?, number?)
	return levels("Prayer")
end

function Player.is_running(): boolean
	local value = Varps.get(Varps.RUN)
	if value == nil then
		return false
	end
	return value == 1
end

function Player.special_attack(): number?
	local value = Varps.get(Varps.SPECIAL_ATTACK)
	if value == nil then
		return nil
	end
	return value / 10
end

function Player.special_attack_enabled(): boolean
	local value = Varps.get(Varps.SPECIAL_ATTACK_ENABLED)
	if value == nil then
		return false
	end
	return value == 1
end

function Player.poison(): string?
	local value = Varps.get(Varps.POISON)
	if value == nil then
		return nil
	end
	return Varps.poison_state(value)
end

Player.STILL_MS = 400
Player.WALK_TIMEOUT = 20000

local function fine(): (number?, number?)
	local s = game_state()
	local p = s.position
	if p == nil then
		return nil, nil
	end
	return p.local_x, p.local_y
end

function Player.is_moving(sample_ms: number?): boolean
	local x, y = fine()
	if x == nil then
		return false
	end
	sleep(sample_ms or 100)
	local x2, y2 = fine()
	if x2 == nil then
		return false
	end
	return x2 ~= x or y2 ~= y
end

function Player.destination(): Tile?
	local s = game_state()
	return s.destination
end

function Player.wait_still(timeout_ms: number?): boolean
	local timeout = timeout_ms or Player.WALK_TIMEOUT
	local x, y = fine()
	if x == nil then
		return false
	end
	local started = time()
	local still_since = started
	while true do
		local now = time()
		if now - still_since >= Player.STILL_MS then
			return true
		end
		if now - started >= timeout then
			Log.log("Player", `the player was still moving after {timeout} ms`)
			return false
		end
		sleep(50)
		local x2, y2 = fine()
		if x2 == nil then
			return false
		end
		if x2 ~= x or y2 ~= y then
			x, y, still_since = x2, y2, time()
		end
	end
end

function Player.wait_walk(timeout_ms: number?): boolean
	local timeout = timeout_ms or Player.WALK_TIMEOUT
	local started = time()
	local walked = false
	while true do
		local s = game_state()
		local to = s.destination
		if to == nil then
			break
		end
		walked = true
		if time() - started >= timeout then
			Log.log("Player", `the player was still walking to {to.x}, {to.y} after {timeout} ms`)
			return false
		end
		sleep(50)
	end
	if not walked then
		return true
	end
	return Player.wait_still(math.max(timeout - (time() - started), 0))
end

return Player
