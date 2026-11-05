--!strict
-- Combat achievement tiers: which ones the account has reached and which it has claimed the rewards of, from the game's own varbits
-- (`ca_tier_status_easy` to `ca_tier_status_grandmaster`). The game's scripts treat 2 as claimed (script 6931) and above 0 as reached (10255).
local Varbits = require("@lib/main/varbits")

local CombatAchievements = {}

export type Tier = "easy" | "medium" | "hard" | "elite" | "master" | "grandmaster"

-- the tiers from lowest to highest
CombatAchievements.TIERS = table.freeze({ "easy", "medium", "hard", "elite", "master", "grandmaster" } :: { Tier })

-- each tier's status varbit: 0 not reached yet, 1 reached, 2 rewards claimed
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

-- A tier's status (`NOT_REACHED`, `REACHED` or `CLAIMED`); nil when it can't be read.
function CombatAchievements.status(tier: Tier): number?
	local varbit = CombatAchievements.STATUS_VARBITS[tier]
	if varbit == nil then
		return nil
	end
	return Varbits.get(varbit)
end

-- Whether the account has enough points for the tier, claimed or not.
function CombatAchievements.is_reached(tier: Tier): boolean
	local status = CombatAchievements.status(tier)
	return status ~= nil and status >= CombatAchievements.REACHED
end

-- Whether the tier's rewards are claimed: what its perks (like Master's longer thralls) need.
function CombatAchievements.is_claimed(tier: Tier): boolean
	return CombatAchievements.status(tier) == CombatAchievements.CLAIMED
end

-- The highest tier whose rewards are claimed, nil for none.
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
