--!strict
local Host = require("../host")
local varp = Host.varp
local varps = Host.varps
local Varps = {}

Varps.ATTACK_STYLE = 43
Varps.ACTIVE_PRAYERS = 83
Varps.QUEST_POINTS = 101
Varps.POISON = 102
Varps.RUN = 173
Varps.TUTORIAL_PROGRESS = 281
Varps.SPECIAL_ATTACK = 300
Varps.SPECIAL_ATTACK_ENABLED = 301
Varps.SLAYER_TASK_SIZE = 394
Varps.SLAYER_TASK_CREATURE = 395
Varps.LAST_HOME_TELEPORT = 892

function Varps.get(id: number): number?
	return varp(id)
end

function Varps.all(): { [number]: number }?
	local list = varps()
	if list == nil then
		return nil
	end
	local all: { [number]: number } = {}
	for i, value in ipairs(list) do
		all[i - 1] = value
	end
	return all
end

function Varps.changes(
	before: { [number]: number },
	after: { [number]: number }
): { [number]: { before: number?, after: number } }
	local changed: { [number]: { before: number?, after: number } } = {}
	for id, value in pairs(after) do
		if before[id] ~= value then
			changed[id] = { before = before[id], after = value }
		end
	end
	return changed
end

function Varps.poison_state(value: number): string
	if value >= 1000000 then
		return "envenomed"
	elseif value > 0 then
		return "poisoned"
	end
	return "healthy"
end

return Varps
