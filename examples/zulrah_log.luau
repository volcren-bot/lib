--!strict
-- Logs a Zulrah fight you play by hand: each change to Zulrah, the snakelings, projectiles, spot animations, objects, you and the game chat.
-- It only reads, so it never clicks, and stops after RUN_MS. Tiles print as world, then scene.
local Host = require("@lib/host")
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

local RUN_MS = 30 * 60 * 1000
local POLL_MS = 100
local PERF_MS = 60 * 1000
local TRACKED = { zulrah = true, snakeling = true }

local started = Host.time()
local tick = 0
local base_x, base_y = 0, 0

local function log(kind: string, text: string)
	print(`t{tick} {string.format("%.1f", (Host.time() - started) / 1000)}s {kind} {text}`)
end

local function at(x: number, y: number): string
	return `{x},{y} scene {x - base_x},{y - base_y}`
end

local last: { [string]: string } = {}

-- logs `text` under `key` when it differs from the last time
local function changed(key: string, kind: string, text: string)
	if last[key] ~= text then
		last[key] = text
		log(kind, text)
	end
end

local function level(state: Host.ClientState, name: string): number
	for _, skill in ipairs(state.skills or {}) do
		if skill.name == name then
			return skill.level
		end
	end
	return 0
end

local function read_scene()
	local regions = {}
	for _, region in ipairs(Host.map_regions() or {}) do
		table.insert(regions, `{region[1]},{region[2]}`)
	end
	changed(
		"scene",
		"SCENE",
		`instance={Host.in_instance()} corner={base_x},{base_y} regions={table.concat(regions, " ")}`
	)
end

local function read_self(state: Host.ClientState)
	local pos = state.position
	if pos == nil then
		return
	end
	changed("tile", "ME_TILE", at(pos.x, pos.y))
	changed("stats", "ME_STATS", `hp={level(state, "Hitpoints")} prayer={level(state, "Prayer")}`)
	for _, player in ipairs(Host.players() or {}) do
		if player.name == state.player_name then
			changed(
				"self",
				"ME_ACTOR",
				`anim={player.animation} graphic={player.graphic} target_npc={player.interacting_npc}`
			)
			break
		end
	end
end

local function read_prayers()
	local keys = {}
	for _, prayer in ipairs(Prayer.active()) do
		table.insert(keys, prayer.key)
	end
	changed("prayers", "ME_PRAYERS", table.concat(keys, " "))
end

local tracked_now: { [number]: string } = {}
local hits_seen: { [string]: boolean } = {}

local function read_npcs()
	local now: { [number]: string } = {}
	local zulrahs: { number } = {}
	for _, npc in ipairs(Host.npcs() or {}) do
		local name = string.lower(npc.name)
		if TRACKED[name] then
			now[npc.index] = name
			local key = `npc{npc.index}`
			if tracked_now[npc.index] == nil then
				local sizes = Host.npc_sizes({ npc.index })
				log("NPC_NEW", `{name} index={npc.index} id={npc.id} size={sizes and sizes[npc.index]}`)
			end
			-- a snakeling's walking would drown out the rest, so only Zulrah logs its tile
			local tile = if name == "zulrah" then ` at {at(npc.x, npc.y)}` else ""
			changed(
				key,
				"NPC",
				`{name} index={npc.index} id={npc.id}{tile} anim={npc.animation} target_player={npc.interacting_player}`
			)
			if name == "zulrah" then
				table.insert(zulrahs, npc.index)
			end
		end
	end
	for index, name in pairs(tracked_now) do
		if now[index] == nil then
			log("NPC_GONE", `{name} index={index}`)
			last[`npc{index}`] = nil
		end
	end
	tracked_now = now

	if #zulrahs > 0 then
		for index, splats in pairs(Host.npc_hitsplats(zulrahs) or {}) do
			for _, splat in ipairs(splats) do
				local key = `{index}:{splat.slot}:{splat.cycle}`
				if not hits_seen[key] then
					hits_seen[key] = true
					log("HIT", `zulrah kind={splat.kind} damage={splat.damage}`)
				end
			end
		end
	end
