--!strict
local Host = require("@lib/host")
local game_state = Host.game_state
local sleep = Host.sleep
local time = Host.time
type Tile = Host.Tile
local GameState = require("@lib/main/game_state")
local Log = require("@lib/utils/log")
local Position = require("@lib/main/position")
local Varps = require("@lib/main/varps")

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

-- server packet 2 ends a game tick; packet ids reshuffle when the game updates
local TICK_PACKET = 2

function Player.is_moving(sample_ms: number?): boolean
	local movement = Host.movement()
	if movement ~= nil then
		return movement.moving
	end
	-- an agent that doesn't track the server tile: watch the model, which lags the server
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

local function animation_of(name: string?): number?
	if name == nil then
		return nil
	end
	for _, p in ipairs(Host.players() or {}) do
		if p.name == name then
			return p.animation
		end
	end
	return nil
end

-- The id of the animation the player is playing, -1 for none: an obstacle, a search, an attack. Walking and running are the pose, not this.
function Player.animation(): number?
	return animation_of(game_state().player_name)
end

-- The id of the player's pose: what it does when no animation plays, like standing, walking or riding a magic carpet.
function Player.pose(): number?
	local name = game_state().player_name
	if name == nil then
		return nil
	end
	for _, p in ipairs(Host.players() or {}) do
		if p.name == name then
			return p.pose
		end
	end
	return nil
end

function Player.is_animating(): boolean
	local id = Player.animation()
	return id ~= nil and id ~= -1
end

-- an animation can pause for a moment between two others
Player.IDLE_MS = 300

-- Waits until the player has neither moved nor played an animation for `Player.IDLE_MS`. False after `timeout_ms`.
-- `on_poll` is called on every check.
function Player.wait_idle(timeout_ms: number?, on_poll: (() -> ())?): boolean
	local timeout = timeout_ms or Player.WALK_TIMEOUT
	local started = time()
	local x, y = fine()
	local idle_since = started
	while true do
		local now = time()
		local s = game_state()
		local p = s.position
		local nx, ny = if p then p.local_x else nil, if p then p.local_y else nil
		if on_poll then
			on_poll()
		end
		local animation = if nx == nil or nx ~= x or ny ~= y then nil else animation_of(s.player_name)
		if nx == nil or nx ~= x or ny ~= y or (animation ~= nil and animation ~= -1) then
			x, y = nx, ny
			idle_since = now
		elseif now - idle_since >= Player.IDLE_MS then
			return true
		end
		if now - started >= timeout then
			return false
		end
		sleep(30)
	end
end

function Player.destination(): Tile?
	local s = game_state()
	return s.destination
end

-- Whether the player is still on the way somewhere. The destination alone doesn't say: it clears on the server's last step, a few tiles before the player gets there.
function Player.in_transit(): boolean
	if Player.destination() ~= nil then
		return true
	end
	local server = Host.server_tile()
	return server ~= nil and server.steps > 0
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

function Player.wait_server_still(timeout_ms: number?): boolean
	local timeout = timeout_ms or Player.WALK_TIMEOUT
	local started = time()
	while true do
		local left = timeout - (time() - started)
		local movement = Host.movement()
		if movement == nil then
			return Player.wait_still(math.max(left, 0))
		end
		if not movement.moving then
			return true
		end
		if left <= 0 then
			Log.log("Player", `the server was still moving the player after {timeout} ms`)
			return false
		end
		Host.wait_packet({ TICK_PACKET }, math.min(left, 1200))
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
