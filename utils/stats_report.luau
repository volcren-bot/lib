--!strict
local Host = require("../host")
local StatsReport = {}

StatsReport.INTERVAL_MS = 60000

export type Tracker = {
	interval_ms: number,
	last_xp: number?,
	last_gold: number?,
	last_sent: number,
	xp: number,
	gold: number,
	custom: { number },
}

function StatsReport.new(interval_ms: number?): Tracker
	return {
		interval_ms = interval_ms or StatsReport.INTERVAL_MS,
		last_xp = nil,
		last_gold = nil,
		last_sent = Host.time(),
		xp = 0,
		gold = 0,
		custom = {},
	}
end

function StatsReport.add_custom(tracker: Tracker, index: number, amount: number)
	for i = #tracker.custom + 1, index do
		tracker.custom[i] = 0
	end
	tracker.custom[index] += amount
end

function StatsReport.flush(tracker: Tracker): boolean
	tracker.last_sent = Host.time()
	local any = tracker.xp ~= 0 or tracker.gold ~= 0
	for _, value in ipairs(tracker.custom) do
		any = any or value ~= 0
	end
	if not any then
		return false
	end
	Host.report_stats(tracker.xp, tracker.gold, tracker.custom)
	tracker.xp, tracker.gold, tracker.custom = 0, 0, {}
	return true
end

function StatsReport.update(tracker: Tracker, skills: { Host.Skill }?, gold: number?): boolean
	if skills ~= nil then
		local total = 0
		for _, skill in ipairs(skills) do
			total += skill.xp
		end
		-- the first read, or a total that went down, is a new starting point rather than a gain
		local last = tracker.last_xp
		if last ~= nil and total > last then
			tracker.xp += total - last
		end
		tracker.last_xp = total
	end
	if gold ~= nil then
		local last = tracker.last_gold
		if last ~= nil then
			tracker.gold += gold - last
		end
		tracker.last_gold = gold
	end
	if Host.time() - tracker.last_sent >= tracker.interval_ms then
		return StatsReport.flush(tracker)
	end
	return false
end

return StatsReport