end

local effects_seen: { [string]: boolean } = {}

local function read_effects()
	for _, p in ipairs(Host.projectiles() or {}) do
		local key = `p{p.id}:{p.start_cycle}:{p.source_x}:{p.source_y}:{p.target_x}:{p.target_y}`
		if not effects_seen[key] then
			effects_seen[key] = true
			log(
				"PROJECTILE",
				`id={p.id} from {at(p.source_x, p.source_y)} to {at(p.target_x, p.target_y)} `
					.. `target_player={p.target_player} target_npc={p.target_npc} `
					.. `leaves_in={(p.start_cycle - p.cycle) * 20}ms lands_in={(p.end_cycle - p.cycle) * 20}ms`
			)
		end
	end
	for _, s in ipairs(Host.spot_anims() or {}) do
		local key = `s{s.id}:{s.start_cycle}:{s.x}:{s.y}`
		if not effects_seen[key] then
			effects_seen[key] = true
			log("SPOT", `id={s.id} at {at(s.x, s.y)} starts_in={(s.start_cycle - s.cycle) * 20}ms`)
		end
	end
end

local locs_now: { [string]: string }? = nil
local locs_corner = ""

-- only in an instance: the arena has few objects, and the clouds should be among the changes
local function read_locs()
	if not Host.in_instance() then
		locs_now = nil
		return
	end
	local corner = `{base_x},{base_y}`
	local list = Host.locs()
	if list == nil then
		return
	end
	local now: { [string]: string } = {}
	for _, loc in ipairs(list) do
		now[`{loc.id}:{loc.x}:{loc.y}`] = `id={loc.id} name={loc.name} at {at(loc.x, loc.y)}`
	end
	-- a new scene changes every object, so it only sets what later reads compare with
	if locs_now ~= nil and locs_corner == corner then
		for key, text in pairs(now) do
			if (locs_now :: { [string]: string })[key] == nil then
				log("LOC_NEW", text)
			end
		end
		for key, text in pairs(locs_now :: { [string]: string }) do
			if now[key] == nil then
				log("LOC_GONE", text)
			end
		end
	else
		log("LOC_BASE", `{#list} objects`)
	end
	locs_now, locs_corner = now, corner
end

local chat_seen: { [number]: boolean }? = nil

-- game messages only: `name` is empty on those, so other players' chat stays out of the log
local function read_chat()
	local messages = Host.chat_messages()
	if messages == nil then
		return
	end
	local first = chat_seen == nil
	local seen: { [number]: boolean } = chat_seen or {}
	for _, message in ipairs(messages) do
		if not seen[message.uid] then
			seen[message.uid] = true
			if not first and message.name == "" then
				log("CHAT", `kind={message.kind} {message.text}`)
			end
		end
	end
	chat_seen = seen
end

log("START", `logging for {RUN_MS // 60000} minutes`)
local last_tick = -1
local passes, worst_ms, worst_tick_ms, perf_at = 0, 0, 0, Host.time()

while Host.time() - started < RUN_MS do
	local pass_at = Host.time()
	local state = Host.game_state()
	local pos = state.position
	if pos ~= nil then
		tick = state.tick_count or 0
		base_x, base_y = pos.x - pos.local_x // 128, pos.y - pos.local_y // 128
		read_self(state)
		read_npcs()
		read_effects()
		if tick ~= last_tick then
			last_tick = tick
			local tick_at = Host.time()
			read_scene()
			read_prayers()
			read_locs()
			read_chat()
			worst_tick_ms = math.max(worst_tick_ms, Host.time() - tick_at)
		end
	end
	passes += 1
	worst_ms = math.max(worst_ms, Host.time() - pass_at)
	if Host.time() - perf_at >= PERF_MS then
		log("PERF", `passes={passes} worst_pass={worst_ms}ms worst_tick_reads={worst_tick_ms}ms`)
		passes, worst_ms, worst_tick_ms, perf_at = 0, 0, 0, Host.time()
	end
	Host.sleep(POLL_MS)
end
log("DONE", "time is up")
