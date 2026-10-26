--!strict
local Host = require("../../../host")
local game_state = Host.game_state
local widget = Host.widget
type Skill = Host.Skill
local SidePanels = require("./side_panels")
local Mouse = require("../../../utils/input/mouse")
local Geometry = require("../../../utils/math/geometry")
local Log = require("../../../utils/log")
local Box = Geometry.Box
local Stats = {}

Stats.GROUP = 320

-- The tab's skill boxes are children 1 to 24, column by column; "total" is the box under them.
Stats.CHILDREN = {
	attack = 1,
	strength = 2,
	defence = 3,
	ranged = 4,
	prayer = 5,
	magic = 6,
	runecraft = 7,
	construction = 8,
	hitpoints = 9,
	agility = 10,
	herblore = 11,
	thieving = 12,
	crafting = 13,
	fletching = 14,
	slayer = 15,
	hunter = 16,
	mining = 17,
	smithing = 18,
	fishing = 19,
	cooking = 20,
	firemaking = 21,
	woodcutting = 22,
	farming = 23,
	sailing = 24,
	total = 25,
} :: { [string]: number }

function Stats.total_experience(skills: { Skill }?): number?
	if skills == nil then
		return nil
	end
	local total = 0
	for _, skill in ipairs(skills) do
		total += skill.xp
	end
	return total
end

function Stats.total_level(skills: { Skill }?): number?
	if skills == nil then
		return nil
	end
	local total = 0
	for _, skill in ipairs(skills) do
		total += skill.real_level
	end
	return total
end

function Stats.get(name: string): Skill?
	local state = game_state()
	for _, skill in ipairs(state.skills or {}) do
		if string.lower(skill.name) == string.lower(name) then
			return skill
		end
	end
	return nil
end

function Stats.level(name: string): number?
	local skill = Stats.get(name)
	if skill == nil then
		return nil
	end
	return skill.level
end

function Stats.real_level(name: string): number?
	local skill = Stats.get(name)
	if skill == nil then
		return nil
	end
	return skill.real_level
end

function Stats.xp(name: string): number?
	local skill = Stats.get(name)
	if skill == nil then
		return nil
	end
	return skill.xp
end

-- Opens the tab and moves the mouse over a skill's box (or "total").
function Stats.hover(name: string): boolean
	local child = Stats.CHILDREN[string.lower(name)]
	if child == nil then
		Log.log("Stats", `unknown skill {name}`)
		return false
	end
	local opened = SidePanels.open(SidePanels.STATS)
	if opened ~= true then
		return false
	end
	local box = widget(Stats.GROUP, child)
	if box == nil or box.hidden then
		return false
	end
	Mouse.move(Box.new(box.x + 2, box.y + 2, box.x + box.width - 2, box.y + box.height - 2))
	return true
end

-- Queues the tab open and the move over a skill's box (or "total") and returns at once.
function Stats.hover_async(name: string): boolean
	local child = Stats.CHILDREN[string.lower(name)]
	if child == nil then
		Log.log("Stats", `unknown skill {name}`)
		return false
	end
	local box = widget(Stats.GROUP, child)
	if box == nil then
		return false
	end
	if not SidePanels.open_async(SidePanels.STATS) then
		return false
	end
	Mouse.move_async(Box.new(box.x + 2, box.y + 2, box.x + box.width - 2, box.y + box.height - 2))
	return true
end

return Stats
