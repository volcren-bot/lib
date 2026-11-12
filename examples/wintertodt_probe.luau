--!strict
local Host = require("@lib/host")
local Objects = require("@lib/main/entities/objects")

local RUN_MS = 10 * 60 * 1000
local POLL_MS = 600
local MAX_CHILD = 120
local ARENA = { x1 = 1600, y1 = 3960, x2 = 1660, y2 = 4030 }
local LOC_WORDS = { "brazier", "root", "crate", "sprouting", "doors" }
local NPC_WORDS = { "pyromancer", "brew", "wintertodt" }
local HUD_WORDS = { "warmth", "energy", "returns", "points", "wintertodt" }
local TIMER_VARBIT = 7980

local started = Host.time()

local function log(kind: string, text: string)
	print(`{string.format("%.1f", (Host.time() - started) / 1000)}s {kind} {text}`)
end

local function has_word(text: string, words: { string }): boolean
	local lower = string.lower(text)
	for _, word in ipairs(words) do
		if string.find(lower, word, 1, true) then
			return true
		end
	end
	return false
end

local function in_arena(x: number, y: number): boolean
	return x >= ARENA.x1 and x <= ARENA.x2 and y >= ARENA.y1 and y <= ARENA.y2
end

local last: { [string]: string } = {}

local function changed(key: string, kind: string, text: string)
	if last[key] ~= text then
		last[key] = text
		log(kind, text)
	end
end

local function hud_groups(): { number }
	local groups: { [number]: boolean } = {}
	for _, sub in ipairs(Host.sub_interfaces() or {}) do
		groups[sub.group] = true
	end
	groups[396] = true
	local list: { number } = {}
	for group in pairs(groups) do
		table.insert(list, group)
	end
	table.sort(list)
	return list
end

local function read_hud()
	for _, group in ipairs(hud_groups()) do
		for child = 0, MAX_CHILD do
			local w = Host.widget(group, child)
			if w and w.text and w.text ~= "" and has_word(w.text, HUD_WORDS) then
				changed(
					`hud:{group}:{child}`,
					"HUD",
					`{group}:{child} hidden={w.hidden} color={w.text_color} text={w.text}`
				)
			end
		end
	end
	changed("timer", "VARBIT", `{TIMER_VARBIT}={Host.varbit(TIMER_VARBIT)}`)
end

local function read_locs()
	for _, loc in ipairs(Objects.find() or {}) do
		if loc.name and in_arena(loc.x, loc.y) and has_word(loc.name, LOC_WORDS) then
			local view = (Host.loc_shown({ loc.id }) or {})[1]
			local shown = if view then `{view.name} [{table.concat(view.actions, ", ")}]` else "?"
			changed(
				`loc:{loc.x},{loc.y}:{loc.name}`,
				"LOC",
				`{loc.x},{loc.y} size {loc.size_x}x{loc.size_y} id={loc.id} name={loc.name} shown={shown}`
			)
		end
	end
end

local function read_npcs()
	for _, npc in ipairs(Host.npcs() or {}) do
		if has_word(npc.name, NPC_WORDS) then
			changed(`npc:{npc.index}`, "NPC", `{npc.x},{npc.y} id={npc.id} name={npc.name} anim={npc.animation}`)
		end
	end
end

local function read_self()
	local state = Host.game_state()
	local pos = state.position
	if pos then
		changed("tile", "ME", `{pos.x},{pos.y} plane={pos.plane}`)
	end
	local ws = Host.world_select()
	changed("world", "WORLD", tostring(ws and ws.current))
	local items = {}
	for _, slot in ipairs(Host.item_container(93) or {}) do
		if slot.id >= 0 then
			table.insert(items, `{slot.slot}:{slot.id}:{Host.item_name(slot.id) or "?"}`)
		end
	end
	changed("inv", "INV", table.concat(items, " "))
end

local chat_uid = -1

local function read_chat()
	for _, m in ipairs(Host.chat_messages() or {}) do
		if m.uid > chat_uid then
			chat_uid = m.uid
			if Host.time() - started > 1000 then
				log("CHAT", `kind={m.kind} {m.text}`)
			end
		end
	end
end

while Host.time() - started < RUN_MS do
	read_self()
	read_hud()
	read_locs()
	read_npcs()
	read_chat()
	Host.sleep(POLL_MS)
end
