--!strict
-- Achievement diary progress from the client's cache and variables: which tiers of which regions are done, and how many tasks, with no tab to open and nothing hard-coded.
-- Two of the game's own scripts hold it, and they are read once and kept for the run:
--   `area_task_complete` (56): for each region number, the four varbits that say a tier is done (easy, medium, hard, elite) and the one that says the diary was started.
--   `diary_completion_info` (2200): for each region number, each tier's task-count varbit and its number of tasks.
-- The region's name comes from the client's own name for its varbits (`kandarin_diary_elite_complete`).
local Cs2 = require("@lib/utils/cs2")
local Host = require("@lib/host")
local Log = require("@lib/utils/log")

local Diaries = {}

Diaries.COMPLETE_SCRIPT = 56
Diaries.INFO_SCRIPT = 2200
Diaries.SCRIPT_INDEX = 12
-- the kind of the client's name table for varbits (`GameVal.VARBIT`)
Diaries.VARBIT_NAMES = 4
Diaries.TIERS = { "easy", "medium", "hard", "elite" }

-- cs2 opcodes read here: loading a local, and the "not equal" jump that opens each region's block
local PUSH_LOCAL = 33
local JUMP_NOT_EQUAL = 8

type Tier = {
	-- 1 once the tier is done (Karamja's first three hold 2)
	done_varbit: number,
	done_value: number,
	-- the varbit counting the tier's finished tasks, and how many tasks it has
	count_varbit: number?,
	total: number?,
}

type Region = {
	key: string,
	started_varbit: number,
	tiers: { Tier },
}

export type Progress = { done: number, total: number }

local loaded = false
local failed = false
local regions: { [string]: Region } = {}
local order: { string } = {}

local function script(id: number): Cs2.Script?
	local bytes = Host.cache_file(Diaries.SCRIPT_INDEX, id, 0)
	if bytes == nil then
		return nil
	end
	return Cs2.script(bytes)
end

-- The varbits of each region number in `area_task_complete`: its block starts at "local 0 = N" and holds the four tier varbits, then the "started" one.
local function read_complete(s: Cs2.Script): { [number]: Region }?
	local found: { [number]: Region } = {}
	local ins = s.instructions
	local current: { number }? = nil
	local number: number? = nil
	local values: { [number]: number } = {}
	local function close()
		if current ~= nil and number ~= nil and #current == 5 then
			local tiers: { Tier } = {}
			for t = 1, 4 do
				tiers[t] = { done_varbit = current[t], done_value = values[current[t]] or 1 }
			end
			found[number] = { key = "", started_varbit = current[5], tiers = tiers }
		end
		current = nil
	end
	for i, x in ipairs(ins) do
		if
			x.op == PUSH_LOCAL
			and x.value == 0
			and ins[i + 1] ~= nil
			and ins[i + 1].op == Cs2.PUSH_INT
			and ins[i + 2] ~= nil
			and ins[i + 2].op == JUMP_NOT_EQUAL
		then
			close()
			number = ins[i + 1].value :: number
			current = {}
		elseif x.op == Cs2.GET_VARBIT and current ~= nil then
			table.insert(current, x.value :: number)
			-- a tier tested on its own against a value (`= 2`) says what "done" means for it
			local after, jump = ins[i + 1], ins[i + 2]
			if after ~= nil and jump ~= nil and after.op == Cs2.PUSH_INT and jump.op == JUMP_NOT_EQUAL then
				values[x.value :: number] = after.value :: number
			end
		end
	end
	close()
	if next(found) == nil then
		return nil
	end
	return found
end

-- Each region number's task-count varbit and task total for every tier, from the switch in `diary_completion_info`.
local function read_info(s: Cs2.Script): { [number]: { { count: number, total: number } } }?
	local at: number? = nil
	for i, x in ipairs(s.instructions) do
		if x.op == Cs2.SWITCH then
			at = i
			break
		end
	end
	if at == nil then
		return nil
	end
	local t = s.tables[(s.instructions[at].value :: number) + 1]
	if t == nil then
		return nil
	end
	local info: { [number]: { { count: number, total: number } } } = {}
	for number, jump in pairs(t) do
		local first = at + 1 + jump
		local tiers: { { count: number, total: number } } = {}
		for tier = 1, 4 do
			-- per tier: the count varbit, the number of tasks, and the reward varbit
			local count, total, reward = s.instructions[first], s.instructions[first + 1], s.instructions[first + 2]
			if
				count == nil
				or total == nil
				or reward == nil
				or count.op ~= Cs2.GET_VARBIT
				or total.op ~= Cs2.PUSH_INT
				or reward.op ~= Cs2.GET_VARBIT
			then
				return nil
			end
			tiers[tier] = { count = count.value :: number, total = total.value :: number }
			first += 3
		end
		info[number] = tiers
	end
	return info
end

-- Reads the two scripts and names the regions. Done once; false (and not tried again) when the cache isn't shaped as expected.
function Diaries.load(): boolean
	if loaded then
		return true
	end
	if failed then
		return false
	end
	failed = true
	local complete_script, info_script = script(Diaries.COMPLETE_SCRIPT), script(Diaries.INFO_SCRIPT)
	local complete = if complete_script then read_complete(complete_script) else nil
	local info = if info_script then read_info(info_script) else nil
	if complete == nil or info == nil then
		Log.log("Diaries", "couldn't read the diary scripts")
		return false
	end
	local ids: { number } = {}
	local numbers: { number } = {}
	for number, region in pairs(complete) do
		table.insert(numbers, number)
		table.insert(ids, region.tiers[4].done_varbit)
	end
	local names = Host.game_val_names(Diaries.VARBIT_NAMES, ids)
	if names == nil then
		Log.log("Diaries", "couldn't read the varbit names")
		return false
	end
	local found: { [string]: Region } = {}
	local keys: { string } = {}
	for i, number in ipairs(numbers) do
		local name = names[i]
		local key = if name then string.match(name, "^(%a+)_diary_elite_complete$") else nil
		local region, tiers = complete[number], info[number]
		if key ~= nil and tiers ~= nil then
			region.key = key
			for t = 1, 4 do
				region.tiers[t].count_varbit = tiers[t].count
				region.tiers[t].total = tiers[t].total
			end
			found[key] = region
			table.insert(keys, key)
		end
	end
	if #keys == 0 then
		Log.log("Diaries", "found no diary regions")
		return false
	end
	table.sort(keys)
	regions = found
	order = keys
	loaded = true
	failed = false
	Log.log("Diaries", `read {#keys} diary regions from the cache`)
	return true
end

-- The first word of a region's name, lowercase: "Kourend & Kebos" is "kourend", "Western Provinces" is "western".
local function key_of(region: string): string
	return (string.match(string.lower(region), "^%a+")) or ""
end

-- The regions the cache lists, by key ("ardougne", "kourend", "western", ...), sorted.
function Diaries.regions(): { string }
	if not Diaries.load() then
		return {}
	end
	return table.clone(order)
end

-- Whether a tier ("easy", "medium", "hard" or "elite") of a region is done; nil for an unknown region or tier, or when it can't be read.
function Diaries.tier(region: string, tier: string): boolean?
	if not Diaries.load() then
		return nil
	end
	local r = regions[key_of(region)]
	local index = table.find(Diaries.TIERS, string.lower(tier))
	if r == nil or index == nil then
		return nil
	end
	local value = Host.varbit(r.tiers[index].done_varbit)
	if value == nil then
		return nil
	end
	return value >= r.tiers[index].done_value
end

-- Whether all four tiers of a region are done; nil for an unknown region or when it can't be read.
function Diaries.complete(region: string): boolean?
	for _, tier in ipairs(Diaries.TIERS) do
		local done = Diaries.tier(region, tier)
		if done == nil then
			return nil
		elseif not done then
			return false
		end
	end
	return true
end

-- Whether the region's diary has been started.
function Diaries.started(region: string): boolean?
	if not Diaries.load() then
		return nil
	end
	local r = regions[key_of(region)]
	local value = if r then Host.varbit(r.started_varbit) else nil
	return if value ~= nil then value > 0 else nil
end

-- Tasks done and tasks in all, for a region or for one of its tiers; nil for an unknown region or tier, or when it can't be read.
function Diaries.progress(region: string, tier: string?): Progress?
	if not Diaries.load() then
		return nil
	end
	local r = regions[key_of(region)]
	if r == nil then
		return nil
	end
	local from, to = 1, 4
	if tier ~= nil then
		local index = table.find(Diaries.TIERS, string.lower(tier))
		if index == nil then
			return nil
		end
		from, to = index, index
	end
	local done, total = 0, 0
	for i = from, to do
		local t = r.tiers[i]
		local count = Host.varbit(t.count_varbit :: number)
		if count == nil then
			return nil
		end
		done += count
		total += t.total :: number
	end
	return { done = done, total = total }
end

-- Forgets what was read, so the next question reads the cache again.
function Diaries.reload()
	loaded = false
	failed = false
	regions = {}
	order = {}
end

return Diaries
