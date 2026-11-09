--!strict
local Certer = require("@lib/main/interfaces/mainscreen/certer")
local Lamp = require("@lib/main/interfaces/mainscreen/lamp")
local Randoms = require("@lib/main/antiban/randoms")
local RecommendSurvey = require("@lib/main/interfaces/chatbox/recommend_survey")
local Stats = require("@lib/main/interfaces/gametabs/stats")

if RecommendSurvey.is_open() then
	print("skipping the survey:", RecommendSurvey.skip())
end

if Certer.is_open() then
	print("certer quiz: model", Certer.model(), "category", Certer.category())
	for _, answer in ipairs(Certer.answers() or {}) do
		print(" ", answer.letter, answer.text)
	end
	local answer = Certer.correct()
	print("  answer:", answer and answer.letter)
end

local opened = Lamp.open()
if opened then
	for _, cell in ipairs(Lamp.skills() or {}) do
		print("lamp skill:", cell.name)
	end
	print("choose Herblore:", Lamp.choose(Stats.Skill.Herblore), "chosen:", Lamp.selected())
	print("close:", Lamp.close())
else
	print("no lamp in the inventory")
end

local event = Randoms.find()
if event then
	print(`random event waiting: {event.name}`)
	print("handled:", Randoms.handle())
else
	print("no random event waiting")
end
