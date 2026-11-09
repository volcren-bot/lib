--!strict
local Host = require("@lib/host")
local widget_children = Host.widget_children
local widget = Host.widget
local time = Host.time
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local SidePanels = require("@lib/main/interfaces/gametabs/side_panels")
local Widgets = require("@lib/main/interfaces/widgets")

local Journal = {}

Journal.GROUP = 629
Journal.QUEST_BUTTON = 10
Journal.DIARY_BUTTON = 18
Journal.QUEST_GROUP = 399
Journal.QUEST_ROWS = 7
Journal.DIARY_GROUP = 259
Journal.DIARY_ROWS = 2

Journal.COMPLETE_COLOR = 0x0DC10D
Journal.STARTED_COLOR = 0xFFFF00
Journal.NOT_STARTED_COLOR = 0xFF0000

Journal.CACHE_MS = 60 * 1000
local PAGE_TIMEOUT_MS = 3000
local POLL_MS = 100

export type QuestState = "complete" | "started" | "not_started"

export type Diary = {
	name: string,
	done: number,
	total: number,
	complete: boolean,
}

local quests: { [string]: QuestState }? = nil
local quests_at = 0
local diaries: { Diary }? = nil
local diaries_at = 0

local function key(name: string): string
	return string.lower((string.gsub(name, "^%s*(.-)%s*$", "%1")))
end

local function rows(group: number, child: number): { Host.Widget }
	return widget_children(group, child) or {}
end

local function open_page(button: number, group: number, child: number): boolean
	if not SidePanels.open(SidePanels.SIDE_JOURNAL) then
		return false
	end
	if #rows(group, child) == 0 then
		local b = widget(Journal.GROUP, button)
		if b == nil then
			return false
		end
		Mouse.click(b)
	end
	return Widgets.wait_within(function(): boolean
		return #rows(group, child) > 0
	end, PAGE_TIMEOUT_MS, POLL_MS)
end

local function read_quests(): ({ [string]: QuestState }?, number)
	local found: { [string]: QuestState } = {}
	local count = 0
	for _, row in ipairs(rows(Journal.QUEST_GROUP, Journal.QUEST_ROWS)) do
		local text = row.text
		if text ~= nil and text ~= "" then
			local state: QuestState? = nil
			if row.text_color == Journal.COMPLETE_COLOR then
				state = "complete"
			elseif row.text_color == Journal.STARTED_COLOR then
				state = "started"
			elseif row.text_color == Journal.NOT_STARTED_COLOR then
				state = "not_started"
			end
			if state ~= nil then
				found[key(text)] = state
				count += 1
			end
		end
	end
	if count == 0 then
		return nil, 0
	end
	return found, count
end

function Journal.refresh_quests(): boolean
	local found, count = read_quests()
	if found == nil then
		if not open_page(Journal.QUEST_BUTTON, Journal.QUEST_GROUP, Journal.QUEST_ROWS) then
			Log.log("Journal", "couldn't open the quest list")
			return false
		end
		found, count = read_quests()
		if found == nil then
			return false
		end
	end
	quests = found
	quests_at = time()
	Log.log("Journal", `read {count} quests`)
	return true
end

local function fresh_quests(): { [string]: QuestState }?
	if quests == nil or time() - quests_at > Journal.CACHE_MS then
		Journal.refresh_quests()
	end
	return quests
end

function Journal.quest(name: string): QuestState?
	local Quests = require("@lib/main/quests")
	local state = Quests.state(name)
	if state ~= nil then
		return state
	end
	local all = fresh_quests()
	return if all then all[key(name)] else nil
end

function Journal.is_quest_complete(name: string): boolean
	return Journal.quest(name) == "complete"
end

function Journal.completed_quests(): { string }
	local list = {}
	local Quests = require("@lib/main/quests")
	local names = Quests.names()
	if #names > 0 then
		for _, name in ipairs(names) do
			if Quests.state(name) == "complete" then
				table.insert(list, string.lower(name))
			end
		end
		return list
	end
	for name, state in pairs(fresh_quests() or {}) do
		if state == "complete" then
			table.insert(list, name)
		end
	end
	table.sort(list)
	return list
end

function Journal.refresh_diaries(): boolean
	if not open_page(Journal.DIARY_BUTTON, Journal.DIARY_GROUP, Journal.DIARY_ROWS) then
		Log.log("Journal", "couldn't open the achievement diaries")
		return false
	end
	local found: { Diary } = {}
	local last: string? = nil
	for _, row in ipairs(rows(Journal.DIARY_GROUP, Journal.DIARY_ROWS)) do
		local text = row.text
		if text ~= nil and text ~= "" and not row.hidden then
			local done, total = string.match(text, "^(%d+)/(%d+)$")
			if done ~= nil and last ~= nil then
				table.insert(found, {
					name = last,
					done = tonumber(done) :: number,
					total = tonumber(total) :: number,
					complete = done == total,
				})
				last = nil
			else
				last = text
			end
		end
	end
	if #found == 0 then
		return false
	end
	diaries = found
	diaries_at = time()
	Log.log("Journal", `read {#found} achievement diary regions`)
	return true
end

local function first_word(name: string): string
	return (string.match(string.lower(name), "^%a+")) or ""
end

Journal.TIERS = { "easy", "medium", "hard", "elite" }

function Journal.diaries(): { Diary }?
	local Diaries = require("@lib/main/diaries")
	local list: { Diary } = {}
	for _, region in ipairs(Diaries.regions()) do
		local p = Diaries.progress(region)
		if p == nil then
			list = {}
			break
		end
		table.insert(list, {
			name = string.upper(string.sub(region, 1, 1)) .. string.sub(region, 2),
			done = p.done,
			total = p.total,
			complete = p.done == p.total,
		})
	end
	if #list > 0 then
		return list
	end
	if diaries == nil or time() - diaries_at > Journal.CACHE_MS then
		Journal.refresh_diaries()
	end
	return diaries
end

function Journal.diary(name: string): Diary?
	for _, d in ipairs(Journal.diaries() or {}) do
		if first_word(d.name) == first_word(name) then
			return d
		end
	end
	return nil
end

function Journal.diary_tier(region: string, tier: string): boolean?
	return require("@lib/main/diaries").tier(region, tier)
end

function Journal.is_diary_complete(region: string): boolean?
	return require("@lib/main/diaries").complete(region)
end

function Journal.forget()
	quests = nil
	diaries = nil
end

return Journal
