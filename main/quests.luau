--!strict
-- Quest progress from the client's own cache and variables, with no tab to open and nothing hard-coded.
-- The game decides a quest's state in two small scripts (`quest_status_get` and the `quest_progress_get` it calls): the first compares the quest's
-- progress with the "not started" and "finished" values stored in the quest's database row, and the second says which varp or varbit holds the progress.
-- This module reads those two scripts and the rows from the cache once, and keeps them for the rest of the run.
local Cs2 = require("@lib/utils/cs2")
local Host = require("@lib/host")
local Log = require("@lib/utils/log")

local Quests = {}

-- The status script. The progress script is found from the call inside it, and the database columns from the fields it reads.
Quests.STATUS_SCRIPT = 4029
Quests.SCRIPT_INDEX = 12
Quests.CONFIG_INDEX = 2
Quests.DBROW_ARCHIVE = 38
-- The column of a quest row that holds its name as the quest list shows it.
Quests.NAME_COLUMN = 2

export type State = "complete" | "started" | "not_started"

type Entry = {
	-- the quest's database row
	row: number,
	-- "varp" or "varbit", and its id
	kind: string,
	id: number,
}

type Quest = {
	name: string,
	var: Entry,
	-- progress at or below this is "not started" (0 when the row doesn't say)
	unstarted: number,
	-- progress at or above this is "complete"
	finished: number,
}

local loaded = false
local failed = false
local by_name: { [string]: Quest } = {}

local function key(name: string): string
	return string.lower((string.gsub(name, "^%s*(.-)%s*$", "%1")))
end

local function script(id: number): Cs2.Script?
	local bytes = Host.cache_file(Quests.SCRIPT_INDEX, id, 0)
	if bytes == nil then
		return nil
	end
	return Cs2.script(bytes)
end

-- The status script's three database columns (release type, "not started" value, "finished" value, in the order it reads them) and the scripts it calls.
local function read_status(s: Cs2.Script): ({ number }?, { number }?)
	local columns: { number } = {}
	local calls: { number } = {}
	for i, ins in ipairs(s.instructions) do
		if ins.op == Cs2.DB_GETFIELD then
			local column = s.instructions[i - 2]
			if column == nil or column.op ~= Cs2.PUSH_INT then
				return nil, nil
			end
			-- a column constant is the column number shifted past 4 bits for the tuple index
			table.insert(columns, (column.value :: number) // 16)
		elseif ins.op == Cs2.GOSUB then
			table.insert(calls, ins.value :: number)
		end
	end
	if #columns ~= 3 or #calls == 0 then
		return nil, nil
	end
	return columns, calls
end

-- Every quest row and the variable that holds its progress, from the progress script's switch.
local function read_progress(s: Cs2.Script): { Entry }?
	local at: number? = nil
	for i, ins in ipairs(s.instructions) do
		if ins.op == Cs2.SWITCH then
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
	local found: { Entry } = {}
	for row, jump in pairs(t) do
		local case = s.instructions[at + 1 + jump]
		local after = s.instructions[at + 2 + jump]
		if case ~= nil and after ~= nil and after.op == Cs2.RETURN then
			if case.op == Cs2.GET_VARP then
				table.insert(found, { row = row, kind = "varp", id = case.value :: number })
			elseif case.op == Cs2.GET_VARBIT then
				table.insert(found, { row = row, kind = "varbit", id = case.value :: number })
			end
		end
	end
	if #found == 0 then
		return nil
	end
	return found
end

local function field(columns: { [number]: Cs2.Column }, column: number): number | string | nil
	local c = columns[column]
	return if c and c.values[1] then c.values[1][1] else nil
end

-- Reads the scripts and the quest rows. Done once; false (and not tried again) when the cache isn't shaped as expected.
function Quests.load(): boolean
	if loaded then
		return true
	end
	if failed then
		return false
	end
	failed = true
	local status = script(Quests.STATUS_SCRIPT)
	if status == nil then
		Log.log("Quests", "couldn't read the quest status script")
		return false
	end
	local columns, calls = read_status(status)
	if columns == nil or calls == nil then
		Log.log("Quests", "the quest status script isn't shaped as expected")
		return false
	end
	-- the progress script is the one it calls that switches on the quest rows
	local vars: { Entry }? = nil
	for _, id in ipairs(calls) do
		local called = script(id)
		vars = if called then read_progress(called) else nil
		if vars ~= nil then
			break
		end
	end
	if vars == nil then
		Log.log("Quests", "couldn't read the quest progress script")
		return false
	end
	local unstarted_column, finished_column = columns[2], columns[3]
	local quests: { [string]: Quest } = {}
	local wanted: { { number } } = {}
	for i, entry in ipairs(vars) do
		wanted[i] = { Quests.DBROW_ARCHIVE, entry.row }
	end
	local files = Host.cache_files(Quests.CONFIG_INDEX, wanted)
	for i, entry in ipairs(vars) do
		local bytes = if files then files[i] else nil
		local row = if type(bytes) == "string" then Cs2.dbrow(bytes) else nil
		if row ~= nil then
			local name = field(row, Quests.NAME_COLUMN)
			local finished = field(row, finished_column)
			if type(name) == "string" and type(finished) == "number" then
				local unstarted = field(row, unstarted_column)
				quests[key(name)] = {
					name = name,
					var = entry,
					unstarted = if type(unstarted) == "number" then unstarted else 0,
					finished = finished,
				}
			end
		end
	end
	if next(quests) == nil then
		Log.log("Quests", "found no quest rows")
		return false
	end
	by_name = quests
	loaded = true
	failed = false
	Log.log("Quests", `read {#vars} quest variables from the cache`)
	return true
end

-- A quest's state by name (as the quest list shows it, any case), or nil when the cache can't be read, the quest isn't known, or its variable can't be read.
function Quests.state(name: string): State?
	if not Quests.load() then
		return nil
	end
	local q = by_name[key(name)]
	if q == nil then
		return nil
	end
	local value = if q.var.kind == "varp" then Host.varp(q.var.id) else Host.varbit(q.var.id)
	if value == nil or q.finished <= q.unstarted then
		return nil
	end
	if value >= q.finished then
		return "complete"
	elseif value <= q.unstarted then
		return "not_started"
	end
	return "started"
end

-- Whether the quest whose progress is held by the varbit `id` is complete; nil when no quest keeps its progress there (or the cache can't be read).
function Quests.complete_by_varbit(id: number): boolean?
	if not Quests.load() then
		return nil
	end
	for _, quest in pairs(by_name) do
		if quest.var.kind == "varbit" and quest.var.id == id then
			return Quests.state(quest.name) == "complete"
		end
	end
	return nil
end

function Quests.is_complete(name: string): boolean
	return Quests.state(name) == "complete"
end

-- The names of every quest the cache lists, as the quest list shows them.
function Quests.names(): { string }
	local names = {}
	if Quests.load() then
		for _, q in pairs(by_name) do
			table.insert(names, q.name)
		end
	end
	table.sort(names)
	return names
end

-- Forgets what was read, so the next question reads the cache again.
function Quests.reload()
	loaded = false
	failed = false
	by_name = {}
end

return Quests
