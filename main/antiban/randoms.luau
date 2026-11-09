--!strict
local Host = require("@lib/host")
local sleep = Host.sleep
local time = Host.time
type Npc = Host.Npc
local Certer = require("@lib/main/interfaces/mainscreen/certer")
local ChatOptions = require("@lib/main/interfaces/chatbox/chat_options")
local Lamp = require("@lib/main/interfaces/mainscreen/lamp")
local Log = require("@lib/utils/log")
local Npcs = require("@lib/main/entities/npcs")
local Stats = require("@lib/main/interfaces/gametabs/stats")
local SurpriseExam = require("@lib/main/interfaces/mainscreen/surprise_exam")
local Widgets = require("@lib/main/interfaces/widgets")

local Randoms = {}

export type Handler = (npc: Npc) -> boolean

Randoms.GENIE = 326
Randoms.GENIE_LAMP = 2528
Randoms.GENIE_OPTION = "Talk-to"
Randoms.NILES = 5436
Randoms.MILES = 5437
Randoms.GILES = 5438
Randoms.GENIE_TIMEOUT_MS = 8000
Randoms.GENIE_SETTLE_MS = 600
Randoms.POLL_MS = 100
Randoms.LAMP_WAIT_MS = 3000
Randoms.LAMP_ATTEMPTS = 3

local function own_index(): number?
	local name = Host.game_state().player_name
	if name == nil then
		return nil
	end
	for _, p in ipairs(Host.players() or {}) do
		if p.name == name then
			return p.index
		end
	end
	return nil
end

local function lamps_held(): number
	local count = 0
	for _, item in ipairs(Host.item_container(Lamp.INVENTORY) or {}) do
		if item.id == Randoms.GENIE_LAMP then
			count += item.quantity
		end
	end
	return count
end

function Randoms.lamp_skill(): Stats.SkillName?
	local skill, why = Host.lamp_skill()
	if why ~= nil then
		Log.log("Randoms", `can't read the lamp skill: {why}`)
	end
	if skill == nil then
		return nil
	end
	if (Stats.Skill :: any)[skill] == nil then
		Log.log("Randoms", `unknown lamp skill "{skill}"`)
		return nil
	end
	return skill :: any
end

local function held_at(slot: number): number?
	for _, item in ipairs(Host.item_container(Lamp.INVENTORY) or {}) do
		if item.slot == slot then
			return item.id
		end
	end
	return nil
end

function Randoms.use_lamps(): boolean
	Widgets.wait_for(function(): boolean
		return Lamp.slot() ~= nil
	end, Randoms.LAMP_WAIT_MS, Randoms.POLL_MS)
	local skill: Stats.SkillName? = nil
	local failures = 0
	while true do
		local slot = Lamp.slot()
		if slot == nil then
			return true
		end
		skill = skill or Randoms.lamp_skill()
		if skill == nil then
			Log.log("Randoms", "no lamp skill set for this account: keeping the lamp")
			return false
		end
		local id = held_at(slot)
		local ok, why = Lamp.use(skill :: Stats.SkillName)
		if
			ok
			and Widgets.wait_for(function(): boolean
				return held_at(slot) ~= id
			end, Randoms.LAMP_WAIT_MS, Randoms.POLL_MS)
		then
			Log.log("Randoms", `spent a lamp on {skill}`)
			failures = 0
		else
			failures += 1
			Log.log("Randoms", `couldn't spend the lamp on {skill}: {why or "it is still held"}`)
			if failures >= Randoms.LAMP_ATTEMPTS then
				return false
			end
		end
	end
end

local function handle_genie(genie: Npc): boolean
	local before = lamps_held()
	if not Npcs.interact(genie, Randoms.GENIE_OPTION) then
		return false
	end
	local deadline = time() + Randoms.GENIE_TIMEOUT_MS
	local got_at: number? = nil
	while time() < deadline do
		if ChatOptions.contains_continue() then
			ChatOptions.continue_chat()
		elseif lamps_held() > before then
			got_at = got_at or time()
			if time() - (got_at :: number) >= Randoms.GENIE_SETTLE_MS then
				break
			end
		end
		sleep(Randoms.POLL_MS)
	end
	if got_at == nil then
		Log.log("Randoms", "the genie gave no lamp")
		return false
	end
	return true
end

local function handle_certer(npc: Npc): boolean
	local opened, closed_why = Certer.open(npc)
	if not opened then
		Log.log("Randoms", closed_why or "the quiz didn't open")
		return false
	end
	local ok, why = Certer.solve()
	if not ok then
		Log.log("Randoms", why or "the quiz wasn't answered")
	end
	return ok
end

Randoms.HANDLERS = {
	[Randoms.GENIE] = handle_genie,
	[SurpriseExam.DUNCE] = SurpriseExam.accept,
	[Randoms.NILES] = handle_certer,
	[Randoms.MILES] = handle_certer,
	[Randoms.GILES] = handle_certer,
} :: { [number]: Handler }

Randoms.LAMP_EVENTS = {
	[Randoms.GENIE] = true,
	[SurpriseExam.DUNCE] = true,
} :: { [number]: boolean }

function Randoms.find(): Npc?
	local me: number? = nil
	for _, npc in ipairs(Host.npcs() or {}) do
		if Randoms.HANDLERS[npc.id] ~= nil then
			me = me or own_index()
			if me ~= nil and npc.interacting_player == me then
				return npc
			end
		end
	end
	return nil
end

function Randoms.handle(): boolean
	if SurpriseExam.inside() then
		Log.log("Randoms", "in the Surprise Exam's classroom")
		local done = SurpriseExam.complete()
		if done then
			Randoms.use_lamps()
		end
		return done
	end
	local npc = Randoms.find()
	if npc == nil then
		return false
	end
	Log.log("Randoms", `event NPC {npc.id} ({npc.name}) is interacting with us`)
	local done = Randoms.HANDLERS[npc.id](npc)
	if done and Randoms.LAMP_EVENTS[npc.id] then
		Randoms.use_lamps()
	end
	return done
end

return Randoms
