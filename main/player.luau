--!strict
local Host = require("@lib/host")
local game_state = Host.game_state
local sleep = Host.sleep
local time = Host.time
type Tile = Host.Tile
type PlayerInfo = Host.PlayerInfo
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
	return game_state().player_name
end

function Player.position(): Position.Position?
	local s = game_state()
	local p = s.position
	if p == nil then
		return nil
	end
	return Position.new(p.local_x, p.local_y, p.x, p.y, p.plane)
end

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
	local pos = Player.position()
	return pos ~= nil and pos:in_instance()
end

function Player.instance_chunks(): { Position.Chunk }?
	if not Player.in_instance() then
		return nil
	end
	return Player.map_chunks()
end

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
	return game_state().weight
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
	return Varps.get(Varps.RUN) == 1
end

function Player.special_attack(): number?
	local value = Varps.get(Varps.SPECIAL_ATTACK)
	if value == nil then
		return nil
	end
	return value / 10
end

function Player.special_attack_enabled(): boolean
	return Varps.get(Varps.SPECIAL_ATTACK_ENABLED) == 1
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

local TICK_PACKET = 2

function Player.is_moving(sample_ms: number?): boolean
	local movement = Host.movement()
	if movement ~= nil then
		return movement.moving
	end
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

local function player_named(name: string?): PlayerInfo?
	if name == nil then
		return nil
	end
	for _, p in ipairs(Host.players() or {}) do
		if p.name == name then
			return p
		end
	end
	return nil
end

local function animation_of(name: string?): number?
	local p = player_named(name)
	return if p then p.animation else nil
end

local function me(): PlayerInfo?
	return player_named(game_state().player_name)
end

function Player.animation(): number?
	return animation_of(game_state().player_name)
end

function Player.pose(): number?
	local p = me()
	return if p then p.pose else nil
end

Player.HIT_KINDS = { [16] = true, [12] = true, [43] = true } :: { [number]: boolean }
Player.COMBAT_MS = 6000
Player.INTERACTING = 0

local CYCLES_PER_MS = 50 / 1000

local function hit_lately(splats: { Host.Hitsplat }?, now: number): boolean
	local since = now - Player.COMBAT_MS * CYCLES_PER_MS
	for _, splat in ipairs(splats or {}) do
		if Player.HIT_KINDS[splat.kind] and splat.cycle > since then
			return true
		end
	end
	return false
end

function Player.attacking(): Host.Npc?
	local self, now = me(), Host.client_cycle()
	if self == nil or now == nil or self.target_state ~= Player.INTERACTING or self.interacting_npc < 0 then
		return nil
	end
	local target: Host.Npc? = nil
	for _, npc in ipairs(Host.npcs() or {}) do
		if npc.index == self.interacting_npc then
			target = npc
			break
		end
	end
	if target == nil then
		return nil
	end
	if hit_lately((Host.npc_hitsplats({ target.index }) or {})[target.index], now) then
		return target
	end
	local pos = game_state().position
	for _, p in ipairs(Host.projectiles() or {}) do
		local from_tile = p.source_player < 0
			and p.source_npc < 0
			and pos ~= nil
			and p.source_x == pos.x
			and p.source_y == pos.y
		if p.target_npc == target.index and (p.source_player == self.index or from_tile) then
			return target
		end
	end
	return nil
end

function Player.is_attacked(): boolean
	local self, now = me(), Host.client_cycle()
	if self == nil or now == nil then
		return false
	end
	if hit_lately((Host.player_hitsplats({ self.index }) or {})[self.index], now) then
		return true
	end
	for _, p in ipairs(Host.projectiles() or {}) do
		if p.target_player == self.index then
			return true
		end
	end
	return false
end

function Player.in_combat(): boolean
	return Player.attacking() ~= nil or Player.is_attacked()
end

function Player.restore_with(drink: () -> boolean, timeout_ms: number): (boolean, string?)
	local function levels(): (number, number, number)
		return Player.hitpoints() or 0, Player.prayer() or 0, Player.run_energy() or 0
	end
	local function full(): boolean
		local hp, max_hp = Player.hitpoints()
		local prayer, max_prayer = Player.prayer()
		return hp == max_hp and prayer == max_prayer and (Player.run_energy() or 0) >= 100
	end
	local hp, prayer, run = levels()
	if not drink() then
		return false, "couldn't drink from it"
	end
	local deadline = time() + timeout_ms
	while true do
		local h, p, r = levels()
		if h > hp or p > prayer or r > run or full() then
			return true, nil
		end
		if time() >= deadline then
			return false, "it didn't restore anything"
		end
		sleep(100)
	end
end

function Player.is_animating(): boolean
	local id = Player.animation()
	return id ~= nil and id ~= -1
end

Player.IDLE_MS = 300

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
	return game_state().destination
end

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
