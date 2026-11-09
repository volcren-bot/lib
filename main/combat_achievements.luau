--!strict
local Varbits = require("@lib/main/varbits")

local CombatAchievements = {}

export type Tier = "easy" | "medium" | "hard" | "elite" | "master" | "grandmaster"

CombatAchievements.TIERS = table.freeze({ "easy", "medium", "hard", "elite", "master", "grandmaster" } :: { Tier })

CombatAchievements.STATUS_VARBITS = table.freeze({
	easy = 12863,
	medium = 12864,
	hard = 12865,
	elite = 12866,
	master = 12867,
	grandmaster = 12868,
})

CombatAchievements.NOT_REACHED = 0
CombatAchievements.REACHED = 1
CombatAchievements.CLAIMED = 2

function CombatAchievements.status(tier: Tier): number?
	local varbit = CombatAchievements.STATUS_VARBITS[tier]
	if varbit == nil then
		return nil
	end
	return Varbits.get(varbit)
end

function CombatAchievements.is_reached(tier: Tier): boolean
	local status = CombatAchievements.status(tier)
	return status ~= nil and status >= CombatAchievements.REACHED
end

function CombatAchievements.is_claimed(tier: Tier): boolean
	return CombatAchievements.status(tier) == CombatAchievements.CLAIMED
end

function CombatAchievements.highest_claimed(): Tier?
	for i = #CombatAchievements.TIERS, 1, -1 do
		local tier = CombatAchievements.TIERS[i]
		if CombatAchievements.is_claimed(tier) then
			return tier
		end
	end
	return nil
end

return CombatAchievements
